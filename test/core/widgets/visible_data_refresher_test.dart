import 'dart:async';

import 'package:ae_coaching/core/widgets/visible_data_refresher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const debounce = Duration(milliseconds: 20);

/// Lets stream events, the debounce window and the reload all run.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(debounce * 3);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late StreamController<Object?> changes;
  late ValueNotifier<bool> visible;
  late int reloads;
  late int running;
  late int maxConcurrent;
  Completer<void>? gate;
  late VisibleDataRefresher refresher;

  setUp(() {
    changes = StreamController<Object?>.broadcast();
    visible = ValueNotifier<bool>(true);
    reloads = 0;
    running = 0;
    maxConcurrent = 0;
    gate = null;
    refresher = VisibleDataRefresher(
      debounce: debounce,
      reload: () async {
        reloads++;
        running++;
        if (running > maxConcurrent) maxConcurrent = running;
        try {
          await gate?.future;
        } finally {
          running--;
        }
      },
    )..attachVisibility(visible);
    refresher.watch([changes.stream]);
  });

  tearDown(() async {
    refresher.dispose();
    visible.dispose();
    await changes.close();
  });

  test('navigation alone (visibility flips) never reloads', () async {
    for (var i = 0; i < 5; i++) {
      visible.value = false;
      visible.value = true;
    }
    await settle();
    expect(reloads, 0);
  });

  test('a change while visible reloads exactly once', () async {
    changes.add(null);
    await settle();
    expect(reloads, 1);
    expect(refresher.isDirty, isFalse);
  });

  test('changes while hidden wait, then reload once when shown', () async {
    visible.value = false;
    changes
      ..add(null)
      ..add(null)
      ..add(null);
    await settle();
    expect(reloads, 0);
    expect(refresher.isDirty, isTrue);

    visible.value = true;
    await settle();
    expect(reloads, 1);

    // Showing it again without new changes does nothing.
    visible.value = false;
    visible.value = true;
    await settle();
    expect(reloads, 1);
  });

  test(
    'a burst during a reload queues exactly one more, never overlapping',
    () async {
      gate = Completer<void>();
      changes.add(null);
      await settle();
      expect(reloads, 1);

      for (var i = 0; i < 10; i++) {
        changes.add(null);
      }
      await settle();
      expect(reloads, 1, reason: 'still waiting for the first reload');

      final first = gate!;
      gate = null;
      first.complete();
      await settle();
      expect(reloads, 2);
      expect(maxConcurrent, 1);
    },
  );

  test('a burst in the same turn is coalesced into one reload', () async {
    for (var i = 0; i < 10; i++) {
      changes.add(null);
    }
    await settle();
    expect(reloads, 1);
  });

  test(
    'writes trickling in (like Hive saving a workout) reload once',
    () async {
      for (var i = 0; i < 10; i++) {
        changes.add(null);
        await Future<void>.delayed(debounce ~/ 4);
      }
      expect(reloads, 0, reason: 'still inside the debounce window');
      await settle();
      expect(reloads, 1);
    },
  );

  test('markClean: a load started elsewhere covers pending changes', () async {
    visible.value = false;
    changes.add(null);
    await settle();
    refresher.markClean();
    visible.value = true;
    await settle();
    expect(reloads, 0);
  });

  test(
    'reset drops pending changes and stops watching (user switch)',
    () async {
      visible.value = false;
      changes.add(null);
      await settle();
      refresher.reset();
      visible.value = true;
      changes.add(null);
      await settle();
      expect(reloads, 0);

      final next = StreamController<Object?>.broadcast();
      addTearDown(next.close);
      refresher.watch([next.stream]);
      next.add(null);
      await settle();
      expect(reloads, 1);
    },
  );

  test('a failed reload does not break later refreshes', () async {
    var fail = true;
    final failing = VisibleDataRefresher(
      debounce: debounce,
      reload: () async {
        reloads++;
        if (fail) throw StateError('offline');
      },
    )..watch([changes.stream]);
    addTearDown(failing.dispose);
    refresher.dispose();

    changes.add(null);
    await settle();
    expect(reloads, 1);
    fail = false;
    changes.add(null);
    await settle();
    expect(reloads, 2);
  });

  test('dispose stops all reloads and listeners', () async {
    refresher.dispose();
    changes.add(null);
    visible.value = false;
    visible.value = true;
    await settle();
    expect(reloads, 0);
  });
}
