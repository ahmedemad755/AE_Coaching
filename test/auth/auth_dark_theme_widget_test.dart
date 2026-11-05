import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
import 'package:ae_coaching/auth/domain/usecases/complete_profile_for_current_user_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/inspect_session_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/link_password_to_current_user_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/link_phone_migration_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_phone_password_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_password_reset_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_phone_migration_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/reset_password_with_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/view/loginview.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthCubit _authCubit() {
  final repository = _UnusedAuthRepository();
  return AuthCubit(
    loginUseCase: LoginUseCase(repository),
    requestOtpUseCase: RequestOtpUseCase(repository),
    registerWithOtpUseCase: RegisterWithOtpUseCase(repository),
    registerWithPhonePasswordUseCase: RegisterWithPhonePasswordUseCase(
      repository,
    ),
    inspectSessionUseCase: InspectSessionUseCase(repository),
    linkPasswordToCurrentUserUseCase: LinkPasswordToCurrentUserUseCase(
      repository,
    ),
    completeProfileForCurrentUserUseCase: CompleteProfileForCurrentUserUseCase(
      repository,
    ),
    requestPhoneMigrationOtpUseCase: RequestPhoneMigrationOtpUseCase(
      repository,
    ),
    linkPhoneMigrationUseCase: LinkPhoneMigrationUseCase(repository),
    requestPasswordResetOtpUseCase: RequestPasswordResetOtpUseCase(repository),
    resetPasswordWithOtpUseCase: ResetPasswordWithOtpUseCase(repository),
  );
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Login form follows $mode theme and supports Arabic errors', (
      tester,
    ) async {
      final cubit = _authCubit();
      addTearDown(cubit.close);
      const locale = Locale('ar');

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: const LoginView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(LoginView));
      final l10n = AppLocalizations.of(context)!;
      final scheme = Theme.of(context).colorScheme;
      expect(Directionality.of(context), TextDirection.rtl);
      expect(
        Theme.of(context).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(
        tester.widget<Text>(find.text(l10n.appBrandFull)).style?.color,
        scheme.onSurface,
      );

      final phoneField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(TextField),
        ),
      );
      expect(
        phoneField.decoration!.fillColor,
        Theme.of(context).inputDecorationTheme.fillColor,
      );
      expect(
        (phoneField.decoration!.errorBorder! as OutlineInputBorder)
            .borderSide
            .color,
        scheme.error,
      );

      await tester.tap(find.text(l10n.loginButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.phoneNumberRequired), findsOneWidget);
      expect(find.text(l10n.passwordRequired), findsOneWidget);
    });
  }
}
