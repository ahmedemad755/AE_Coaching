import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  bool _initialized = false;
  bool _readyForRegistration = false;

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

  @visibleForTesting
  static String tokenDocumentId(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Future<void> initialize() async {
    try {
      if (_initialized) return;
      if (!await _messaging.isSupported()) return;
      _initialized = true;

      _authSubscription = _auth.authStateChanges().listen((user) {
        if (user == null) {
          _blockedUids.clear();
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

    final currentUid = _auth.currentUser?.uid;
    final stillOwnsSession = sessionOwnsAuthenticatedUser(
      authenticatedUid: currentUid,
      sessionUid: _box.get('currentUserUid', defaultValue: '') as String,
      isLoggedIn: _box.get('isLoggedIn', defaultValue: false) as bool,
    );
    if (!stillOwnsSession || currentUid != uid || _blockedUids.contains(uid)) {
      return;
    }

    final tokenId = tokenDocumentId(token);
    final previousOwnerUid = _box.get(_tokenOwnerUidKey) as String?;
    final previousTokenId = _box.get(_tokenIdKey) as String?;
    final tokenRef = _tokenDocument(uid!, tokenId);
    final batch = _firestore.batch();
    final snapshot = await tokenRef.get();
    if (_auth.currentUser?.uid != uid || _blockedUids.contains(uid)) return;

    final data = <String, Object>{
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.name,
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

  void _handleNotificationTap(RemoteMessage message) {
    if (FcmNotificationRouting.destinationForData(message.data) ==
        FcmNotificationDestination.home) {
      AppRouter.openHomeFromNotification();
    }
  }
}
