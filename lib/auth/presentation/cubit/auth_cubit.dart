import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  final RequestOtpUseCase requestOtpUseCase;
  final RegisterWithOtpUseCase registerWithOtpUseCase;

  AuthCubit({
    required this.loginUseCase,
    required this.requestOtpUseCase,
    required this.registerWithOtpUseCase,
  }) : super(AuthInitial());

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      await loginUseCase(email, password);
      emit(AuthSuccess(message: "Logged in successfully"));
    } catch (e) {
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    emit(AuthLoading());
    try {
      // 🔥 دلوقتي إحنا بننتظر الـ ID الحقيقي من فايربيز
      final String verificationId = await requestOtpUseCase(phoneNumber);
      
      // بنبعته للـ RegisterView عن طريق State الـ AuthOtpSent
      emit(AuthOtpSent(verificationId)); 
    } catch (e) {
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

// في دالة registerWithOtp ضيف المعطيات الجديدة:
  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      await registerWithOtpUseCase(
        verificationId: verificationId,
        smsCode: smsCode,
        name: name,
        phone: phone,
        password: password,
      );
      emit(AuthSuccess(message: "Account created successfully. Please login."));
    } catch (e) {
      emit(AuthError(_mapExceptionToMessage(e)));
    }
  }

  String _mapExceptionToMessage(Object e) {
    return e.toString().replaceAll('Exception: ', '');
  }
}