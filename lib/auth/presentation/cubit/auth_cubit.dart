import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// الكود الخاص بمعرف التحقق في حالة الـ OTP
class AuthOtpSent extends AuthState {
  final String verificationId;
  AuthOtpSent(this.verificationId);
}

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  final RequestOtpUseCase requestOtpUseCase;
  final RegisterWithOtpUseCase registerWithOtpUseCase;

  AuthCubit({
    required this.loginUseCase,
    required this.requestOtpUseCase,
    required this.registerWithOtpUseCase,
  }) : super(AuthInitial());

  // 1. تسجيل الدخول التقليدي
  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      await loginUseCase(email, password);
      emit(AuthSuccess(message: "Logged in successfully"));
    } catch (e) {
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  // 2. طلب كود OTP
  Future<void> requestOtp(String phoneNumber) async {
    emit(AuthLoading());
    try {
      await requestOtpUseCase(phoneNumber);
      // ملاحظة: الـ verificationId عادة بيتم التعامل معاه في الـ Data Source 
      // عبر callback، اتأكد من تمريره إذا كنت بتخزنه هناك.
      emit(AuthSuccess(message: "OTP Sent successfully"));
    } catch (e) {
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  // 3. إتمام التسجيل بكود الـ OTP
  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    emit(AuthLoading());
    try {
      await registerWithOtpUseCase(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      emit(AuthSuccess(message: "Registered successfully"));
    } catch (e) {
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  // دالة مساعدة لتحويل الـ Exceptions لرسائل مفهومة
  String _mapExceptionToMessage(Object e) {
    // يمكنك تخصيص الرسائل بناءً على نوع الـ Exception (FirebaseException مثلاً)
    return e.toString().replaceAll('Exception: ', '');
  }
}