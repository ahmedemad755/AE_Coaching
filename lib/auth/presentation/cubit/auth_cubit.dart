import 'dart:developer'
    as developer; // استيراد الـ developer log لطباعة احترافية
import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/usecases/complete_profile_for_current_user_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/inspect_session_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/link_password_to_current_user_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/link_phone_migration_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_phone_password_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_phone_migration_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_password_reset_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/reset_password_with_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  final RequestOtpUseCase requestOtpUseCase;
  final RegisterWithOtpUseCase registerWithOtpUseCase;
  final RegisterWithPhonePasswordUseCase registerWithPhonePasswordUseCase;
  final InspectSessionUseCase inspectSessionUseCase;
  final LinkPasswordToCurrentUserUseCase linkPasswordToCurrentUserUseCase;
  final CompleteProfileForCurrentUserUseCase
  completeProfileForCurrentUserUseCase;
  final RequestPhoneMigrationOtpUseCase requestPhoneMigrationOtpUseCase;
  final LinkPhoneMigrationUseCase linkPhoneMigrationUseCase;
  final RequestPasswordResetOtpUseCase requestPasswordResetOtpUseCase;
  final ResetPasswordWithOtpUseCase resetPasswordWithOtpUseCase;

  AuthCubit({
    required this.loginUseCase,
    required this.requestOtpUseCase,
    required this.registerWithOtpUseCase,
    required this.registerWithPhonePasswordUseCase,
    required this.inspectSessionUseCase,
    required this.linkPasswordToCurrentUserUseCase,
    required this.completeProfileForCurrentUserUseCase,
    required this.requestPhoneMigrationOtpUseCase,
    required this.linkPhoneMigrationUseCase,
    required this.requestPasswordResetOtpUseCase,
    required this.resetPasswordWithOtpUseCase,
  }) : super(AuthInitial());

  Future<void> login(String phoneOrEmail, String password) async {
    developer.log(
      '=== [Login Attempt] === Started for: $phoneOrEmail',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      final user = await loginUseCase(phoneOrEmail, password);

      developer.log(
        '=== [Login Success] === User UID: ${user.uid}',
        name: 'AuthCubit',
      );
      emit(AuthSuccess(message: "Logged in successfully", user: user));
    } catch (e, stackTrace) {
      _logError('Login Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    developer.log(
      '=== [OTP Request Attempt] === Phone: $phoneNumber',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      final String verificationId = await requestOtpUseCase(phoneNumber);

      developer.log(
        '=== [OTP Sent Success] === VerificationID: $verificationId',
        name: 'AuthCubit',
      );
      emit(AuthOtpSent(verificationId, phoneNumber));
    } catch (e, stackTrace) {
      _logError('Request OTP Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  }) async {
    developer.log(
      '=== [Register With OTP Attempt] === Phone: $phone, Name: $name',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      final user = await registerWithOtpUseCase(
        verificationId: verificationId,
        smsCode: smsCode,
        name: name,
        phone: phone,
        password: password,
      );

      developer.log(
        '=== [Register With OTP Success] === User UID: ${user.uid}',
        name: 'AuthCubit',
      );
      emit(AuthSuccess(message: "Account created successfully", user: user));
    } catch (e, stackTrace) {
      _logError('Register With OTP Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> registerWithPhonePassword({
    required String name,
    required String phone,
    required String password,
  }) async {
    developer.log(
      '=== [Register Phone/Password Attempt] === Phone: $phone, Name: $name',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      final user = await registerWithPhonePasswordUseCase(
        name: name,
        phone: phone,
        password: password,
      );

      developer.log(
        '=== [Register Phone/Password Success] === User UID: ${user.uid}',
        name: 'AuthCubit',
      );
      emit(AuthSuccess(message: "Account created successfully", user: user));
    } catch (e, stackTrace) {
      _logError('Register Phone/Password Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  /// Startup/reconciliation: is there a real Firebase session
  /// underneath a Hive-logged-out UI, and if so is it complete or a
  /// resumable partial registration? Never creates a new UID.
  Future<void> reconcileSession() async {
    developer.log('=== [Reconcile Session Attempt] ===', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      final inspection = await inspectSessionUseCase();

      if (inspection.completedUser != null) {
        developer.log(
          '=== [Reconcile Session] === Complete profile found, UID: ${inspection.completedUser!.uid}',
          name: 'AuthCubit',
        );
        emit(AuthSuccess(user: inspection.completedUser));
        return;
      }

      if (inspection.recoveryStep != null) {
        developer.log(
          '=== [Reconcile Session] === Resumable registration, step: ${inspection.recoveryStep}',
          name: 'AuthCubit',
        );
        emit(
          AuthPartialRegistration(
            step: inspection.recoveryStep!,
            phone: inspection.phone!,
          ),
        );
        return;
      }

      developer.log(
        '=== [Reconcile Session] === Nothing to reconcile',
        name: 'AuthCubit',
      );
      emit(AuthInitial());
    } catch (e, stackTrace) {
      _logError('Reconcile Session Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  /// Resume path: link a (possibly new/stronger) password onto the
  /// SAME already phone-authenticated session. Never re-verifies phone.
  Future<void> linkPasswordToCurrentUser({
    required String phone,
    required String password,
  }) async {
    developer.log(
      '=== [Link Password Resume Attempt] === Phone: $phone',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      await linkPasswordToCurrentUserUseCase(phone: phone, password: password);
      developer.log(
        '=== [Link Password Resume Success] ===',
        name: 'AuthCubit',
      );
      emit(
        AuthPartialRegistration(
          step: RegistrationRecoveryStep.needsProfile,
          phone: phone,
        ),
      );
    } catch (e, stackTrace) {
      _logError('Link Password Resume Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  /// Resume path: write `users/{uid}` for the SAME already-linked
  /// session. Never repeats authentication.
  Future<void> completeProfileForCurrentUser({
    required String name,
    required String phone,
  }) async {
    developer.log(
      '=== [Complete Profile Resume Attempt] === Phone: $phone, Name: $name',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      final user = await completeProfileForCurrentUserUseCase(
        name: name,
        phone: phone,
      );
      developer.log(
        '=== [Complete Profile Resume Success] === User UID: ${user.uid}',
        name: 'AuthCubit',
      );
      emit(AuthSuccess(message: "Account setup complete", user: user));
    } catch (e, stackTrace) {
      _logError('Complete Profile Resume Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  /// Phase 4 — legacy migration. Sends an OTP to the account's own
  /// canonical [phone] (never user-typed). Semantically distinct from
  /// [requestOtp]: this can only ever be called for an already
  /// authenticated legacy user, and never routes through
  /// [registerWithOtpUseCase].
  Future<void> requestPhoneMigrationOtp(String phone) async {
    developer.log(
      '=== [Migration OTP Request Attempt] === Phone: $phone',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      final String verificationId = await requestPhoneMigrationOtpUseCase(
        phone,
      );
      developer.log('=== [Migration OTP Sent Success] ===', name: 'AuthCubit');
      emit(AuthOtpSent(verificationId, phone));
    } catch (e, stackTrace) {
      _logError('Request Migration OTP Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  /// Phase 4 — legacy migration. Links the phone credential onto the
  /// SAME already-authenticated user (never signInWithCredential, never
  /// a new UID). [uid]/[name]/[phone] are the values already known from
  /// the login that started this flow — used only to report the
  /// now-fully-migrated user back to the UI, not re-fetched.
  Future<void> linkPhoneMigration({
    required String verificationId,
    required String smsCode,
    required String uid,
    required String name,
    required String phone,
  }) async {
    developer.log(
      '=== [Link Phone Migration Attempt] === UID: $uid',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      await linkPhoneMigrationUseCase(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      developer.log(
        '=== [Link Phone Migration Success] === UID unchanged: $uid',
        name: 'AuthCubit',
      );
      emit(
        AuthSuccess(
          message: "Phone verified successfully",
          user: AuthUser(
            uid: uid,
            name: name,
            phoneNumber: phone,
            needsPhoneVerification: false,
          ),
        ),
      );
    } catch (e, stackTrace) {
      _logError('Link Phone Migration Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  /// Phase 5B — signed-out Forgot Password. Sends an OTP request to the
  /// TRUSTED BACKEND (Cloud Function `requestPasswordReset`) for the
  /// phone the user typed. Never assumes an account exists — that is
  /// only ever determined server-side, never here. Emits
  /// [AuthPasswordResetOtpSent], never [AuthOtpSent] — see that state's
  /// doc comment for why they must not be conflated.
  Future<void> requestPasswordResetOtp(String phone) async {
    developer.log(
      '=== [Password Reset OTP Request Attempt] === Phone: $phone',
      name: 'AuthCubit',
    );
    emit(AuthLoading());
    try {
      final String challengeId = await requestPasswordResetOtpUseCase(phone);
      developer.log(
        '=== [Password Reset OTP Sent Success] ===',
        name: 'AuthCubit',
      );
      emit(AuthPasswordResetOtpSent(challengeId: challengeId, phone: phone));
    } catch (e, stackTrace) {
      _logError('Request Password Reset OTP Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  /// Phase 5B — signed-out Forgot Password. Submits the OTP + new
  /// password to the TRUSTED BACKEND (Cloud Function
  /// `completePasswordReset`), which alone decides whether an eligible
  /// account exists and performs the password update — this Cubit (and
  /// the client entirely) never signs in, never resolves identity, and
  /// never calls Firebase Auth's updatePassword directly. Emits
  /// [AuthPasswordResetSuccess], never [AuthSuccess]: the backend
  /// always ends signed out, so this must never be mistaken for an
  /// authenticated session.
  Future<void> resetPassword({
    required String challengeId,
    required String smsCode,
    required String newPassword,
  }) async {
    developer.log('=== [Reset Password Attempt] ===', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      await resetPasswordWithOtpUseCase(
        challengeId: challengeId,
        smsCode: smsCode,
        newPassword: newPassword,
      );
      developer.log('=== [Reset Password Success] ===', name: 'AuthCubit');
      emit(AuthPasswordResetSuccess("Password changed successfully"));
    } catch (e, stackTrace) {
      _logError('Reset Password Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  // دالة مساعدة موحدة لطباعة الأخطاء بشكل منظم ومفصل جداً في الـ Console
  void _logError(String action, Object error, StackTrace stackTrace) {
    developer.log(
      '❌❌❌ [$action] ERROR ❌❌❌\n'
      'Message: $error\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
      'STACK TRACE:\n$stackTrace'
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      name: 'AuthCubit',
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _mapExceptionToMessage(Object e) {
    return e.toString().replaceAll('Exception: ', '');
  }
}
