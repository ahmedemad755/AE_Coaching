import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/notifications/fcm_notification_routing.dart';

class FcmDeviceService {
  FcmDeviceService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    Box? localBox,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localBox = localBox;

  static const _permissionPromptedKey = 'fcmPermissionPrompted';
  static const _tokenOwnerUidKey = 'fcmTokenOwnerUid';
  static const _tokenIdKey = 'fcmTokenId';

  /// Token-document field confirming a build handles SERVER reminders
  /// (contract with firestore.rules and Cloud Functions). Deliberately NOT
  /// written while inactivity reminders are scheduled locally (Spark plan):
  /// the server must treat these devices as not ready, or enabling server
  /// delivery later would duplicate the local reminders. A build that moves
  /// reminders to the server writes it again (equal to `updatedAt`) and
  /// stops local scheduling in the same release.
  static const serverRemindersReadyField = 'serverRemindersReadyAt';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final Box? _localBox;
  Box get _box => _localBox ?? Hive.box('authBox');

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<BoxEvent>? _sessionSubscription;
  Future<void> _operationQueue = Future<void>.value();
  final Set<String> _blockedUids = {};

  /// FCM message ids already routed, so the same tap delivered twice
  /// (getInitialMessage and onMessageOpenedApp, or a re-attached engine)
  /// navigates once.
  final Set<String> _handledMessageIds = {};
  bool _initialized = false;
  bool _readyForRegistration = false;

  /// `uid:tokenId` of the last token written in this process, so repeated
  /// triggers (user reloads, session-marker writes, startup) don't rewrite
  /// the same document. Cleared on sign-out and unregister.
  String? _lastRegistration;

  Future<AuthorizationStatus> notificationAuthorizationStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  @visibleForTesting
  static bool sessionOwnsAuthenticatedUser({
    required String? authenticatedUid,
    required String sessionUid,
    required bool isLoggedIn,
  }) {
    return isLoggedIn &&
        authenticatedUid != null &&
        authenticatedUid.isNotEmpty &&
        sessionUid.isNotEmpty &&
        authenticatedUid == sessionUid;
  }

  /// Token registration eligibility: the same cleared identity the route
  /// guard requires (signed in, not a phone-era test account, verified
  /// when password-based) AND, stricter than the guard, a verified email
  /// for every provider. firestore.rules enforces the same
  /// `email_verified` requirement on token writes.
  @visibleForTesting
  static bool isEligibleForTokenRegistration(StartupAuthSnapshot snapshot) =>
      hasVerifiedEmailIdentity(snapshot);

  static StartupAuthSnapshot _snapshotOf(User? user) => StartupAuthSnapshot(
    firebaseUid: user?.uid,
    firebaseEmail: user?.email ?? '',
    firebaseEmailVerified: user?.emailVerified ?? false,
    firebaseUsesPassword:
        user?.providerData.any((p) => p.providerId == 'password') ?? false,
  );

  /// Runs one registration attempt now, through the same serial queue as
  /// the production triggers.
  @visibleForTesting
  Future<void> syncTokenForTesting() => _enqueue(_registerCurrentSession);

