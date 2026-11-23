import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small Android phone (360×640 dp, 3-button navigation bar). With
/// [keyboard] the soft keyboard is open: it covers the navigation bar, so
/// the bottom padding becomes 0 and the keyboard height is a view inset,
/// exactly as Android reports it.
const smallPhone = Size(360, 640);
const statusBar = 24.0;
const navigationBar = 48.0;
const keyboardHeight = 280.0;

void useSmallPhone(
  WidgetTester tester, {
  bool keyboard = false,
  double textScale = 1,
}) {
  tester.view
    ..physicalSize = smallPhone
    ..devicePixelRatio = 1
    ..viewPadding = const FakeViewPadding(top: statusBar, bottom: navigationBar)
    ..padding = FakeViewPadding(
      top: statusBar,
      bottom: keyboard ? 0 : navigationBar,
    )
    ..viewInsets = FakeViewPadding(bottom: keyboard ? keyboardHeight : 0);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Opens or closes the keyboard on the current screen.
Future<void> setKeyboard(WidgetTester tester, {required bool open}) async {
  tester.view
    ..padding = FakeViewPadding(
      top: statusBar,
      bottom: open ? 0 : navigationBar,
    )
    ..viewInsets = FakeViewPadding(bottom: open ? keyboardHeight : 0);
  await tester.pumpAndSettle();
}

/// Fails with Flutter's own overflow report ("A RenderFlex overflowed by…").
void expectNoOverflow(WidgetTester tester) {
  final error = tester.takeException();
  expect(error, isNull, reason: 'layout error: $error');
}

/// Every dialog button is fully visible above the keyboard (after scrolling
/// the dialog, if it scrolls).
void expectActionsAboveKeyboard(WidgetTester tester) {
  final top = smallPhone.height - keyboardHeight;
  final buttons = find.descendant(
    of: find.byType(Dialog),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(buttons, findsWidgets);
  for (final element in buttons.evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    expect(
      rect.bottom,
      lessThanOrEqualTo(top + 0.5),
      reason: '${element.widget} hidden by the keyboard',
    );
    expect(
      rect.top,
      greaterThanOrEqualTo(statusBar - 0.5),
      reason: '${element.widget} under the status bar',
    );
  }
}
