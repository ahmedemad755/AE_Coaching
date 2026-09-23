import 'package:ae_coaching/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ae_coaching/auth/data/repositories/auth_repository_impl.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
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
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/core/di/sl_instance.dart';

void initAuth() {
  // 1. UseCases
  sl.registerLazySingleton(() => RequestOtpUseCase(sl()));
  sl.registerLazySingleton(() => RegisterWithOtpUseCase(sl()));
  sl.registerLazySingleton(() => RegisterWithPhonePasswordUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => InspectSessionUseCase(sl()));
  sl.registerLazySingleton(() => LinkPasswordToCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => CompleteProfileForCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => RequestPhoneMigrationOtpUseCase(sl()));
  sl.registerLazySingleton(() => LinkPhoneMigrationUseCase(sl()));
  sl.registerLazySingleton(() => RequestPasswordResetOtpUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordWithOtpUseCase(sl()));

  // 2. Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // 3. Data Source
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );

  // الـ AuthCubit Factory
  sl.registerFactory(
    () => AuthCubit(
      requestOtpUseCase: sl(),
      registerWithOtpUseCase: sl(),
      registerWithPhonePasswordUseCase: sl(),
      loginUseCase: sl(),
      inspectSessionUseCase: sl(),
      linkPasswordToCurrentUserUseCase: sl(),
      completeProfileForCurrentUserUseCase: sl(),
      requestPhoneMigrationOtpUseCase: sl(),
      linkPhoneMigrationUseCase: sl(),
      requestPasswordResetOtpUseCase: sl(),
      resetPasswordWithOtpUseCase: sl(),
    ),
  );
}
