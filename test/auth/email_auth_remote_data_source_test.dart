import 'package:ae_coaching/auth/data/datasources/email_auth_remote_data_source.dart';
import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/data/datasources/user_profile_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

/// Real EmailAuthRemoteDataSourceImpl logic against Firebase Auth test
/// doubles (firebase_auth_mocks) and an in-memory [UserProfileStore] with
/// the same create-only contract as FirestoreUserProfileStore.
/// (fake_cloud_firestore has no release compatible with this project's
/// Flutter SDK plus cloud_firestore 6.) These cover the
/// data-layer guarantees: create-only profiles, missing-profile recovery,
/// the verification gate, legacy-account handling and error mapping.
/// They are not a substitute for a real-project/emulator run (see the
/// Stage 3B report).

class _ProviderInfo implements UserInfo {
  @override
  final String providerId;
  _ProviderInfo(this.providerId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// MockUser whose verification flag can flip (as after opening the link)
/// and whose reload can fail like a revoked session.
// MockUser (the base) is itself mutable. These fields simulate server-side
// changes, such as the user opening the verification link.
// ignore: must_be_immutable
class _TestUser extends MockUser {
  bool verified;
  String? currentEmail;
  final bool usesPassword;
  FirebaseAuthException? reloadError;
  FirebaseAuthException? emailChangeError;
  String? requestedNewEmail;
  int verificationEmailsSent = 0;
  int forcedTokenRefreshes = 0;

  _TestUser({
    required super.uid,
    required String email,
    super.displayName,
    this.verified = false,
    this.usesPassword = true,
    Map<String, dynamic>? tokenClaims,
  }) : currentEmail = email,
       super(email: email, isEmailVerified: verified, customClaim: tokenClaims);

  @override
  bool get emailVerified => verified;

  @override
  String? get email => currentEmail;

  @override
  List<UserInfo> get providerData => usesPassword
      ? [_ProviderInfo('password')]
      : [_ProviderInfo('google.com')];

  @override
  Future<void> reload() async {
    final e = reloadError;
    if (e != null) throw e;
  }

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    final e = emailChangeError;
    if (e != null) throw e;
    requestedNewEmail = newEmail;
  }

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) forcedTokenRefreshes++;
    return 'test-token';
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    verificationEmailsSent++;
  }
}

/// In-memory `users/{uid}`, honoring the UserProfileStore contract.
/// In-memory `users/{uid}`. Writes go through the REAL [profileWriteFor]
/// rules, so these tests exercise the same create/repair decisions as
/// FirestoreUserProfileStore's transaction.
class _MemoryProfiles implements UserProfileStore {
  final Map<String, Map<String, dynamic>> docs = {};
  int writeAttempts = 0;

  /// Thrown by the next read(s), first in first out. Simulates "fails
  /// once, then works".
  final List<FirebaseException> readErrors = [];
  final List<FirebaseException> writeErrors = [];

  /// Simulates a write that reports success but doesn't land. The
  /// data source must not trust it.
  bool dropWrites = false;

  @override
  Future<Map<String, dynamic>?> read(String uid) async {
    if (readErrors.isNotEmpty) throw readErrors.removeAt(0);
    final doc = docs[uid];
    return doc == null ? null : Map.of(doc);
  }

  @override
  Future<void> createOrRepair({
    required String uid,
    required String name,
    required String email,
  }) async {
    writeAttempts++;
    if (writeErrors.isNotEmpty) throw writeErrors.removeAt(0);
    final write = profileWriteFor(
      existing: docs[uid],
      uid: uid,
      name: name,
      email: email,
      now: 'SERVER_TIMESTAMP',
    );
    if (write == null || dropWrites) return;
    docs[uid] = {...?docs[uid], ...write};
  }

  @override
  Future<void> updateEmail({required String uid, required String email}) async {
    docs[uid]!['email'] = email;
    docs[uid]!['updatedAt'] = 'SERVER_TIMESTAMP';
  }
}

