import 'package:ae_coaching/auth/domain/usecases/email_auth_usecases.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';

import 'fake_email_auth_repository.dart';

export 'fake_email_auth_repository.dart';

/// AuthCubit wired to a [FakeEmailAuthRepository] (a fresh one if none is
/// given). Pass your own to drive and observe the flow.
AuthCubit buildAuthCubit([FakeEmailAuthRepository? emailRepo]) => AuthCubit(
  emailAuth: EmailAuthUseCases(emailRepo ?? FakeEmailAuthRepository()),
);
