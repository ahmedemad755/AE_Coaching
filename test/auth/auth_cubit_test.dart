import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
import 'package:ae_coaching/auth/domain/usecases/complete_profile_for_current_user_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/inspect_session_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/link_password_to_current_user_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/link_phone_migration_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_phone_password_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_phone_migration_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_password_reset_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/reset_password_with_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// UNIT-TEST TIER: this fake sits at the [AuthRepository] boundary — no
/// Firebase Auth/Firestore SDK, no emulator, is ever involved. It proves
/// AuthCubit's own orchestration logic (which state it emits for which
/// repository outcome), not real Firebase provider-linking/collision
/// behavior. Real Firebase behavior (collision cleanup, provider
/// linking, Firestore payload shape) is covered separately by the
/// SOURCE-level regression tests in auth_remote_data_source_regression_test.dart,
/// which read AuthRemoteDataSourceImpl's actual implementation text —
/// neither tier is a substitute for real-device/emulator testing (see
/// the Phase 3 report's "known limitations" section).
class FakeAuthRepository implements AuthRepository {
  Exception? errorToThrow;
  String otpVerificationId = 'verification-id-123';
  AuthUser? userToReturn;
  AuthSessionInspection sessionInspection =
      const AuthSessionInspection.noSession();

  int requestOtpCalls = 0;
  int registerWithOtpCalls = 0;
  int registerWithPhonePasswordCalls = 0;
  int loginCalls = 0;
  int inspectCurrentSessionCalls = 0;
  int linkPasswordToCurrentUserCalls = 0;
  int completeProfileForCurrentUserCalls = 0;
  int requestMigrationOtpCalls = 0;
  int linkPhoneToCurrentUserCalls = 0;
  String? lastRequestMigrationOtpPhone;
  int requestPasswordResetOtpCalls = 0;
  int verifyPasswordResetOtpAndUpdatePasswordCalls = 0;
  String? lastRequestPasswordResetOtpPhone;

  @override
  Future<String> requestOtp(String phoneNumber) async {
    requestOtpCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return otpVerificationId;
  }

  @override
  Future<AuthUser> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  }) async {
    registerWithOtpCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return userToReturn ??
        AuthUser(uid: 'new-phone-uid', name: name, phoneNumber: phone);
  }

  @override
  Future<AuthUser> registerWithPhonePassword({
    required String name,
    required String phone,
    required String password,
  }) async {
    registerWithPhonePasswordCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return userToReturn ??
        AuthUser(uid: 'legacy-uid', name: name, phoneNumber: phone);
  }

  @override
  Future<AuthUser> login(String phone, String password) async {
    loginCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return userToReturn ??
        AuthUser(uid: 'login-uid', name: 'Test User', phoneNumber: phone);
  }

  @override
  Future<AuthSessionInspection> inspectCurrentSession() async {
    inspectCurrentSessionCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return sessionInspection;
  }

  @override
  Future<void> linkPasswordToCurrentUser({
    required String phone,
    required String password,
  }) async {
    linkPasswordToCurrentUserCalls++;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<AuthUser> completeProfileForCurrentUser({
    required String name,
    required String phone,
  }) async {
    completeProfileForCurrentUserCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return userToReturn ??
        AuthUser(uid: 'resume-uid', name: name, phoneNumber: phone);
  }

  @override
  Future<String> requestMigrationOtp(String phone) async {
    requestMigrationOtpCalls++;
    lastRequestMigrationOtpPhone = phone;
    if (errorToThrow != null) throw errorToThrow!;
    return otpVerificationId;
  }

  @override
  Future<void> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  }) async {
    linkPhoneToCurrentUserCalls++;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<String> requestPasswordResetOtp(String phone) async {
    requestPasswordResetOtpCalls++;
    lastRequestPasswordResetOtpPhone = phone;
    if (errorToThrow != null) throw errorToThrow!;
    return otpVerificationId;
  }

  @override
  Future<void> verifyPasswordResetOtpAndUpdatePassword({
    required String challengeId,
    required String smsCode,
    required String newPassword,
  }) async {
    verifyPasswordResetOtpAndUpdatePasswordCalls++;
    if (errorToThrow != null) throw errorToThrow!;
  }
}

