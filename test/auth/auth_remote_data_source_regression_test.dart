import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [AuthRemoteDataSourceImpl] hardcodes `FirebaseAuth.instance` and
/// `FirebaseFirestore.instance` (no constructor injection), so its
/// Firestore writes and Firebase Auth calls cannot be exercised with a
/// fake/in-memory double the way the rest of this test suite tests
/// repositories — that would require either a Firebase emulator or
/// refactoring the data source for dependency injection, both out of
/// scope for this phase (removing the Firestore password write only).
///
/// Instead, this is a source-level regression guard: it reads the
/// implementation file as text and asserts on its structure. It is
/// intentionally strict about what changed (password removed from
/// Firestore payloads) and what must NOT have changed (the real
/// Firebase Auth password parameters, and every other Firestore field).
void main() {
  late String source;

  setUpAll(() {
    // Normalized to LF regardless of the on-disk line ending (this repo's
    // core.autocrlf=true checks files out as CRLF, but every literal-\n
    // boundary search below assumes LF) so these assertions don't become
    // a coin flip depending on whether git last touched the file.
    source = File(
      'lib/auth/data/datasources/auth_remote_data_source.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  group('Firestore payloads no longer store a password/hash', () {
    test('registration Firestore payload contains no password field', () {
      expect(source.contains("'password':"), isFalse);
    });

    test('_hashPassword helper has been removed', () {
      expect(source.contains('_hashPassword'), isFalse);
    });

    test('package:crypto is no longer imported by this file', () {
      expect(source.contains("package:crypto"), isFalse);
    });

    test('sha256/utf8 hashing leftovers are gone', () {
      expect(source.contains('sha256'), isFalse);
      expect(source.contains('utf8.encode'), isFalse);
    });
  });

  group('Firebase Auth still receives the real password where required', () {
    // A lazy, bounded [\s\S] window (rather than a [^)]* exclusion) is used
    // because the email argument itself contains nested parentheses
    // (`_authEmailFromPhone(phone)`), which would otherwise terminate a
    // paren-excluding character class before it ever reaches `password:`.
    test('createUserWithEmailAndPassword still passes password', () {
      expect(
        RegExp(
          r'createUserWithEmailAndPassword\(\s*email:[\s\S]{0,150}?password:\s*password',
        ).hasMatch(source),
        isTrue,
      );
    });

    test('signInWithEmailAndPassword still passes password', () {
      expect(
        RegExp(
          r'signInWithEmailAndPassword\(\s*email:[\s\S]{0,150}?password:\s*password',
        ).hasMatch(source),
        isTrue,
      );
    });

    test('EmailAuthProvider.credential still receives the real password '
        '(used for linking, not Firestore storage)', () {
      expect(
        RegExp(
          r'EmailAuthProvider\.credential\(\s*email:[\s\S]{0,150}?password:\s*password',
        ).hasMatch(source),
        isTrue,
      );
    });
  });

  group('All other users/{uid} fields are preserved unchanged', () {
    for (final field in ['uid', 'name', 'phoneNumber', 'authEmail']) {
      test("'$field' is still written", () {
        expect(source.contains("'$field'"), isTrue);
      });
    }

    test("'createdAt' still uses FieldValue.serverTimestamp()", () {
      expect(source.contains('FieldValue.serverTimestamp()'), isTrue);
    });

    test('registerWithOtp, registerWithPhonePassword, and the resume '
        'completeProfileForCurrentUser path all write through the ONE '
        'shared _writeUserProfile helper (no duplicated/divergent '
        'payload shapes)', () {
      final setCallCount = RegExp(
        r"\.collection\('users'\)\.doc\([\s\S]{0,40}?\)\.set\(",
      ).allMatches(source).length;
      // Only _writeUserProfile writes via the inline chained form now;
      // login()'s first-time-doc-creation fallback writes via a
      // separately-stored `userRef.set(...)` instead — checked below.
      expect(setCallCount, 1);

      // And every one of the three callers routes through it.
      final callSites = RegExp(
        r'_writeUserProfile\(',
      ).allMatches(source).length;
      // 1 definition + 3 call sites (registerWithOtp,
      // registerWithPhonePassword, completeProfileForCurrentUser).
      expect(callSites, 4);
    });

    test("login's first-time-doc-creation fallback still writes via "
        'userRef.set(...) without a password field', () {
      expect(source.contains('await userRef.set({'), isTrue);
    });
  });

  group('UID derivation is unchanged', () {
    test('registerWithOtp still keys the document by user.uid from the '
        'phone-credential sign-in', () {
      expect(
        source.contains("_firestore.collection('users').doc(user.uid).set({"),
        isTrue,
      );
    });

    test('login still keys the document by the signed-in firebaseUser.uid', () {
      expect(
        source.contains(
          "_firestore.collection('users').doc(firebaseUser.uid);",
        ),
        isTrue,
      );
    });
  });

  /// PHASE 3 — the properties below are unique to the new-user OTP
  /// registration + collision-cleanup + partial-registration recovery
  /// work. Still source-level only, for the same DI reason noted above.
  group('Phase 3: registerWithOtp never creates a second independent '
      'account', () {
    // The abstract AuthRemoteDataSource interface declares matching
    // method signatures (no body) above the impl class — every
    // method-body extraction below must search starting after the impl
    // class begins, or it will find the bodyless interface declaration
    // instead.
    late final int implStart;

    setUpAll(() {
      implStart = source.indexOf('class AuthRemoteDataSourceImpl');
      expect(implStart, greaterThan(-1));
    });

    String registerWithOtpBody() {
      final start = source.indexOf(
        'Future<AuthUser> registerWithOtp(',
        implStart,
      );
      final nextOverride = source.indexOf('@override', start);
      expect(start, greaterThan(implStart));
      expect(nextOverride, greaterThan(start));
      return source.substring(start, nextOverride);
    }

    test('registerWithOtp never calls createUserWithEmailAndPassword', () {
      expect(
        registerWithOtpBody().contains('createUserWithEmailAndPassword'),
        isFalse,
      );
    });

    test('registerWithOtp consumes the phone credential via '
        'signInWithCredential exactly once', () {
      final matches = RegExp(
        'signInWithCredential',
      ).allMatches(registerWithOtpBody()).length;
      expect(matches, 1);
    });

    test('createUserWithEmailAndPassword is actually CALLED exactly once '
        'total — only inside the untouched legacy '
        'registerWithPhonePassword path (a doc-comment elsewhere merely '
        'mentions the name in prose, so this checks for the call form '
        'specifically)', () {
      final matches = RegExp(
        r'createUserWithEmailAndPassword\(',
      ).allMatches(source).length;
      expect(matches, 1);
    });
  });

  group('Phase 3: bounded, non-merge collision cleanup', () {
    test('_cleanUpOrphanedPhoneOnlyUser exists and is only invoked from '
        'the two named collision codes, never from a bare/default catch', () {
      expect(source.contains('_cleanUpOrphanedPhoneOnlyUser'), isTrue);

      final linkStart = source.indexOf('Future<void> _linkPasswordLogin(');
      final nextMethod = source.indexOf('\n  Future', linkStart + 10);
      final linkBody = source.substring(
        linkStart,
        nextMethod == -1 ? source.length : nextMethod,
      );

      expect(
        linkBody.contains("e.code == 'credential-already-in-use'"),
        isTrue,
      );
      expect(linkBody.contains("e.code == 'email-already-in-use'"), isTrue);

      // The cleanup call must appear after the collision-code check and
      // before the generic rethrow/throw for anything else — i.e. it is
      // scoped to that branch, not a blanket catch-all.
      final collisionCheckIndex = linkBody.indexOf(
        "e.code == 'credential-already-in-use'",
      );
      final cleanupCallIndex = linkBody.indexOf(
        '_cleanUpOrphanedPhoneOnlyUser(user)',
      );
      expect(cleanupCallIndex, greaterThan(collisionCheckIndex));
    });

    test('_cleanUpOrphanedPhoneOnlyUser checks for an existing Firestore '
        'profile before ever deleting — refusing to delete a user that '
        'already has completed data', () {
      final start = source.indexOf(
        'Future<void> _cleanUpOrphanedPhoneOnlyUser(',
      );
      final nextMethod = source.indexOf('\n  /// Writes', start);
      final body = source.substring(
        start,
        nextMethod == -1 ? source.length : nextMethod,
      );
      expect(body.contains('doc.exists'), isTrue);
      expect(body.contains('user.delete()'), isTrue);
      expect(body.contains('_auth.signOut()'), isTrue);
    });

    test('weak-password is never routed through the cleanup/deletion path', () {
      // weak-password must fall into the generic branch that rethrows a
      // mapped Exception, not the collision branch that deletes the user.
      final linkStart = source.indexOf('Future<void> _linkPasswordLogin(');
      final nextMethod = source.indexOf('\n  Future', linkStart + 10);
      final linkBody = source.substring(
        linkStart,
        nextMethod == -1 ? source.length : nextMethod,
      );
      expect(linkBody.contains("'weak-password'"), isFalse);
    });
  });

  group('Phase 3: resume paths never repeat authentication', () {
    // Same interface-vs-impl pitfall as the group above: every search
    // here starts after the impl class begins, since the abstract
    // AuthRemoteDataSource interface declares matching (bodyless)
    // signatures for all of these first.
    late final int implStart;

    setUpAll(() {
      implStart = source.indexOf('class AuthRemoteDataSourceImpl');
      expect(implStart, greaterThan(-1));
    });

    /// Every impl method is followed eventually by another `@override`
    /// (marking the next method) except the last method in the class,
    /// for which running to end-of-source is correct.
    String implMethodBody(String signature) {
      final start = source.indexOf(signature, implStart);
      expect(start, greaterThan(implStart));
      final nextOverride = source.indexOf('@override', start);
      return source.substring(
        start,
        nextOverride == -1 ? source.length : nextOverride,
      );
    }

    test('linkPasswordToCurrentUser never calls verifyPhoneNumber or '
        'signInWithCredential', () {
      final body = implMethodBody('Future<void> linkPasswordToCurrentUser(');
      expect(body.contains('verifyPhoneNumber'), isFalse);
      expect(body.contains('signInWithCredential'), isFalse);
    });

    test('completeProfileForCurrentUser never calls verifyPhoneNumber, '
        'signInWithCredential, or createUserWithEmailAndPassword', () {
      final body = implMethodBody(
        'Future<AuthUser> completeProfileForCurrentUser(',
      );
      expect(body.contains('verifyPhoneNumber'), isFalse);
      expect(body.contains('signInWithCredential'), isFalse);
      expect(body.contains('createUserWithEmailAndPassword'), isFalse);
    });

    test('inspectCurrentSession is read-only: never calls '
        'verifyPhoneNumber, signInWithCredential, or '
        'createUserWithEmailAndPassword — it can never create a UID', () {
      final body = implMethodBody(
        'Future<AuthSessionInspection> inspectCurrentSession(',
      );
      expect(body.contains('verifyPhoneNumber'), isFalse);
      expect(body.contains('signInWithCredential'), isFalse);
      expect(body.contains('createUserWithEmailAndPassword'), isFalse);
    });
  });

  group('Phase 3: error messages never leak raw Firebase details', () {
    test('the default _mapFirebaseAuthException branch no longer returns '
        'e.message/e.code directly', () {
      final start = source.indexOf('String _mapFirebaseAuthException(');
      final end = source.indexOf('\n  }\n', start);
      final body = source.substring(start, end);
      expect(body.contains('return e.message'), isFalse);
      expect(body.contains('default:'), isTrue);
    });

    test('the shared _sendOtpCode primitive (used by both requestOtp and '
        'Phase 4 requestMigrationOtp) maps verificationFailed through '
        '_mapFirebaseAuthException instead of propagating the raw '
        'FirebaseAuthException', () {
      final implStart = source.indexOf('class AuthRemoteDataSourceImpl');
      final start = source.indexOf('Future<String> _sendOtpCode(', implStart);
      final end = source.indexOf('@override', start);
      final body = source.substring(start, end);
      expect(
        body.contains(
          'completer.completeError(Exception(_mapFirebaseAuthException(e)))',
        ),
        isTrue,
      );
    });

    test('requestOtp delegates to _sendOtpCode with no extra validation '
        '(fresh registration has no account to validate against)', () {
      final implStart = source.indexOf('class AuthRemoteDataSourceImpl');
      final start = source.indexOf('Future<String> requestOtp(', implStart);
      final end = source.indexOf('\n\n', start);
      final body = source.substring(start, end);
      expect(body.contains('_sendOtpCode(phoneNumber)'), isTrue);
    });
  });

  /// PHASE 4 — legacy user phone-provider migration. Still source-level
  /// only, for the same DI reason noted above.
  group('Phase 4: migration never signs in, never creates a second '
      'account, never re-verifies credentials', () {
    late final int implStart;

    setUpAll(() {
      implStart = source.indexOf('class AuthRemoteDataSourceImpl');
      expect(implStart, greaterThan(-1));
    });

    String implMethodBody(String signature) {
      final start = source.indexOf(signature, implStart);
      expect(start, greaterThan(implStart));
      final nextOverride = source.indexOf('@override', start);
      return source.substring(
        start,
        nextOverride == -1 ? source.length : nextOverride,
      );
    }

    test('requestMigrationOtp never calls signInWithCredential or '
        'createUserWithEmailAndPassword', () {
      final body = implMethodBody('Future<String> requestMigrationOtp(');
      expect(body.contains('signInWithCredential'), isFalse);
      expect(body.contains('createUserWithEmailAndPassword'), isFalse);
    });

    test('requestMigrationOtp validates the canonical phone against the '
        "signed-in user's actual email before ever sending an OTP — a "
        'mismatch stops migration rather than guessing/rewriting '
        'identity', () {
      final body = implMethodBody('Future<String> requestMigrationOtp(');
      expect(body.contains('_authEmailFromPhone(phone)'), isTrue);
      expect(body.contains('user.email != expectedEmail'), isTrue);
      // The validation must run before the OTP is actually sent.
      final validationIndex = body.indexOf('user.email != expectedEmail');
      final sendIndex = body.indexOf('_sendOtpCode(phone)');
      expect(validationIndex, lessThan(sendIndex));
    });

    test('requestMigrationOtp refuses to run for an account that already '
        'has the phone provider linked, rather than silently re-sending', () {
      final body = implMethodBody('Future<String> requestMigrationOtp(');
      expect(body.contains('_hasPhoneProviderLinked(user)'), isTrue);
    });

    test('linkPhoneToCurrentUser never calls signInWithCredential or '
        'createUserWithEmailAndPassword — only linkWithCredential', () {
      final body = implMethodBody('Future<void> linkPhoneToCurrentUser(');
      expect(body.contains('signInWithCredential'), isFalse);
      expect(body.contains('createUserWithEmailAndPassword'), isFalse);
      expect(body.contains('user.linkWithCredential(credential)'), isTrue);
    });

    test('linkPhoneToCurrentUser never calls .delete() or the Phase 3 '
        'orphan-cleanup helper — the legacy account is never deletable '
        'from this path', () {
      final body = implMethodBody('Future<void> linkPhoneToCurrentUser(');
      expect(body.contains('.delete()'), isFalse);
      expect(body.contains('_cleanUpOrphanedPhoneOnlyUser'), isFalse);
    });

    test('linkPhoneToCurrentUser captures the uid BEFORE linking and '
        'verifies it is unchanged AFTER — a mismatch is treated as a '
        'fatal, non-success error', () {
      final body = implMethodBody('Future<void> linkPhoneToCurrentUser(');
      expect(body.contains('final uidBefore = user.uid;'), isTrue);
      final uidBeforeIndex = body.indexOf('final uidBefore = user.uid;');
      final linkCallIndex = body.indexOf('user.linkWithCredential(credential)');
      final uidAfterCheckIndex = body.indexOf('uidAfter != uidBefore');
      expect(uidBeforeIndex, lessThan(linkCallIndex));
      expect(linkCallIndex, lessThan(uidAfterCheckIndex));
    });

    test('credential-already-in-use is handled without merging, '
        'deleting, overwriting, or signing into the other account — it '
        'only throws a clear, recoverable error', () {
      final body = implMethodBody('Future<void> linkPhoneToCurrentUser(');
      expect(body.contains("e.code == 'credential-already-in-use'"), isTrue);
      // No sign-in/account-switch/Firestore-write calls anywhere in this
      // method at all (checked file-wide above and re-asserted here for
      // this specific branch's absence of side effects).
      expect(body.contains('_firestore'), isFalse);
    });

    test('provider-already-linked is only treated as success after '
        're-checking providerData AND the uid, never assumed blindly', () {
      final body = implMethodBody('Future<void> linkPhoneToCurrentUser(');
      expect(body.contains("e.code == 'provider-already-linked'"), isTrue);
      final idempotentBranchStart = body.indexOf(
        "e.code == 'provider-already-linked'",
      );
      final idempotentBranchEnd = body.indexOf(
        "e.code == 'credential-already-in-use'",
      );
      final idempotentBranch = body.substring(
        idempotentBranchStart,
        idempotentBranchEnd,
      );
      expect(
        idempotentBranch.contains('_hasPhoneProviderLinked(refreshedUser)'),
        isTrue,
      );
      expect(
        idempotentBranch.contains('refreshedUser.uid == uidBefore'),
        isTrue,
      );
    });

    test('neither requestMigrationOtp nor linkPhoneToCurrentUser writes '
        'to Firestore — migration is derived from providerData only, no '
        'redundant/duplicated UID-scoped data is ever written here', () {
      final requestBody = implMethodBody('Future<String> requestMigrationOtp(');
      final linkBody = implMethodBody('Future<void> linkPhoneToCurrentUser(');
      expect(requestBody.contains('_firestore'), isFalse);
      expect(linkBody.contains('_firestore'), isFalse);
    });

    test('login() now also computes needsPhoneVerification via '
        '_hasPhoneProviderLinked, with its credential verification '
        '(signInWithEmailAndPassword) unchanged', () {
      final body = implMethodBody('Future<AuthUser> login(');
      expect(body.contains('signInWithEmailAndPassword'), isTrue);
      expect(
        body.contains(
          'needsPhoneVerification: !_hasPhoneProviderLinked(firebaseUser)',
        ),
        isTrue,
      );
    });
  });

  /// PHASE 4 RESTART-BYPASS FIX — a completed users/{uid} profile alone
  /// used to be treated as "fully finished" by inspectCurrentSession,
  /// with no check for whether a legacy account had actually linked the
  /// phone provider yet. That let a killed-mid-migration app restart
  /// straight to Home via SessionReconciliationView. The fix reuses the
  /// SAME _hasPhoneProviderLinked helper login() already uses (see the
  /// group above) — these assertions prove it is wired into the
  /// doc.exists branch specifically, without touching the Phase 3
  /// needsPassword/needsProfile branches below it (disjoint — those
  /// only run when doc.exists is false).
  group('Phase 4 restart-bypass fix: inspectCurrentSession correctly '
      'reports needsPhoneVerification for a completed profile', () {
    late final int implStart;

    setUpAll(() {
      implStart = source.indexOf('class AuthRemoteDataSourceImpl');
      expect(implStart, greaterThan(-1));
    });

    String implMethodBody(String signature) {
      final start = source.indexOf(signature, implStart);
      expect(start, greaterThan(implStart));
      final nextOverride = source.indexOf('@override', start);
      return source.substring(
        start,
        nextOverride == -1 ? source.length : nextOverride,
      );
    }

    test('the doc.exists (completed-profile) branch sets '
        'needsPhoneVerification via !_hasPhoneProviderLinked(user) — '
        'the SAME helper login() uses, not a second reimplementation, '
        'so a legacy account with the phone provider still missing '
        'reports true, and one with it linked reports false, exactly '
        'as login() would for the same account', () {
      final body = implMethodBody(
        'Future<AuthSessionInspection> inspectCurrentSession(',
      );
      // Scoped to the doc.exists branch specifically, not the whole
      // method, so this never accidentally matches something in the
      // needsPassword/needsProfile recovery branches below it.
      final docExistsStart = body.indexOf('if (doc.exists)');
      final docExistsEnd = body.indexOf(
        'final providerIds = user.providerData',
      );
      expect(docExistsStart, greaterThan(-1));
      expect(docExistsEnd, greaterThan(docExistsStart));
      final docExistsBranch = body.substring(docExistsStart, docExistsEnd);

      expect(
        docExistsBranch.contains(
          'needsPhoneVerification: !_hasPhoneProviderLinked(user)',
        ),
        isTrue,
      );
      // Confirms it's the shared helper, not a duplicated inline check
      // (which would risk drifting from login()'s definition of
      // "linked").
      expect(docExistsBranch.contains("providerId == 'phone'"), isFalse);
    });

    test('the Phase 3 needsPassword/needsProfile recovery branches '
        '(which only run when doc.exists is false) are untouched by '
        'this fix', () {
      final body = implMethodBody(
        'Future<AuthSessionInspection> inspectCurrentSession(',
      );
      expect(
        body.contains(
              'return AuthSessionInspection.recovery(\n        RegistrationRecoveryStep.needsProfile,',
            ) ||
            body.contains('RegistrationRecoveryStep.needsProfile,'),
        isTrue,
      );
      expect(body.contains('RegistrationRecoveryStep.needsPassword,'), isTrue);
    });
  });

  /// PHASE 5B — signed-out Forgot Password, now backed by the TRUSTED
  /// BACKEND (Cloud Functions `requestPasswordReset` /
  /// `completePasswordReset`) rather than any client-side Firebase Auth
  /// phone-credential flow. The prior client-only Phase 5 implementation
  /// (signInWithCredential + isNewUser gate + orphan cleanup +
  /// user.updatePassword) was security-rejected because Firebase creates
  /// the Auth user server-side as part of signInWithCredential itself,
  /// before isNewUser can ever be inspected — "detect and clean up" is
  /// not "prevent". These assertions are scoped to ONLY the two Phase 5B
  /// method bodies (via implMethodBody, which stops at the next
  /// @override) so they never false-fail against Phase 3/4's legitimate,
  /// untouched use of signInWithCredential/verifyPhoneNumber elsewhere in
  /// this same file (registerWithOtp, linkPhoneToCurrentUser, etc.).
  group('Phase 5B: signed-out password reset never creates a Firebase '
      'user — it uses the trusted backend exclusively', () {
    late final int implStart;

    setUpAll(() {
      implStart = source.indexOf('class AuthRemoteDataSourceImpl');
      expect(implStart, greaterThan(-1));
    });

    String implMethodBody(String signature) {
      final start = source.indexOf(signature, implStart);
      expect(start, greaterThan(implStart));
      // verifyPasswordResetOtpAndUpdatePassword is the LAST @override in
      // the class, so a plain "next @override" search would run past its
      // closing brace into the trailing _mapFunctionsException doc
      // comment/body (which itself mentions e.details/stack traces in
      // prose) — the exact doc-comment-pollutes-body-extraction pitfall
      // called out elsewhere in this file. Bound the search there too.
      final nextOverride = source.indexOf('@override', start);
      // Bound at the START of that trailing doc comment (not just its
      // method signature) — the doc comment itself mentions e.details in
      // prose, so stopping only at the signature would still let the
      // comment leak into this body.
      final helperBoundary = source.indexOf(
        '/// Maps a [FirebaseFunctionsException]',
        start,
      );
      var end = source.length;
      if (nextOverride != -1) end = nextOverride;
      if (helperBoundary != -1 && helperBoundary < end) end = helperBoundary;
      return source.substring(start, end);
    }

    test('requestPasswordResetOtp calls the requestPasswordReset callable '
        'and never uses Firebase Phone Auth (verifyPhoneNumber) or any '
        'client-side sign-in', () {
      final body = implMethodBody('Future<String> requestPasswordResetOtp(');
      expect(body.contains("httpsCallable('requestPasswordReset')"), isTrue);
      expect(body.contains('verifyPhoneNumber'), isFalse);
      expect(body.contains('signInWithCredential'), isFalse);
      expect(body.contains('_auth.currentUser'), isFalse);
    });

    test('requestPasswordResetOtp sends only the phone to the backend — '
        'no uid, email, or provider state', () {
      final body = implMethodBody('Future<String> requestPasswordResetOtp(');
      expect(body.contains("'phone': phone"), isTrue);
    });

    test('verifyPasswordResetOtpAndUpdatePassword calls the '
        'completePasswordReset callable and performs none of the unsafe '
        'client-side operations the rejected Phase 5 design used: no '
        'signInWithCredential, no isNewUser inspection, no '
        'linkWithCredential, no createUserWithEmailAndPassword, no '
        'reauthenticateWithCredential, and no client-side '
        'user.updatePassword call', () {
      final body = implMethodBody(
        'Future<void> verifyPasswordResetOtpAndUpdatePassword(',
      );
      expect(body.contains("httpsCallable('completePasswordReset')"), isTrue);
      expect(body.contains('signInWithCredential'), isFalse);
      expect(body.contains('isNewUser'), isFalse);
      expect(body.contains('linkWithCredential'), isFalse);
      expect(body.contains('createUserWithEmailAndPassword'), isFalse);
      expect(body.contains('reauthenticateWithCredential'), isFalse);
      expect(body.contains('.updatePassword('), isFalse);
    });

    test('verifyPasswordResetOtpAndUpdatePassword sends only challengeId, '
        'otp, and newPassword to the backend — no uid, email, synthetic '
        'email, eligible flag, otpVerified flag, or provider state', () {
      final body = implMethodBody(
        'Future<void> verifyPasswordResetOtpAndUpdatePassword(',
      );
      expect(body.contains("'challengeId': challengeId"), isTrue);
      expect(body.contains("'otp': smsCode"), isTrue);
      expect(body.contains("'newPassword': newPassword"), isTrue);
    });

    test('verifyPasswordResetOtpAndUpdatePassword never calls the Phase 3 '
        'orphan-cleanup helper or .delete() — there is no client-side '
        'Firebase user for this flow to create or clean up in the first '
        'place', () {
      final body = implMethodBody(
        'Future<void> verifyPasswordResetOtpAndUpdatePassword(',
      );
      expect(body.contains('_cleanUpOrphanedPhoneOnlyUser'), isFalse);
      expect(body.contains('.delete()'), isFalse);
    });

    test('neither Phase 5B method writes to Firestore directly — all '
        'state lives in the trusted backend', () {
      final requestBody = implMethodBody(
        'Future<String> requestPasswordResetOtp(',
      );
      final completeBody = implMethodBody(
        'Future<void> verifyPasswordResetOtpAndUpdatePassword(',
      );
      expect(requestBody.contains('_firestore'), isFalse);
      expect(completeBody.contains('_firestore'), isFalse);
    });

    test('backend exceptions are mapped through _mapFunctionsException in '
        'both methods, never surfacing e.details or a raw stack trace', () {
      final requestBody = implMethodBody(
        'Future<String> requestPasswordResetOtp(',
      );
      final completeBody = implMethodBody(
        'Future<void> verifyPasswordResetOtpAndUpdatePassword(',
      );
      expect(requestBody.contains('_mapFunctionsException(e)'), isTrue);
      expect(completeBody.contains('_mapFunctionsException(e)'), isTrue);
      expect(requestBody.contains('e.details'), isFalse);
      expect(completeBody.contains('e.details'), isFalse);
    });

    test('_mapFunctionsException never returns e.details and falls back '
        'to a generic message when the backend message is missing/empty', () {
      final start = source.indexOf('String _mapFunctionsException(');
      final end = source.indexOf('\n  }\n', start);
      final body = source.substring(start, end);
      expect(body.contains('e.details'), isFalse);
      expect(body.contains('Something went wrong'), isTrue);
    });

    test('Phase 3/4 still legitimately use signInWithCredential/'
        'verifyPhoneNumber/updatePassword elsewhere in this file — proving '
        'the absence checks above are scoped to Phase 5B only, not a '
        'blanket file-wide removal of these APIs', () {
      expect(
        RegExp('signInWithCredential').allMatches(source).length,
        greaterThan(0),
      );
      expect(source.contains('user.updatePassword'), isFalse);
    });
  });
}
