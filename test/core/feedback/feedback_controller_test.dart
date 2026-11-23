import 'package:ae_coaching/core/feedback/feedback_controller.dart';
import 'package:ae_coaching/core/feedback/feedback_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppFeedbackController controller;
  String? uid;
  late int notifications;

  setUp(() {
    uid = 'user-a';
    controller = AppFeedbackController(currentUser: () => uid);
    notifications = 0;
    controller.addListener(() => notifications++);
  });

  tearDown(() => controller.dispose());

  int show(FeedbackType type, String title) =>
      controller.show(type: type, title: title);

  group('visibility and defaults', () {
    test('the first feedback becomes current with type defaults', () {
      final id = show(FeedbackType.success, 'Saved');
      final current = controller.current!;
      expect(current.id, id);
      expect(current.duration, FeedbackDurations.success);
      expect(current.priority, FeedbackPriority.normal);
      expect(current.ownerUid, 'user-a');
      expect(notifications, 1);
    });

    test(
      'errors are critical and stay longer; loading never auto-dismisses',
      () {
        show(FeedbackType.error, 'Failed');
        expect(controller.current!.priority, FeedbackPriority.critical);
        expect(controller.current!.duration, FeedbackDurations.error);
        controller.clear();
        show(FeedbackType.loading, 'Saving');
        expect(controller.current!.duration, isNull);
      },
    );
  });

  group('deduplication', () {
    test('re-showing the visible message reuses it and restarts its timer', () {
      final id = show(FeedbackType.info, 'Hello');
      final revision = controller.current!.revision;
      for (var i = 0; i < 5; i++) {
        expect(show(FeedbackType.info, 'Hello'), id);
      }
      expect(controller.current!.revision, revision + 5);
      expect(controller.queued, isEmpty);
    });

    test('a queued duplicate is not queued twice', () {
      show(FeedbackType.info, 'First');
      final queued = show(FeedbackType.success, 'Second');
      expect(show(FeedbackType.success, 'Second'), queued);
      expect(controller.queued, hasLength(1));
    });

    test('same text with a different type is a different message', () {
      show(FeedbackType.info, 'Same');
      show(FeedbackType.warning, 'Same');
      expect(controller.queued, hasLength(1));
    });
  });

  group('queueing and priority', () {
    test('normal feedback waits in order; dismissing shows the next', () {
      final a = show(FeedbackType.success, 'A');
      final b = show(FeedbackType.info, 'B');
      final c = show(FeedbackType.warning, 'C');
      expect(controller.current!.id, a);
      expect(controller.queued.map((e) => e.id), [b, c]);
      controller.dismiss(a);
      expect(controller.current!.id, b);
      controller.dismiss(b);
      expect(controller.current!.id, c);
      controller.dismiss(c);
      expect(controller.current, isNull);
    });

    test('an error replaces a visible normal message at once', () {
      show(FeedbackType.success, 'Saved');
      final error = show(FeedbackType.error, 'Failed');
      expect(controller.current!.id, error);
      expect(controller.queued, isEmpty, reason: 'transient success dropped');
    });

    test('an error preempts loading, and the loading card comes back', () {
      final loading = show(FeedbackType.loading, 'Saving');
      final error = show(FeedbackType.error, 'Network down');
      expect(controller.current!.id, error);
      controller.dismiss(error);
      expect(controller.current!.id, loading);
    });

    test('a queued error goes ahead of queued normal feedback', () {
      show(FeedbackType.error, 'E1');
      final normal = show(FeedbackType.info, 'N1');
      final e2 = show(FeedbackType.error, 'E2');
      expect(controller.queued.map((e) => e.id), [e2, normal]);
    });

    test('the queue is bounded and never drops errors or loading', () {
      show(FeedbackType.loading, 'Saving');
      final kept = [
        show(FeedbackType.error, 'E1'),
        show(FeedbackType.loading, 'Uploading'),
      ];
      for (var i = 0; i < 10; i++) {
        show(FeedbackType.info, 'info $i');
      }
      expect(controller.queued.length, AppFeedbackController.maxQueued);
      for (final id in kept) {
        expect(controller.contains(id), isTrue);
      }
      expect(controller.queued.last.title, 'info 9', reason: 'newest kept');
    });
  });

  group('updates and dismissal', () {
    test('loading resolves to success in place, with a timer', () {
      final id = controller.show(
        type: FeedbackType.loading,
        title: 'Uploading',
        progress: 0.4,
      );
      expect(controller.update(id, progress: 0.8), isTrue);
      expect(controller.current!.progress, 0.8);
      controller.update(id, type: FeedbackType.success, title: 'Uploaded');
      final current = controller.current!;
      expect(current.id, id);
      expect(current.type, FeedbackType.success);
      expect(current.duration, FeedbackDurations.success);
      expect(current.progress, isNull);
    });

    test('dismissing unknown or already-dismissed feedback is harmless', () {
      final id = show(FeedbackType.info, 'Hi');
      controller.dismiss(id);
      final before = notifications;
      controller.dismiss(id);
      controller.dismiss(999);
      expect(notifications, before);
      expect(controller.update(id, title: 'x'), isFalse);
    });

    test('clear removes everything, including loading', () {
      show(FeedbackType.loading, 'Saving');
      show(FeedbackType.info, 'Queued');
      controller.clear();
      expect(controller.current, isNull);
      expect(controller.queued, isEmpty);
    });
  });

  group('user isolation', () {
    test("a user change drops the previous user's feedback, loading too", () {
      show(FeedbackType.loading, 'Saving');
      show(FeedbackType.success, 'Saved');
      uid = null; // signed out
      final notice = show(FeedbackType.warning, 'Signed out notice');
      controller.onUserChanged(null);
      expect(controller.current!.id, notice);
      expect(controller.queued, isEmpty);
    });

    test('feedback of the same user survives a repeated user event', () {
      final id = show(FeedbackType.success, 'Saved');
      controller.onUserChanged('user-a');
      expect(controller.current!.id, id);
    });
  });
}