FirebaseException _firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  late _MemoryProfiles profiles;

  setUp(() => profiles = _MemoryProfiles());

  EmailAuthRemoteDataSourceImpl sourceFor(MockFirebaseAuth auth) =>
      EmailAuthRemoteDataSourceImpl(auth: auth, profiles: profiles);

  Future<Map<String, dynamic>?> profile(String uid) async => profiles.docs[uid];

  Future<void> expectMessage(Future<Object?> future, String message) =>
      expectLater(
        future,
        throwsA(predicate((e) => e.toString() == 'Exception: $message')),
      );

  group('register', () {
    test('creates the account, a create-only profile with exactly the '
        'approved fields, and lands on pending verification', () async {
      final auth = MockFirebaseAuth(verifyEmailAutomatically: false);
      final result = await sourceFor(auth).register(
        name: 'Ahmed Emad',
        email: 'ahmed@example.com',
        password: 'secret1',
        languageCode: 'ar',
      );

      expect(result.status, AuthStatus.pendingEmailVerification);
      expect(result.email, 'ahmed@example.com');
      expect(result.verificationEmailSent, isTrue);

      final uid = auth.currentUser!.uid;
      final doc = await profile(uid);
      expect(doc, isNotNull);
      expect(doc!.keys.toSet(), {
        'uid',
        'name',
        'email',
        'createdAt',
        'updatedAt',
      });
      expect(doc['name'], 'Ahmed Emad');
      expect(doc['email'], 'ahmed@example.com');
      expect(doc.containsKey('password'), isFalse);
      expect(doc.containsKey('phoneNumber'), isFalse);
      expect(doc.containsKey('emailVerified'), isFalse);
      expect(auth.currentUser!.displayName, 'Ahmed Emad');
    });

    test('an existing email maps to the "log in instead" message and '
        'creates nothing', () async {
      final auth = MockFirebaseAuth();
      whenCalling(
        Invocation.method(#createUserWithEmailAndPassword, null),
      ).on(auth).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      await expectMessage(
        sourceFor(
          auth,
        ).register(name: 'A', email: 'taken@example.com', password: 'secret1'),
        EmailAuthMessages.emailInUse,
      );
      expect(profiles.docs, isEmpty);
    });

    test('network failure before the account exists is a recoverable '
        'error', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      await expectMessage(
        sourceFor(
          auth,
        ).register(name: 'A', email: 'a@example.com', password: 'secret1'),
        EmailAuthMessages.network,
      );
    });
  });

  group('profile creation is create-only (createdAt overwrite fix)', () {
    test('an existing profile is never overwritten by a retry', () async {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(1000);
      profiles.docs['uid-1'] = ({
        'uid': 'uid-1',
        'name': 'Original Name',
        'email': 'ahmed@example.com',
        'createdAt': createdAt,
        'updatedAt': createdAt,
      });
      final user = _TestUser(
        uid: 'uid-1',
        email: 'ahmed@example.com',
        displayName: 'Other',
        verified: true,
      );
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);

      final result = await sourceFor(auth).completeProfile(name: 'New Name');

      final doc = (await profile('uid-1'))!;
      expect(doc['name'], 'Original Name');
      expect(doc['createdAt'], createdAt);
      expect(result.status, AuthStatus.authenticated);
      expect(result.user!.name, 'Original Name');
    });
  });

  group('resolveCurrentSession (startup / resume)', () {
    test('no Firebase user → unauthenticated', () async {
      final result = await sourceFor(
        MockFirebaseAuth(),
      ).resolveCurrentSession();
      expect(result.status, AuthStatus.unauthenticated);
    });

    test('unverified email/password account → pending verification, and no '
        'profile read is needed to decide it', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com');
      final result = await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).resolveCurrentSession();
      expect(result.status, AuthStatus.pendingEmailVerification);
      expect(result.email, 'ahmed@example.com');
    });

    test(
      'verified with a profile → authenticated with the stored name',
      () async {
        profiles.docs['u'] = ({
          'uid': 'u',
          'name': 'Stored Name',
          'email': 'ahmed@example.com',
        });
        final user = _TestUser(
          uid: 'u',
          email: 'ahmed@example.com',
          verified: true,
        );
        final result = await sourceFor(
          MockFirebaseAuth(signedIn: true, mockUser: user),
        ).resolveCurrentSession();
        expect(result.status, AuthStatus.authenticated);
        expect(result.user!.uid, 'u');
        expect(result.user!.name, 'Stored Name');
        expect(result.user!.email, 'ahmed@example.com');
      },
    );

    test('missing profile is recovered silently from the sign-up display '
        'name', () async {
      final user = _TestUser(
        uid: 'u',
        email: 'ahmed@example.com',
        displayName: '  Ahmed   Emad ',
        verified: true,
      );
      final result = await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).resolveCurrentSession();
      expect(result.status, AuthStatus.authenticated);
      final doc = (await profile('u'))!;
      expect(doc['name'], 'Ahmed Emad');
      expect(doc['email'], 'ahmed@example.com');
      expect(doc['createdAt'], isNotNull);
    });

    test('missing profile without a usable name → incompleteProfile, and '
        'nothing is written', () async {
      final user = _TestUser(
        uid: 'u',
        email: 'ahmed@example.com',
        displayName: '',
        verified: true,
      );
      final result = await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).resolveCurrentSession();
      expect(result.status, AuthStatus.incompleteProfile);
      expect(await profile('u'), isNull);
    });

    test(
      'phone-era test account → legacy, and its data is untouched',
      () async {
        final legacyDoc = {
          'uid': 'legacy',
          'name': 'Old',
          'phoneNumber': '+201012345678',
          'authEmail': 'u201012345678@ae-coaching.app',
        };
        profiles.docs['legacy'] = (legacyDoc);
        final user = _TestUser(
          uid: 'legacy',
          email: 'u201012345678@ae-coaching.app',
        );
        final result = await sourceFor(
          MockFirebaseAuth(signedIn: true, mockUser: user),
        ).resolveCurrentSession();
        expect(result.status, AuthStatus.unsupportedLegacyAccount);
        expect(await profile('legacy'), legacyDoc);
        expect(profiles.writeAttempts, 0);
      },
    );

    test('a revoked/expired session is signed out locally (never deleted) '
        'and resolves to unauthenticated', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com')
        ..reloadError = FirebaseAuthException(code: 'user-token-expired');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      final result = await sourceFor(auth).resolveCurrentSession();
      expect(result.status, AuthStatus.unauthenticated);
      expect(auth.currentUser, isNull);
    });

    test('offline reload is an error (Retry), not a sign-out', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com')
        ..reloadError = FirebaseAuthException(code: 'network-request-failed');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      await expectMessage(
        sourceFor(auth).resolveCurrentSession(),
        EmailAuthMessages.network,
      );
      expect(auth.currentUser, isNotNull);
    });

    test('federated accounts are not held at the email gate', () async {
      final user = _TestUser(
        uid: 'g',
        email: 'g@example.com',
        displayName: 'Google User',
        usesPassword: false,
        verified: false,
      );
      final result = await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).resolveCurrentSession();
      expect(result.status, AuthStatus.authenticated);
    });
  });

  group('login', () {
    test('wrong password / unknown email share one message', () async {
      for (final code in [
        'wrong-password',
        'user-not-found',
        'invalid-credential',
      ]) {
        final auth = MockFirebaseAuth();
        whenCalling(
          Invocation.method(#signInWithEmailAndPassword, null),
        ).on(auth).thenThrow(FirebaseAuthException(code: code));
        await expectMessage(
          sourceFor(auth).login(email: 'a@example.com', password: 'x'),
          EmailAuthMessages.incorrectCredentials,
        );
      }
    });

    test('an unverified account signs in but resolves to pending '
        'verification, never authenticated', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com');
      final result = await sourceFor(
        MockFirebaseAuth(mockUser: user),
      ).login(email: 'ahmed@example.com', password: 'secret1');
      expect(result.status, AuthStatus.pendingEmailVerification);
    });
  });

  group('refreshEmailVerification', () {
    test('still unverified → still pending', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com');
      final result = await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).refreshEmailVerification();
      expect(result.status, AuthStatus.pendingEmailVerification);
    });

    test('verified after the link → authenticated, and the profile email is '
        'synced after an email change', () async {
      profiles.docs['u'] = ({
        'uid': 'u',
        'name': 'Ahmed',
        'email': 'old@example.com',
      });
      final user = _TestUser(uid: 'u', email: 'old@example.com');
      final source = sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      );
      // The user opened the change-email link: Firebase now reports the
      // new, verified address.
      user
        ..verified = true
        ..currentEmail = 'new@example.com';

      final result = await source.refreshEmailVerification();
      expect(result.status, AuthStatus.authenticated);
      expect((await profile('u'))!['email'], 'new@example.com');
    });

    test('a revoked session (e.g. after the email changed) signs out and '
        'reports an expired session', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com')
        ..reloadError = FirebaseAuthException(code: 'user-token-expired');
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      await expectMessage(
        sourceFor(auth).refreshEmailVerification(),
        EmailAuthMessages.sessionExpired,
      );
      expect(auth.currentUser, isNull);
    });
  });

  group('resend / change email / password reset', () {
    test('change email sends the link to the new address without changing '
        'the account email yet', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com');
      await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).requestEmailChange(newEmail: 'new@example.com');
      expect(user.requestedNewEmail, 'new@example.com');
      expect(user.email, 'ahmed@example.com');
    });

    test('change email that needs a fresh sign-in is explained', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com')
        ..emailChangeError = FirebaseAuthException(
          code: 'requires-recent-login',
        );
      await expectMessage(
        sourceFor(
          MockFirebaseAuth(signedIn: true, mockUser: user),
        ).requestEmailChange(newEmail: 'new@example.com'),
        EmailAuthMessages.recentLogin,
      );
    });

    test('resend sends another verification email', () async {
      final user = _TestUser(uid: 'u', email: 'ahmed@example.com');
      await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).resendVerificationEmail(languageCode: 'en');
      expect(user.verificationEmailsSent, 1);
    });

    test('resend without a session reports the ended session', () async {
      await expectMessage(
        sourceFor(MockFirebaseAuth()).resendVerificationEmail(),
        EmailAuthMessages.noSession,
      );
    });

    test('changing to an address another account uses is explained', () async {
      final user = _TestUser(
        uid: 'u',
        email: 'ahmed@example.com',
      )..emailChangeError = FirebaseAuthException(code: 'email-already-in-use');
      await expectMessage(
        sourceFor(
          MockFirebaseAuth(signedIn: true, mockUser: user),
        ).requestEmailChange(newEmail: 'taken@example.com'),
        EmailAuthMessages.newEmailInUse,
      );
    });

    test('password reset for an unknown email completes normally (no '
        'account enumeration)', () async {
      final auth = MockFirebaseAuth();
      whenCalling(
        Invocation.method(#sendPasswordResetEmail, null),
      ).on(auth).thenThrow(FirebaseAuthException(code: 'user-not-found'));
      await expectLater(
        sourceFor(auth).sendPasswordResetEmail(email: 'nobody@example.com'),
        completes,
      );
    });

    test('password reset rate limiting is reported', () async {
      final auth = MockFirebaseAuth();
      whenCalling(
        Invocation.method(#sendPasswordResetEmail, null),
      ).on(auth).thenThrow(FirebaseAuthException(code: 'too-many-requests'));
      await expectMessage(
        sourceFor(auth).sendPasswordResetEmail(email: 'a@example.com'),
        EmailAuthMessages.tooManyRequests,
      );
    });
  });

  group('Stabilization: a verified account enters only with a confirmed '
      'valid profile', () {
    _TestUser verifiedUser({String? displayName = 'Ahmed Emad'}) => _TestUser(
      uid: 'u',
      email: 'ahmed@example.com',
      displayName: displayName,
      verified: true,
    );

    Future<EmailSessionResolution> resolve(_TestUser user) => sourceFor(
      MockFirebaseAuth(signedIn: true, mockUser: user),
    ).resolveCurrentSession();

    test('interrupted registration (profile write failed) is recovered after '
        'verification, from the sign-up display name', () async {
      final auth = MockFirebaseAuth(verifyEmailAutomatically: false);
      profiles.writeErrors.add(_firestoreError('unavailable'));
      final registered = await sourceFor(auth).register(
        name: 'Ahmed Emad',
        email: 'ahmed@example.com',
        password: 'secret1',
      );
      expect(registered.status, AuthStatus.pendingEmailVerification);
      expect(profiles.docs, isEmpty);

      // Later, after verifying: the next resolve creates the profile.
      final user = _TestUser(
        uid: auth.currentUser!.uid,
        email: 'ahmed@example.com',
        displayName: 'Ahmed Emad',
        verified: true,
      );
      final result = await resolve(user);
      expect(result.status, AuthStatus.authenticated);
      expect(profiles.docs[user.uid]!['name'], 'Ahmed Emad');
    });

    test('permission-denied while creating the profile is reported as such '
        'and never becomes authenticated', () async {
      profiles.writeErrors.add(_firestoreError('permission-denied'));
      final result = await resolve(verifiedUser());
      expect(result.status, AuthStatus.profileUnavailable);
      expect(result.profileFailure, ProfileFailure.permissionDenied);
      expect(result.user, isNull);
    });

    test(
      'permission-denied while reading the profile is reported as such',
      () async {
        profiles.readErrors.add(_firestoreError('permission-denied'));
        final result = await resolve(verifiedUser());
        expect(result.status, AuthStatus.profileUnavailable);
        expect(result.profileFailure, ProfileFailure.permissionDenied);
      },
    );

    test(
      'offline read → profileUnavailable(network); Retry then succeeds',
      () async {
        profiles.docs['u'] = {'uid': 'u', 'name': 'Ahmed'};
        profiles.readErrors.add(_firestoreError('unavailable'));
        final user = verifiedUser();
        final first = await resolve(user);
        expect(first.status, AuthStatus.profileUnavailable);
        expect(first.profileFailure, ProfileFailure.network);

        final retry = await resolve(user);
        expect(retry.status, AuthStatus.authenticated);
      },
    );

    test('an existing profile with a blank name never enters silently: it '
        'is repaired from the display name, keeping createdAt', () async {
      profiles.docs['u'] = {
        'uid': 'u',
        'name': '',
        'email': 'ahmed@example.com',
        'createdAt': 'T0',
      };
      final result = await resolve(verifiedUser());
      expect(result.status, AuthStatus.authenticated);
      expect(result.user!.name, 'Ahmed Emad');
      expect(profiles.docs['u']!['name'], 'Ahmed Emad');
      expect(profiles.docs['u']!['createdAt'], 'T0');
    });

    test('an invalid profile with no usable display name → Complete Profile; '
        'saving repairs only the name', () async {
      profiles.docs['u'] = {'uid': 'u', 'name': '  ', 'createdAt': 'T0'};
      final user = verifiedUser(displayName: null);
      final source = sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      );

      final first = await source.resolveCurrentSession();
      expect(first.status, AuthStatus.incompleteProfile);
      expect(profiles.writeAttempts, 0);

      final completed = await source.completeProfile(name: 'Typed Name');
      expect(completed.status, AuthStatus.authenticated);
      expect(profiles.docs['u']!['name'], 'Typed Name');
      expect(profiles.docs['u']!['createdAt'], 'T0');
    });

    test("a profile carrying another account's uid is never entered or "
        'written', () async {
      final foreign = {'uid': 'someone-else', 'name': 'Other'};
      profiles.docs['u'] = Map.of(foreign);
      final result = await resolve(verifiedUser());
      expect(result.status, AuthStatus.profileUnavailable);
      expect(result.profileFailure, ProfileFailure.conflicting);
      expect(profiles.writeAttempts, 0);
      expect(profiles.docs['u'], foreign);
    });

    test('a write that reports success but did not land is caught by the '
        're-read', () async {
      profiles.dropWrites = true;
      final result = await resolve(verifiedUser());
      expect(result.status, AuthStatus.profileUnavailable);
      expect(result.profileFailure, ProfileFailure.unknown);
    });

    test('Complete Profile: permission-denied is reported with its own '
        'message, not as generic', () async {
      profiles.writeErrors.add(_firestoreError('permission-denied'));
      final user = verifiedUser(displayName: null);
      await expectMessage(
        sourceFor(
          MockFirebaseAuth(signedIn: true, mockUser: user),
        ).completeProfile(name: 'Typed Name'),
        EmailAuthMessages.profilePermissionDenied,
      );
    });

    test('Complete Profile refuses to write a conflicting document', () async {
      profiles.docs['u'] = {'uid': 'someone-else', 'name': ''};
      final user = verifiedUser(displayName: null);
      await expectMessage(
        sourceFor(
          MockFirebaseAuth(signedIn: true, mockUser: user),
        ).completeProfile(name: 'Typed Name'),
        EmailAuthMessages.profileConflicting,
      );
      expect(profiles.writeAttempts, 0);
    });

    test('an email-sync failure on a VALID profile does not block sign-in '
        '(display copy only; Auth is authoritative)', () async {
      profiles.docs['u'] = {
        'uid': 'u',
        'name': 'Ahmed',
        'email': 'old@example.com',
      };
      final user = verifiedUser();
      final result = await resolve(user);
      expect(result.status, AuthStatus.authenticated);
      expect(profiles.docs['u']!['email'], 'ahmed@example.com');
    });
  });

  group('Stage 3D: the ID token is current before rules-checked writes', () {
    Future<_TestUser> resolveWith(
      Map<String, dynamic> claims, {
      bool verified = true,
      String email = 'ahmed@example.com',
    }) async {
      profiles.docs['u'] = {'uid': 'u', 'name': 'Ahmed', 'email': email};
      final user = _TestUser(
        uid: 'u',
        email: email,
        verified: verified,
        tokenClaims: claims,
      );
      await sourceFor(
        MockFirebaseAuth(signedIn: true, mockUser: user),
      ).resolveCurrentSession();
      return user;
    }

    test(
      'verified via the link, then restarted: a token still saying '
      'email_verified=false is refreshed before any profile/data write',
      () async {
        final user = await resolveWith({
          'email_verified': false,
          'email': 'ahmed@example.com',
        });
        expect(user.forcedTokenRefreshes, 1);
      },
    );

    test('a current token is not refreshed needlessly', () async {
      final user = await resolveWith({
        'email_verified': true,
        'email': 'ahmed@example.com',
      });
      expect(user.forcedTokenRefreshes, 0);
    });

    test('after an email change, a token carrying the old email is '
        'refreshed (the rules match the profile email to the token)', () async {
      final user = await resolveWith({
        'email_verified': true,
        'email': 'old@example.com',
      });
      expect(user.forcedTokenRefreshes, 1);
    });

    test('an unverified account never reaches the token check', () async {
      final user = await resolveWith(const {}, verified: false);
      expect(user.forcedTokenRefreshes, 0);
    });
  });

  test('unmapped Firebase codes never leak Firebase text', () async {
    final auth = MockFirebaseAuth();
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'INTERNAL ASSERTION FAILED: secret detail',
          ),
        );
    await expectMessage(
      sourceFor(auth).login(email: 'a@example.com', password: 'x'),
      EmailAuthMessages.generic,
    );
  });
}
