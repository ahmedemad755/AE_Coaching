import 'package:ae_coaching/features/profile/presentation/profile_avatar.dart';
import 'package:ae_coaching/features/views/widgets/home_welcome_section.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const englishName = 'Ahmed Emad Abdelrahman Mohamed El Sayed';
  const arabicName = 'أحمد عماد عبد الرحمن محمد السيد الطويل';

  testWidgets('shows the full English name within two lines on a small phone', (
    tester,
  ) async {
    _setSmallPhoneViewport(tester);
    await tester.pumpWidget(_app(const Locale('en'), englishName));

    final nameFinder = find.byKey(const ValueKey('home-user-name'));
    expect(find.text(englishName), findsOneWidget);
    _expectNameFitsInTwoLines(tester, nameFinder);
    expect(find.text("Ready for today's workout?"), findsOneWidget);
  });

  testWidgets('renders the full Arabic name in RTL within two lines', (
    tester,
  ) async {
    _setSmallPhoneViewport(tester);
    await tester.pumpWidget(_app(const Locale('ar'), arabicName));

    final nameFinder = find.byKey(const ValueKey('home-user-name'));
    expect(find.text(arabicName), findsOneWidget);
    _expectNameFitsInTwoLines(tester, nameFinder);
    expect(find.text('مستعد لتمرين اليوم؟'), findsOneWidget);
    expect(Directionality.of(tester.element(nameFinder)), TextDirection.rtl);
  });

  testWidgets('shows the profile avatar beside the full name', (tester) async {
    await tester.pumpWidget(_app(const Locale('en'), englishName));

    final nameFinder = find.byKey(const ValueKey('home-user-name'));
    final nameRow = find
        .ancestor(of: nameFinder, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: nameRow, matching: find.byType(ProfileAvatar)),
      findsOneWidget,
    );
  });
}

void _expectNameFitsInTwoLines(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  expect(text.maxLines, 2);
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: text.style),
    textDirection: Directionality.of(element),
    locale: Localizations.maybeLocaleOf(element),
    textScaler: MediaQuery.textScalerOf(element),
    maxLines: 2,
  )..layout(maxWidth: 276);
  expect(painter.didExceedMaxLines, isFalse);
}

void _setSmallPhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Locale locale, String name) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: HomeWelcomeSection(name: name)),
);
