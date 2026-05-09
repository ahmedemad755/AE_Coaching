import 'package:ae_coaching/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ae_coaching/auth/data/repositories/auth_repository_impl.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

void initAuth() {
  // 1. UseCases
  sl.registerLazySingleton(() => RequestOtpUseCase(sl()));
  sl.registerLazySingleton(() => RegisterWithOtpUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));

  // 2. Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // 3. Data Source
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );

  // أضف هذا السطر في دالة initAuth
sl.registerFactory(() => AuthCubit(
      requestOtpUseCase: sl(),
      registerWithOtpUseCase: sl(),
      loginUseCase: sl(),
    ));

    
}