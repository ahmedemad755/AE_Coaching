abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String? message;
  AuthSuccess({this.message});
}

// تمت إضافة حالة الخطأ
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// تمت إضافة حالة نجاح إرسال كود الـ OTP مع الـ ID
class AuthOtpSent extends AuthState {
  final String verificationId;
  AuthOtpSent(this.verificationId);
}