import 'package:ae_coaching/core/widgets/entrance_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget list({bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: ListView(
        children: [for (var i = 0; i < 12; i++) Text('item $i')].staggered(),
      ),
    ),
  );

  double opacityOf(WidgetTester tester, String text) {
    final opacity = find.ancestor(
      of: find.text(text),
      matching: find.byType(Opacity),
    );
    if (opacity.evaluate().isEmpty) return 1;
    return tester.widget<Opacity>(opacity.first).opacity;
  }

  testWidgets(
    'first 8 items wait their stagger slot, later items show at once',
    (tester) async {
      expect(EntranceMotion.stagger.inMilliseconds, inInclusiveRange(50, 80));
      await tester.pumpWidget(list());
      await tester.pump();

      expect(find.byType(EntranceAnimation), findsNWidgets(8));
      // Item 7's delay (7 × stagger) hasn't elapsed yet: still hidden.
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityOf(tester, 'item 0'), greaterThan(0));
      expect(opacityOf(tester, 'item 7'), 0);
      // From index 8 the item is never wrapped, so it is fully visible.
      expect(opacityOf(tester, 'item 8'), 1);

      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        expect(opacityOf(tester, 'item $i'), 1);
      }
    },
  );

  testWidgets('reduce motion shows everything immediately', (tester) async {
    await tester.pumpWidget(list(reduceMotion: true));
    for (var i = 0; i < 8; i++) {
      expect(opacityOf(tester, 'item $i'), 1);
    }
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('drag proxy scope skips the entrance animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoEntranceAnimation(child: const Text('dragged').animateIn()),
      ),
    );
    expect(opacityOf(tester, 'dragged'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