AuthCubit _buildCubit(FakeAuthRepository repo) {
  return AuthCubit(
    loginUseCase: LoginUseCase(repo),
    requestOtpUseCase: RequestOtpUseCase(repo),
    registerWithOtpUseCase: RegisterWithOtpUseCase(repo),
    registerWithPhonePasswordUseCase: RegisterWithPhonePasswordUseCase(repo),
    inspectSessionUseCase: InspectSessionUseCase(repo),
    linkPasswordToCurrentUserUseCase: LinkPasswordToCurrentUserUseCase(repo),
    completeProfileForCurrentUserUseCase: CompleteProfileForCurrentUserUseCase(
      repo,
    ),
    requestPhoneMigrationOtpUseCase: RequestPhoneMigrationOtpUseCase(repo),
    linkPhoneMigrationUseCase: LinkPhoneMigrationUseCase(repo),
    requestPasswordResetOtpUseCase: RequestPasswordResetOtpUseCase(repo),
    resetPasswordWithOtpUseCase: ResetPasswordWithOtpUseCase(repo),
  );
}

void main() {
  late FakeAuthRepository repo;
  late AuthCubit cubit;

  setUp(() {
    repo = FakeAuthRepository();
    cubit = _buildCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('Successful new-user OTP registration', () {
    test(
      'requestOtp emits AuthOtpSent carrying the exact phone used',
      () async {
        await cubit.requestOtp('+201012345678');
        final state = cubit.state;
        expect(state, isA<AuthOtpSent>());
        expect((state as AuthOtpSent).phone, '+201012345678');
        expect((state).verificationId, repo.otpVerificationId);
      },
    );

    test('registerWithOtp emits AuthSuccess with the completed user only '
        'after the use case returns (i.e. after phone+link+profile all '
        'succeeded server-side)', () async {
      await cubit.registerWithOtp(
        verificationId: 'vid',
        smsCode: '123456',
        name: 'Ahmed',
        phone: '+201012345678',
        password: 'strongpass1',
      );
      final state = cubit.state;
      expect(state, isA<AuthSuccess>());
      expect((state as AuthSuccess).user?.uid, 'new-phone-uid');
      expect(repo.registerWithOtpCalls, 1);
    });
  });

  group('Wrong / expired / resend OTP', () {
    test('wrong OTP surfaces AuthError, not AuthSuccess', () async {
      repo.errorToThrow = Exception(
        'The code you entered is incorrect. Please try again.',
      );
      await cubit.registerWithOtp(
        verificationId: 'vid',
        smsCode: '000000',
        name: 'Ahmed',
        phone: '+201012345678',
        password: 'strongpass1',
      );
      expect(cubit.state, isA<AuthError>());
      expect((cubit.state as AuthError).message, contains('incorrect'));
    });

    test('expired OTP surfaces a clear AuthError', () async {
      repo.errorToThrow = Exception(
        'This code has expired. Please request a new one.',
      );
      await cubit.registerWithOtp(
        verificationId: 'vid',
        smsCode: '123456',
        name: 'Ahmed',
        phone: '+201012345678',
        password: 'strongpass1',
      );
      expect(cubit.state, isA<AuthError>());
      expect((cubit.state as AuthError).message, contains('expired'));
    });

    test(
      'resend OTP calls requestOtp again and updates the verificationId',
      () async {
        await cubit.requestOtp('+201012345678');
        expect(repo.requestOtpCalls, 1);
        repo.otpVerificationId = 'second-verification-id';
        await cubit.requestOtp('+201012345678');
        expect(repo.requestOtpCalls, 2);
        expect(
          (cubit.state as AuthOtpSent).verificationId,
          'second-verification-id',
        );
      },
    );
  });

  group('Weak password preserves the same phone-authenticated session', () {
    test('weak-password failure surfaces AuthError without touching the '
        'resume use cases (no deletion path is exercised from the Cubit '
        'for this error)', () async {
      repo.errorToThrow = Exception(
        'Please choose a stronger password (at least 6 characters).',
      );
      await cubit.registerWithOtp(
        verificationId: 'vid',
        smsCode: '123456',
        name: 'Ahmed',
        phone: '+201012345678',
        password: '123',
      );
      expect(cubit.state, isA<AuthError>());
      expect((cubit.state as AuthError).message, contains('stronger password'));
      expect(repo.linkPasswordToCurrentUserCalls, 0);
      expect(repo.completeProfileForCurrentUserCalls, 0);
    });
  });

  group('Duplicate synthetic email / collision handling', () {
    test('collision error surfaces a clear "already exists" AuthError, '
        'distinct from a generic failure', () async {
      repo.errorToThrow = Exception(
        'An account already exists for this phone. Please log in instead.',
      );
      await cubit.registerWithOtp(
        verificationId: 'vid',
        smsCode: '123456',
        name: 'Ahmed',
        phone: '+201012345678',
        password: 'strongpass1',
      );
      expect(cubit.state, isA<AuthError>());
      expect((cubit.state as AuthError).message, contains('already exists'));
    });
  });

  group('Network failures at each stage', () {
    test('network failure before phone auth (during requestOtp) surfaces '
        'AuthError and never reaches registerWithOtp', () async {
      repo.errorToThrow = Exception(
        'Network error. Please check your connection and try again.',
      );
      await cubit.requestOtp('+201012345678');
      expect(cubit.state, isA<AuthError>());
      expect(repo.registerWithOtpCalls, 0);
    });

    test('network failure after phone auth (during registerWithOtp) '
        'surfaces AuthError', () async {
      repo.errorToThrow = Exception(
        'Network error. Please check your connection and try again.',
      );
      await cubit.registerWithOtp(
        verificationId: 'vid',
        smsCode: '123456',
        name: 'Ahmed',
        phone: '+201012345678',
        password: 'strongpass1',
      );
      expect(cubit.state, isA<AuthError>());
    });

    test('ambiguous link failure recovery: reconcileSession is what '
        'resolves the ambiguity, not a blind retry of registration', () async {
      repo.sessionInspection = const AuthSessionInspection.recovery(
        RegistrationRecoveryStep.needsPassword,
        '+201012345678',
      );
      await cubit.reconcileSession();
      expect(cubit.state, isA<AuthPartialRegistration>());
      expect(
        (cubit.state as AuthPartialRegistration).step,
        RegistrationRecoveryStep.needsPassword,
      );
      expect(repo.registerWithOtpCalls, 0);
    });
  });

  group('App/restart recovery via reconcileSession — no second UID ever '
      'requested', () {
    test(
      'phone-only recovery emits AuthPartialRegistration(needsPassword)',
      () async {
        repo.sessionInspection = const AuthSessionInspection.recovery(
          RegistrationRecoveryStep.needsPassword,
          '+201012345678',
        );
        await cubit.reconcileSession();
        final state = cubit.state;
        expect(state, isA<AuthPartialRegistration>());
        expect(
          (state as AuthPartialRegistration).step,
          RegistrationRecoveryStep.needsPassword,
        );
        expect(state.phone, '+201012345678');
      },
    );

    test('phone+password/no-profile recovery emits '
        'AuthPartialRegistration(needsProfile)', () async {
      repo.sessionInspection = const AuthSessionInspection.recovery(
        RegistrationRecoveryStep.needsProfile,
        '+201012345678',
      );
      await cubit.reconcileSession();
      final state = cubit.state;
      expect(state, isA<AuthPartialRegistration>());
      expect(
        (state as AuthPartialRegistration).step,
        RegistrationRecoveryStep.needsProfile,
      );
    });

    test('completed profile recovery emits AuthSuccess (reconstructs the '
        'local session, does not re-register)', () async {
      repo.sessionInspection = AuthSessionInspection.complete(
        AuthUser(
          uid: 'existing-uid',
          name: 'Ahmed',
          phoneNumber: '+201012345678',
        ),
      );
      await cubit.reconcileSession();
      final state = cubit.state;
      expect(state, isA<AuthSuccess>());
      expect((state as AuthSuccess).user?.uid, 'existing-uid');
      expect(repo.registerWithOtpCalls, 0);
      expect(repo.registerWithPhonePasswordCalls, 0);
    });

    test('no session to reconcile emits AuthInitial (never fabricates a '
        'session or creates a user)', () async {
      repo.sessionInspection = const AuthSessionInspection.noSession();
      await cubit.reconcileSession();
      expect(cubit.state, isA<AuthInitial>());
    });

    test('retry never creates a second UID: linkPasswordToCurrentUser and '
        'completeProfileForCurrentUser never call registerWithOtp or '
        'registerWithPhonePassword', () async {
      await cubit.linkPasswordToCurrentUser(
        phone: '+201012345678',
        password: 'strongpass1',
      );
      await cubit.completeProfileForCurrentUser(
        name: 'Ahmed',
        phone: '+201012345678',
      );

      expect(repo.linkPasswordToCurrentUserCalls, 1);
      expect(repo.completeProfileForCurrentUserCalls, 1);
      expect(repo.registerWithOtpCalls, 0);
      expect(repo.registerWithPhonePasswordCalls, 0);
    });

    test('linkPasswordToCurrentUser success advances state to '
        'needsProfile in place (same screen, same session)', () async {
      await cubit.linkPasswordToCurrentUser(
        phone: '+201012345678',
        password: 'strongpass1',
      );
      final state = cubit.state;
      expect(state, isA<AuthPartialRegistration>());
      expect(
        (state as AuthPartialRegistration).step,
        RegistrationRecoveryStep.needsProfile,
      );
    });

    test('completeProfileForCurrentUser success emits AuthSuccess', () async {
      await cubit.completeProfileForCurrentUser(
        name: 'Ahmed',
        phone: '+201012345678',
      );
      expect(cubit.state, isA<AuthSuccess>());
    });
  });

  group('Existing legacy login remains unchanged', () {
    test('login emits AuthSuccess with the returned user, exactly as '
        'before Phase 3', () async {
      await cubit.login('+201012345678', 'correct-password');
      final state = cubit.state;
      expect(state, isA<AuthSuccess>());
      expect((state as AuthSuccess).user?.uid, 'login-uid');
      expect(repo.loginCalls, 1);
      // Login never touches any Phase 3 recovery/registration use case.
      expect(repo.registerWithOtpCalls, 0);
      expect(repo.inspectCurrentSessionCalls, 0);
    });

    test(
      'login failure surfaces AuthError exactly as before Phase 3',
      () async {
        repo.errorToThrow = Exception('Incorrect phone number or password.');
        await cubit.login('+201012345678', 'wrong-password');
        expect(cubit.state, isA<AuthError>());
      },
    );
  });

  group('Phase 4: legacy password-only login triggers migration '
      'requirement', () {
    test('login returning needsPhoneVerification: true carries that flag '
        'through to AuthSuccess.user (LoginView uses this to route to '
        'migration instead of Home)', () async {
      repo.userToReturn = AuthUser(
        uid: 'legacy-uid',
        name: 'Legacy User',
        phoneNumber: '+201012345678',
        needsPhoneVerification: true,
      );
      await cubit.login('+201012345678', 'correct-password');
      final state = cubit.state as AuthSuccess;
      expect(state.user?.needsPhoneVerification, isTrue);
    });

    test('already-migrated phone+password user: login returns '
        'needsPhoneVerification: false, routing straight Home', () async {
      repo.userToReturn = AuthUser(
        uid: 'migrated-uid',
        name: 'Migrated User',
        phoneNumber: '+201012345678',
        needsPhoneVerification: false,
      );
      await cubit.login('+201012345678', 'correct-password');
      final state = cubit.state as AuthSuccess;
      expect(state.user?.needsPhoneVerification, isFalse);
    });

    test('Phase 3 new-registration account never carries '
        'needsPhoneVerification: true (default is false, and '
        'registerWithOtp never sets it otherwise)', () async {
      await cubit.registerWithOtp(
        verificationId: 'vid',
        smsCode: '123456',
        name: 'New User',
        phone: '+201012345678',
        password: 'strongpass1',
      );
      final state = cubit.state as AuthSuccess;
      expect(state.user?.needsPhoneVerification, isFalse);
    });
  });

  group('Phase 4: migration OTP is sent to the account phone only', () {
    test('requestPhoneMigrationOtp sends the exact phone it is given, '
        'and never touches registerWithOtp/requestOtp', () async {
      await cubit.requestPhoneMigrationOtp('+201012345678');
      expect(repo.requestMigrationOtpCalls, 1);
      expect(repo.lastRequestMigrationOtpPhone, '+201012345678');
      expect(repo.requestOtpCalls, 0);
      expect(repo.registerWithOtpCalls, 0);
    });

    test('requestPhoneMigrationOtp emits AuthOtpSent carrying that same '
        'phone', () async {
      await cubit.requestPhoneMigrationOtp('+201012345678');
      final state = cubit.state as AuthOtpSent;
      expect(state.phone, '+201012345678');
    });

    test('a mismatched/different phone is rejected by the repository '
        'layer and surfaces as AuthError (the Cubit never guesses or '
        'substitutes a phone)', () async {
      repo.errorToThrow = Exception(
        'Your account phone number does not match your login details. '
        'Please contact support.',
      );
      await cubit.requestPhoneMigrationOtp('+201099999999');
      expect(cubit.state, isA<AuthError>());
      expect((cubit.state as AuthError).message, contains('does not match'));
    });
  });

  group('Phase 4: successful linking preserves the exact UID', () {
    test('linkPhoneMigration success emits AuthSuccess with the SAME uid '
        'it was given, and needsPhoneVerification: false', () async {
      await cubit.linkPhoneMigration(
        verificationId: 'vid',
        smsCode: '123456',
        uid: 'LEGACY_UID',
        name: 'Legacy User',
        phone: '+201012345678',
      );
      final state = cubit.state as AuthSuccess;
      expect(state.user?.uid, 'LEGACY_UID');
      expect(state.user?.needsPhoneVerification, isFalse);
      expect(repo.linkPhoneToCurrentUserCalls, 1);
    });

    test('linkPhoneMigration never touches registerWithOtp, '
        'registerWithPhonePassword, or login — it is a fully separate '
        'call path', () async {
      await cubit.linkPhoneMigration(
        verificationId: 'vid',
        smsCode: '123456',
        uid: 'LEGACY_UID',
        name: 'Legacy User',
        phone: '+201012345678',
      );
      expect(repo.registerWithOtpCalls, 0);
      expect(repo.registerWithPhonePasswordCalls, 0);
      expect(repo.loginCalls, 0);
    });
  });

  group('Phase 4: failures during linking preserve the legacy account', () {
    test('wrong OTP surfaces AuthError without emitting AuthSuccess', () async {
      repo.errorToThrow = Exception(
        'The code you entered is incorrect. Please try again.',
      );
      await cubit.linkPhoneMigration(
        verificationId: 'vid',
        smsCode: '000000',
        uid: 'LEGACY_UID',
        name: 'Legacy User',
        phone: '+201012345678',
      );
      expect(cubit.state, isA<AuthError>());
    });

    test(
      'expired OTP surfaces AuthError without emitting AuthSuccess',
      () async {
        repo.errorToThrow = Exception(
          'This code has expired. Please request a new one.',
        );
        await cubit.linkPhoneMigration(
          verificationId: 'vid',
          smsCode: '123456',
          uid: 'LEGACY_UID',
          name: 'Legacy User',
          phone: '+201012345678',
        );
        expect(cubit.state, isA<AuthError>());
      },
    );

    test(
      'network failure surfaces AuthError without emitting AuthSuccess',
      () async {
        repo.errorToThrow = Exception(
          'Network error. Please check your connection and try again.',
        );
        await cubit.linkPhoneMigration(
          verificationId: 'vid',
          smsCode: '123456',
          uid: 'LEGACY_UID',
          name: 'Legacy User',
          phone: '+201012345678',
        );
        expect(cubit.state, isA<AuthError>());
      },
    );

    test('credential-already-in-use surfaces a distinct, clear AuthError '
        '— never AuthSuccess, never a silent account switch', () async {
      repo.errorToThrow = Exception(
        'This phone number is already linked to a different account. '
        'Please contact support to resolve this.',
      );
      await cubit.linkPhoneMigration(
        verificationId: 'vid',
        smsCode: '123456',
        uid: 'LEGACY_UID',
        name: 'Legacy User',
        phone: '+201012345678',
      );
      expect(cubit.state, isA<AuthError>());
      expect((cubit.state as AuthError).message, contains('different account'));
    });
  });

  group('Phase 5B: Forgot Password OTP request', () {
    test(
      'requestPasswordResetOtp sends the exact phone it is given, and '
      'never touches requestOtp/requestMigrationOtp/registerWithOtp',
      () async {
        await cubit.requestPasswordResetOtp('+201012345678');
        expect(repo.requestPasswordResetOtpCalls, 1);
        expect(repo.lastRequestPasswordResetOtpPhone, '+201012345678');
        expect(repo.requestOtpCalls, 0);
        expect(repo.requestMigrationOtpCalls, 0);
        expect(repo.registerWithOtpCalls, 0);
      },
    );

    test('requestPasswordResetOtp emits AuthPasswordResetOtpSent (never '
        'AuthOtpSent) carrying that same phone and the backend-issued '
        'challengeId', () async {
      await cubit.requestPasswordResetOtp('+201012345678');
      final state = cubit.state;
      expect(state, isA<AuthPasswordResetOtpSent>());
      expect(state, isNot(isA<AuthOtpSent>()));
      expect((state as AuthPasswordResetOtpSent).phone, '+201012345678');
      expect(state.challengeId, repo.otpVerificationId);
    });

    test('resend calls requestPasswordResetOtp again and replaces the '
        'challengeId with a fresh one from the backend', () async {
      await cubit.requestPasswordResetOtp('+201012345678');
      expect(repo.requestPasswordResetOtpCalls, 1);
      repo.otpVerificationId = 'second-challenge-id';
      await cubit.requestPasswordResetOtp('+201012345678');
      expect(repo.requestPasswordResetOtpCalls, 2);
      expect(
        (cubit.state as AuthPasswordResetOtpSent).challengeId,
        'second-challenge-id',
      );
    });

    test('network failure requesting the OTP surfaces AuthError', () async {
      repo.errorToThrow = Exception(
        'Network error. Please check your connection and try again.',
      );
      await cubit.requestPasswordResetOtp('+201012345678');
      expect(cubit.state, isA<AuthError>());
    });
  });

  group('Phase 5B: resetPassword — success and UID-safety outcomes', () {
    test('successful reset emits AuthPasswordResetSuccess, never '
        'AuthSuccess — the backend always ends signed out and this must '
        'not be mistaken for an authenticated session', () async {
      await cubit.resetPassword(
        challengeId: 'challenge-id',
        smsCode: '123456',
        newPassword: 'newstrongpass1',
      );
      final state = cubit.state;
      expect(state, isA<AuthPasswordResetSuccess>());
      expect(state, isNot(isA<AuthSuccess>()));
      expect(repo.verifyPasswordResetOtpAndUpdatePasswordCalls, 1);
    });

    test('resetPassword never touches registerWithOtp, '
        'registerWithPhonePassword, login, or the Phase 4 migration use '
        'cases — it is a fully separate call path', () async {
      await cubit.resetPassword(
        challengeId: 'challenge-id',
        smsCode: '123456',
        newPassword: 'newstrongpass1',
      );
      expect(repo.registerWithOtpCalls, 0);
      expect(repo.registerWithPhonePasswordCalls, 0);
      expect(repo.loginCalls, 0);
      expect(repo.linkPhoneToCurrentUserCalls, 0);
      expect(repo.linkPasswordToCurrentUserCalls, 0);
    });

    test(
      'wrong OTP surfaces AuthError, not AuthPasswordResetSuccess',
      () async {
        repo.errorToThrow = Exception(
          'The code you entered is incorrect. Please try again.',
        );
        await cubit.resetPassword(
          challengeId: 'challenge-id',
          smsCode: '000000',
          newPassword: 'newstrongpass1',
        );
        expect(cubit.state, isA<AuthError>());
      },
    );

    test(
      'expired OTP surfaces AuthError, not AuthPasswordResetSuccess',
      () async {
        repo.errorToThrow = Exception(
          'This code has expired. Please request a new one.',
        );
        await cubit.resetPassword(
          challengeId: 'challenge-id',
          smsCode: '123456',
          newPassword: 'newstrongpass1',
        );
        expect(cubit.state, isA<AuthError>());
      },
    );

    test('network failure during update surfaces AuthError, not '
        'AuthPasswordResetSuccess', () async {
      repo.errorToThrow = Exception(
        'Network error. Please check your connection and try again.',
      );
      await cubit.resetPassword(
        challengeId: 'challenge-id',
        smsCode: '123456',
        newPassword: 'newstrongpass1',
      );
      expect(cubit.state, isA<AuthError>());
    });

    test('weak password surfaces a clear AuthError', () async {
      repo.errorToThrow = Exception(
        'Please choose a stronger password (at least 6 characters).',
      );
      await cubit.resetPassword(
        challengeId: 'challenge-id',
        smsCode: '123456',
        newPassword: '123',
      );
      expect(cubit.state, isA<AuthError>());
      expect((cubit.state as AuthError).message, contains('stronger password'));
    });

    test('a backend-surfaced "please try again" style error is a clear, '
        'recoverable AuthError (never silently treated as success)', () async {
      repo.errorToThrow = Exception('Something went wrong. Please try again.');
      await cubit.resetPassword(
        challengeId: 'challenge-id',
        smsCode: '123456',
        newPassword: 'newstrongpass1',
      );
      expect(cubit.state, isA<AuthError>());
    });

    test('an unrecognized phone (no pre-existing account — the '
        'unmigrated-legacy-account or truly-unknown-phone case) surfaces '
        'a safe "not found" AuthError rather than any success state — '
        'proving the Cubit layer treats this exactly like any other '
        'failure, never a partial success', () async {
      repo.errorToThrow = Exception(
        'We could not find an account for this phone number. If you '
        'already have an account, please log in with your password, or '
        'contact support.',
      );
      await cubit.resetPassword(
        challengeId: 'challenge-id',
        smsCode: '123456',
        newPassword: 'newstrongpass1',
      );
      expect(cubit.state, isA<AuthError>());
      expect(
        (cubit.state as AuthError).message,
        contains('could not find an account'),
      );
    });

    test('a fatal backend error surfaces as AuthError, never '
        'AuthPasswordResetSuccess', () async {
      repo.errorToThrow = Exception(
        'A critical account error occurred. Please contact support.',
      );
      await cubit.resetPassword(
        challengeId: 'challenge-id',
        smsCode: '123456',
        newPassword: 'newstrongpass1',
      );
      expect(cubit.state, isA<AuthError>());
    });
  });
}
