import 'package:ae_coaching/auth/data/datasources/email_auth_remote_data_source.dart';
import 'package:ae_coaching/auth/data/repositories/email_auth_repository_impl.dart';
import 'package:ae_coaching/auth/domain/repositories/email_auth_repository.dart';
import 'package:ae_coaching/auth/domain/usecases/email_auth_usecases.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/core/di/sl_instance.dart';

/// Email-first authentication (the only supported flow since Stage 3C).
void initAuth() {
  // Data source → repository → use cases (lazy: nothing touches Firebase
  // until a screen resolves AuthCubit).
  sl.registerLazySingleton<EmailAuthRemoteDataSource>(
    () => EmailAuthRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<EmailAuthRepository>(
    () => EmailAuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => EmailAuthUseCases(sl<EmailAuthRepository>()));

  // One AuthCubit per auth screen.
  sl.registerFactory(() => AuthCubit(emailAuth: sl()));
}