  @visibleForTesting
  static String tokenDocumentId(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Future<void> initialize() async {
    try {
      if (_initialized) return;
      if (!await _messaging.isSupported()) return;
      _initialized = true;

      // userChanges (not authStateChanges) also fires after user.reload(),
      // which is how the app learns an email was just verified, so
      // eligibility is re-evaluated at that moment too.
      _authSubscription = _auth.userChanges().listen((user) {
        if (user == null) {
          _blockedUids.clear();
          _lastRegistration = null;
        } else if (_readyForRegistration && !_blockedUids.contains(user.uid)) {
          _schedule(_registerCurrentSession);
        }
      });
      _sessionSubscription = _box.watch().listen((event) {
        if (_readyForRegistration &&
            (event.key == 'isLoggedIn' || event.key == 'currentUserUid')) {
          _schedule(_registerCurrentSession);
        }
      });
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        (token) {
          if (_readyForRegistration) {
            _schedule(() => _registerCurrentSession(tokenOverride: token));
          }
        },
        onError: (Object error) =>
            debugPrint('FCM token refresh failed: $error'),
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        debugPrint(
          'Foreground FCM message received (type: ${message.data['type']}).',
        );
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _readyForRegistration = true;
        _schedule(_registerCurrentSession);
      });
    } catch (error) {
      debugPrint('FCM initialization skipped: $error');
    }
  }

  Future<void> unregisterCurrentDeviceToken({
    required String expectedUid,
  }) async {
    _blockedUids.add(expectedUid);
    _lastRegistration = null;
    await _enqueue(() async {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != expectedUid) {
        throw StateError('Refusing to unregister a token for another user.');
      }

      final ownerUid = _box.get(_tokenOwnerUidKey) as String?;
      final tokenId = _box.get(_tokenIdKey) as String?;
      if (ownerUid == expectedUid && tokenId != null && tokenId.isNotEmpty) {
        await _tokenDocument(expectedUid, tokenId).delete();
      }

      if (ownerUid == expectedUid) {
        await _box.delete(_tokenOwnerUidKey);
        await _box.delete(_tokenIdKey);
      }
    });
  }

  /// Account deletion completed for [uid]: forget this device's local
  /// registration for it and rotate the device token, so nothing registered
  /// for the deleted account stays usable (its server-side token documents
  /// were removed by the operator tool). Best effort; never throws.
  Future<void> forgetDeletedAccount(String uid) async {
    _blockedUids.add(uid);
    _lastRegistration = null;
    try {
      await _enqueue(() async {
        if (_box.get(_tokenOwnerUidKey) == uid) {
          await _box.delete(_tokenOwnerUidKey);
          await _box.delete(_tokenIdKey);
        }
        await _messaging.deleteToken();
      });
    } catch (error) {
      debugPrint('FCM cleanup after account deletion failed: $error');
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _sessionSubscription?.cancel();
  }

  Future<void> _registerCurrentSession({String? tokenOverride}) async {
    if (kIsWeb) return;
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (_blockedUids.contains(uid)) return;
    if (!sessionOwnsAuthenticatedUser(
      authenticatedUid: uid,
      sessionUid: _box.get('currentUserUid', defaultValue: '') as String,
      isLoggedIn: _box.get('isLoggedIn', defaultValue: false) as bool,
    )) {
      return;
    }
    // Never for unauthenticated, unverified or phone-era accounts, and
    // before any permission prompt. A stale local session marker alone
    // (e.g. left by a phone-era build) is not enough.
    if (!isEligibleForTokenRegistration(_snapshotOf(user))) return;

    final settings = await _messaging.getNotificationSettings();
    final prompted =
        _box.get(_permissionPromptedKey, defaultValue: false) as bool;
    var authorizationStatus = settings.authorizationStatus;
    if (authorizationStatus != AuthorizationStatus.authorized &&
        authorizationStatus != AuthorizationStatus.provisional &&
        !prompted) {
      await _box.put(_permissionPromptedKey, true);
      final requested = await _messaging.requestPermission();
      authorizationStatus = requested.authorizationStatus;
    }
    if (authorizationStatus != AuthorizationStatus.authorized &&
        authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    if ((defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        await _messaging.getAPNSToken() == null) {
      debugPrint('FCM token sync deferred until an APNs token is available.');
      return;
    }

    final token = tokenOverride ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    // TEMPORARY (Firebase Console test sends): debug builds only, never in
    // release. Remove before release.
    if (kDebugMode) debugPrint('FCM_DEBUG_TOKEN: $token');

    final currentUid = _auth.currentUser?.uid;
    final stillOwnsSession = sessionOwnsAuthenticatedUser(
      authenticatedUid: currentUid,
      sessionUid: _box.get('currentUserUid', defaultValue: '') as String,
      isLoggedIn: _box.get('isLoggedIn', defaultValue: false) as bool,
    );
    if (!stillOwnsSession ||
        currentUid != uid ||
        _blockedUids.contains(uid) ||
        !isEligibleForTokenRegistration(_snapshotOf(_auth.currentUser))) {
      return;
    }

    final tokenId = tokenDocumentId(token);
    final previousOwnerUid = _box.get(_tokenOwnerUidKey) as String?;
    final previousTokenId = _box.get(_tokenIdKey) as String?;
    final registration = '$uid:$tokenId';
    if (_lastRegistration == registration &&
        previousOwnerUid == uid &&
        previousTokenId == tokenId) {
      return; // Already registered by this process; nothing changed.
    }
    final tokenRef = _tokenDocument(uid!, tokenId);
    final batch = _firestore.batch();
    final snapshot = await tokenRef.get();
    if (_auth.currentUser?.uid != uid || _blockedUids.contains(uid)) return;

    final data = <String, Object>{
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.name,
      // No serverRemindersReadyField: reminders are local (see its docs).
    };
    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    batch.set(tokenRef, data, SetOptions(merge: true));

    if (previousOwnerUid == uid &&
        previousTokenId != null &&
        previousTokenId.isNotEmpty &&
        previousTokenId != tokenId) {
      batch.delete(_tokenDocument(uid, previousTokenId));
    }
    await batch.commit();

    if (_auth.currentUser?.uid != uid || _blockedUids.contains(uid)) return;
    await _box.put(_tokenOwnerUidKey, uid);
    await _box.put(_tokenIdKey, tokenId);
    _lastRegistration = registration;
  }

  DocumentReference<Map<String, dynamic>> _tokenDocument(
    String uid,
    String tokenId,
  ) => _firestore
      .collection('users')
      .doc(uid)
      .collection('fcmTokens')
      .doc(tokenId);

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.catchError((Object error, StackTrace stackTrace) {
      debugPrint('FCM device operation failed: $error');
    });
    return result;
  }

  void _schedule(Future<void> Function() operation) {
    _enqueue(operation).catchError((Object error) {
      debugPrint('FCM device operation failed: $error');
    });
  }

  /// The tap handler the FCM streams call, for tests (those streams are
  /// static platform channels).
  @visibleForTesting
  void handleNotificationTapForTesting(RemoteMessage message) =>
      _handleNotificationTap(message);

  void _handleNotificationTap(RemoteMessage message) {
    final messageId = message.messageId;
    if (messageId != null && !_handledMessageIds.add(messageId)) return;
    if (FcmNotificationRouting.destinationForData(message.data) ==
        FcmNotificationDestination.home) {
      AppRouter.openHomeFromNotification();
    }
  }
}
