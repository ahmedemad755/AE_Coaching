import 'package:ae_coaching/features/profile/presentation/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the saved name initials and handles RTL taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ProfileAvatar(
              name: 'أحمد عماد',
              semanticLabel: 'إضافة صورة',
              onTap: () => tapped = true,
              onImageError: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('أع'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('إضافة صورة')));
    expect(tapped, isTrue);
    semantics.dispose();
  });

  testWidgets('shows a stable branded fallback when no name or photo exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: ProfileAvatar(name: '', semanticLabel: 'Profile photo'),
        ),
      ),
    );

    expect(find.text('AE'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ProfileAvatar))).brightness,
      Brightness.dark,
    );
  });
}
