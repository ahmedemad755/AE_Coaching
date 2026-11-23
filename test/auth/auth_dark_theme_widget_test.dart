import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/view/loginview.dart';
import 'package:ae_coaching/auth/presentation/view/register_view.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/auth_screen_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_cubit_builder.dart';

/// The email auth screens must follow the app's Light/Dark theme (the
/// AuthScreenTheme + app color scheme), in Arabic (RTL) as well.
Future<BuildContext> _pump(
  WidgetTester tester, {
  required Widget screen,
  required ThemeMode mode,
}) async {
  final AuthCubit cubit = buildAuthCubit();
  addTearDown(cubit.close);
  await tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.element(find.byWidget(screen));
}

void _expectThemedField(WidgetTester tester, Finder field, BuildContext ctx) {
  final scheme = Theme.of(ctx).colorScheme;
  final textField = tester.widget<TextField>(
    find.descendant(of: field, matching: find.byType(TextField)),
  );
  final decoration = textField.decoration!;
  expect(
    (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
    scheme.primary,
  );
  expect(
    (decoration.errorBorder! as OutlineInputBorder).borderSide.color,
    scheme.error,
  );
  if (Theme.of(ctx).brightness == Brightness.dark) {
    expect(decoration.fillColor, isNot(Colors.white));
  }
}

void _expectThemedPanel(WidgetTester tester, BuildContext ctx) {
  final panelColor = AuthScreenTheme.panelColor(ctx);
  final panels = tester
      .widgetList<Container>(find.byType(Container))
      .where(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).color == panelColor,
      );
  expect(panels, isNotEmpty, reason: 'auth card uses AuthScreenTheme panel');
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final brightness = mode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;

    testWidgets('Login follows $mode theme, RTL and Arabic errors', (
      tester,
    ) async {
      const screen = LoginView();
      final ctx = await _pump(tester, screen: screen, mode: mode);
      final l10n = AppLocalizations.of(ctx)!;

      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(Theme.of(ctx).brightness, brightness);
      _expectThemedPanel(tester, ctx);
      _expectThemedField(
        tester,
        find.byKey(const Key('login_email_field')),
        ctx,
      );

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.emailRequired), findsOneWidget);
      expect(find.text(l10n.passwordRequired), findsOneWidget);
    });

    testWidgets('Register follows $mode theme, RTL and Arabic errors', (
      tester,
    ) async {
      const screen = RegisterView();
      final ctx = await _pump(tester, screen: screen, mode: mode);
      final l10n = AppLocalizations.of(ctx)!;

      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(Theme.of(ctx).brightness, brightness);
      _expectThemedPanel(tester, ctx);
      for (final key in [
        'register_name_field',
        'register_email_field',
        'register_password_field',
        'register_confirm_field',
      ]) {
        _expectThemedField(tester, find.byKey(Key(key)), ctx);
      }
      expect(
        tester.widget<Text>(find.text(l10n.createAccountTitle)).style?.color,
        Theme.of(ctx).extension<AppSemanticColors>()?.textPrimary ??
            Theme.of(ctx).colorScheme.onSurface,
      );

      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.fullNameRequired), findsOneWidget);
      expect(find.text(l10n.emailRequired), findsOneWidget);
    });
  }
}
