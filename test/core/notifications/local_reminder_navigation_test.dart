import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('local inactivity reminder tap opens Home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        home: const Scaffold(body: Text('Signed in screen')),
        routes: {
          AppNavigator.home: (_) =>
              const Scaffold(body: Text('Home destination')),
        },
      ),
    );

    AppRouter.openHomeFromNotification();
    await tester.pumpAndSettle();

    expect(find.text('Home destination'), findsOneWidget);
    expect(find.text('Signed in screen'), findsNothing);
  });
}
