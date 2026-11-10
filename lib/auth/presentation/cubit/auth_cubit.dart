import 'dart:developer' as developer;

import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/domain/usecases/email_auth_usecases.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/errors/exception_message_mapper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Email-first authentication state (Stage 3C: the only supported flow).
/// One instance per auth screen (a DI factory). The authoritative state
/// lives in Firebase Auth and `users/{uid}`, never here.
class AuthCubit extends Cubit<AuthState> {
  final EmailAuthUseCases emailAuth;

  AuthCubit({required this.emailAuth}) : super(AuthInitial());

  /// A screen can be popped while a Firebase call is still in flight
  /// (its BlocProvider then closes this cubit). The late result is
  /// dropped instead of throwing "emit after close".
  @override
  void emit(AuthState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Duplicate-submission guard. Every action emits [AuthLoading]
  /// synchronously before its first await, so a second tap in the same
  /// frame (before the disabled button rebuilds) is ignored here: no
  /// second account, email or sign-in request.
  bool get _isBusy => state is AuthLoading;

  /// Leaves Verify Email / Complete Profile / a failed account check and
  /// returns the app to [AuthStatus.unauthenticated]. Ends the Firebase
  /// session only. The account, its uid and its data are never deleted,
  /// so signing in again resumes exactly where the user left off.
  Future<void> signOut() async {
    if (_isBusy) return;
    developer.log('=== [Sign Out Attempt] ===', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      await emailAuth.signOut();
      emit(AuthSignedOut());
    } catch (e, stackTrace) {
      _logError('Sign Out Failed', e, stackTrace);
      emit(AuthError(mapGenericExceptionToMessage(e)));
    }
  }

  /// Maps a resolved session to exactly one state. Login, registration,
  /// startup and refresh all route through here, so none of them can
  /// diverge on what counts as "authenticated".
  Future<void> _emitResolution(
    EmailSessionResolution resolution, {
    String? successMessage,
  }) async {
    switch (resolution.status) {
      case AuthStatus.authenticated:
        emit(AuthSuccess(message: successMessage, user: resolution.user));
      case AuthStatus.pendingEmailVerification:
        emit(
          AuthEmailVerificationRequired(
            email: resolution.email,
            verificationEmailSent: resolution.verificationEmailSent,
          ),
        );
      case AuthStatus.incompleteProfile:
        emit(AuthProfileIncomplete(resolution.email));
      case AuthStatus.profileUnavailable:
        emit(
          AuthProfileUnavailable(
            email: resolution.email,
            failure: resolution.profileFailure ?? ProfileFailure.unknown,
          ),
        );
      case AuthStatus.unsupportedLegacyAccount:
        // Decision A: never modified or deleted, only signed out.
        await emailAuth.signOut();
        emit(AuthLegacyAccountSignedOut());
      case AuthStatus.unauthenticated:
        emit(AuthSignedOut());
    }
  }

  Future<void> _runEmail(String action, Future<void> Function() body) async {
    if (_isBusy) return;
    developer.log('=== [$action] ===', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      await body();
    } catch (e, stackTrace) {
      _logError(action, e, stackTrace);
      emit(AuthError(mapGenericExceptionToMessage(e)));
    }
  }

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
    String? languageCode,
  }) => _runEmail('Register With Email', () async {
    final resolution = await emailAuth.register(
      name: name,
      email: email,
      password: password,
      languageCode: languageCode,
    );
    await _emitResolution(resolution);
  });

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) => _runEmail('Login With Email', () async {
    final resolution = await emailAuth.login(email: email, password: password);
    await _emitResolution(resolution, successMessage: 'Logged in successfully');
  });

  /// Startup / resume: authoritative check of the persisted session.
  Future<void> resolveEmailSession() => _runEmail('Resolve Session', () async {
    await _emitResolution(await emailAuth.resolveSession());
  });

  Future<void> resendVerificationEmail({String? languageCode}) =>
      _runEmail('Resend Verification Email', () async {
        await emailAuth.resendVerification(languageCode: languageCode);
        emit(AuthVerificationEmailSent());
      });

  /// "I've verified my email". With [silent] (automatic check when the
  /// app returns to the foreground) there's no spinner and no error. A
  /// state is emitted only when something actually changed.
  Future<void> refreshEmailVerification({bool silent = false}) async {
    if (!silent) {
      return _runEmail('Refresh Email Verification', () async {
        await _emitResolution(
          await emailAuth.refreshVerification(),
          successMessage: 'Email verified successfully',
        );
      });
    }
    if (_isBusy) return;
    try {
      final resolution = await emailAuth.refreshVerification();
      if (resolution.status != AuthStatus.pendingEmailVerification) {
        await _emitResolution(
          resolution,
          successMessage: 'Email verified successfully',
        );
      }
    } catch (e, stackTrace) {
      _logError('Silent Verification Check', e, stackTrace);
    }
  }

  Future<void> requestEmailChange({
    required String newEmail,
    String? languageCode,
  }) => _runEmail('Request Email Change', () async {
    final sentTo = await emailAuth.requestEmailChange(
      newEmail: newEmail,
      languageCode: languageCode,
    );
    emit(AuthEmailChangeRequested(sentTo));
  });

  Future<void> sendPasswordResetEmail({
    required String email,
    String? languageCode,
  }) => _runEmail('Send Password Reset Email', () async {
    final sentTo = await emailAuth.sendPasswordReset(
      email: email,
      languageCode: languageCode,
    );
    emit(AuthPasswordResetEmailSent(sentTo));
  });

  Future<void> completeEmailProfile({required String name}) =>
      _runEmail('Complete Profile', () async {
        await _emitResolution(
          await emailAuth.completeProfile(name: name),
          successMessage: 'Account setup complete',
        );
      });

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
}
