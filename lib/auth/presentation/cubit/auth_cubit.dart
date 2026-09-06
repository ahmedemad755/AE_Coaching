import 'dart:developer' as developer; // استيراد الـ developer log لطباعة احترافية
import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_phone_password_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  final RequestOtpUseCase requestOtpUseCase;
  final RegisterWithOtpUseCase registerWithOtpUseCase;
  final RegisterWithPhonePasswordUseCase registerWithPhonePasswordUseCase;

  AuthCubit({
    required this.loginUseCase,
    required this.requestOtpUseCase,
    required this.registerWithOtpUseCase,
    required this.registerWithPhonePasswordUseCase,
  }) : super(AuthInitial());

  Future<void> login(String phoneOrEmail, String password) async {
    developer.log('=== [Login Attempt] === Started for: $phoneOrEmail', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      final user = await loginUseCase(phoneOrEmail, password);
      
      developer.log('=== [Login Success] === User UID: ${user.uid}', name: 'AuthCubit');
      emit(AuthSuccess(message: "Logged in successfully", user: user));
    } catch (e, stackTrace) {
      _logError('Login Failed', e, stackTrace);
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    developer.log('=== [OTP Request Attempt] === Phone: $phoneNumber', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      final String verificationId = await requestOtpUseCase(phoneNumber);
      
      developer.log('=== [OTP Sent Success] === VerificationID: $verificationId', name: 'AuthCubit');
      emit(AuthOtpSent(verificationId)); 
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
    developer.log('=== [Register With OTP Attempt] === Phone: $phone, Name: $name', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      await registerWithOtpUseCase(
        verificationId: verificationId,
        smsCode: smsCode,
        name: name,
        phone: phone,
        password: password,
      );
      
      developer.log('=== [Register With OTP Success] === Account Created.', name: 'AuthCubit');
      emit(AuthSuccess(message: "Account created successfully. Please login."));
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
    developer.log('=== [Register Phone/Password Attempt] === Phone: $phone, Name: $name', name: 'AuthCubit');
    emit(AuthLoading());
    try {
      final user = await registerWithPhonePasswordUseCase(
        name: name,
        phone: phone,
        password: password,
      );
      
      developer.log('=== [Register Phone/Password Success] === User UID: ${user.uid}', name: 'AuthCubit');
      emit(AuthSuccess(message: "Account created successfully", user: user));
    } catch (e, stackTrace) {
      _logError('Register Phone/Password Failed', e, stackTrace);
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