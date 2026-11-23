import 'dart:io';

import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/day_sync_review.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/layout/keyboard_phone.dart';
import '../../support/fake_revision_cloud.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';

class _DaysCloud extends FakeRevisionCloud
    implements WorkoutTemplateRemoteDataSource {}

WorkoutTemplateRepository _phone(
  String uid,
  UserStorageManager storage,
  _DaysCloud cloud,
) => WorkoutTemplateRepository(
  remoteDataSource: cloud,
  storageManager: storage,
  uidOverride: () => uid,
);

Map<String, dynamic> _oldDoc() => {
  'id': 'old-day',
  'programId': 'p1',
  'name': 'Legs',
  'createdAt': '2026-09-01T00:00:00.000Z',
  'updatedAt': '2026-09-02T00:00:00.000Z',
  'isArchived': false,
  'exerciseAssignments': [
    for (final name in ['Squat', 'Leg press'])
      WorkoutTemplateExerciseAssignment(
        assignmentId: name,
        exerciseId: 'repdb:$name',
        exerciseNameSnapshot: name,
        referenceType: 'builtIn',
      ).toJson(),
  ],
};

void main() {
  late Directory dir;
  late UserStorageManager storage;
  late _DaysCloud cloud;

  var run = 0;
  String uid(String name) => '$name-$run';

  // Real file I/O never completes inside widget tests' fake time, so the
  // storage folder is created once and removed once, outside of any test;
  // each test uses its own users (its own boxes).
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('day_sync_review_');
    Hive.init(dir.path);
    Hive.registerAdapter(WorkoutTemplateAdapter());
    Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
  });

  tearDownAll(() async {
    // Background syncs started inside a widget test's fake time can leave
    // writes that never complete afterwards: bounded, best-effort cleanup of
    // a temporary folder.
    try {
      await Hive.close().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    run++;
    storage = UserStorageManager();
    cloud = _DaysCloud();
  });

  /// Lets real Hive I/O finish (it never completes in fake time), then
  /// advances frames; no pumpAndSettle, which a loading spinner would block.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpCard(
    WidgetTester tester,
    WorkoutTemplateRepository repository,
    String dayId, {
    String language = 'en',
  }) async {
    final box = (await tester.runAsync(repository.getUserBox))!;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        builder: AppFeedbackHost.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<WorkoutTemplate> live, _) {
              final day = live.get(dayId);
              return day == null
                  ? const Text('removed')
                  : DaySyncNotice(template: day, repository: repository);
            },
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'conflict: both versions previewed; "keep this phone\'s version" wins',
    (tester) async {
      final a = _phone(uid('a'), storage, cloud);
      final b = _phone(uid('b'), storage, cloud);
      late String id;
      await tester.runAsync(() async {
        id = (await a.createTemplate(programId: 'p1', name: 'Push')).id;
        await a.fetchAndSyncFromRemote(await a.getUserBox());
        await b.fetchAndSyncFromRemote(await b.getUserBox());
        // Each edit also starts a background sync, so the order is fixed:
        // A's edit reaches the cloud, then B edits its now outdated copy.
        await a.updateTemplate(templateId: id, name: 'From A');
        await a.fetchAndSyncFromRemote(await a.getUserBox());
        await b.updateTemplate(templateId: id, name: 'From B');
        await b.fetchAndSyncFromRemote(await b.getUserBox());
      });
      await pumpCard(tester, b, id);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DaySyncNotice)),
      )!;
      expect(find.byKey(ValueKey('day-sync-notice-$id')), findsOneWidget);
      expect(find.text(l10n.syncEditedElsewhereTitle), findsOneWidget);

      await tester.tap(find.text(l10n.syncReviewAction));
      await settle(tester);
      expect(find.text(l10n.syncThisPhone), findsOneWidget);
      expect(find.text(l10n.syncOtherVersion), findsOneWidget);
      expect(find.text('From A'), findsOneWidget);
      expect(find.text('From B'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sync-review-primary')));
      await settle(tester);
      expect(find.byKey(ValueKey('day-sync-notice-$id')), findsNothing);
      final day = (await tester.runAsync<WorkoutTemplate?>(
        () async => (await b.getUserBox()).get(id),
      ))!;
      expect(day.name, 'From B');
      expect(day.syncMeta.hasConflict, isFalse);
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language: earlier exercises are previewed and restored only on confirmation',
      (tester) async {
        cloud.docs['old-day'] = _oldDoc();
        final phone = _phone(uid('new-phone'), storage, cloud);
        await tester.runAsync(
          () async => phone.fetchAndSyncFromRemote(await phone.getUserBox()),
        );
        await pumpCard(tester, phone, 'old-day', language: language);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DaySyncNotice)),
        )!;
        expect(find.text(l10n.syncLegacyTitle), findsOneWidget);

        await tester.tap(find.text(l10n.syncReviewAction));
        await settle(tester);
        expect(find.text(l10n.syncLegacyBody(2)), findsOneWidget);
        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('Leg press'), findsOneWidget);
        // Nothing restored by just looking.
        var day = (await tester.runAsync<WorkoutTemplate?>(
          () async => (await phone.getUserBox()).get('old-day'),
        ))!;
        expect(day.exerciseAssignments, isEmpty);

        await tester.tap(find.byKey(const ValueKey('sync-review-primary')));
        await settle(tester);
        day = (await tester.runAsync<WorkoutTemplate?>(
          () async => (await phone.getUserBox()).get('old-day'),
        ))!;
        expect(day.exerciseAssignments.map((a) => a.exerciseNameSnapshot), [
          'Squat',
          'Leg press',
        ]);
        expect(
          find.byKey(const ValueKey('day-sync-notice-old-day')),
          findsNothing,
        );
      },
    );
  }

  testWidgets('an optional earlier version is a quiet link, not a warning', (
    tester,
  ) async {
    cloud.docs['old-day'] = _oldDoc();
    final phone = _phone(uid('p'), storage, cloud);
    await tester.runAsync(() async {
      final box = await phone.getUserBox();
      // This phone has its own (different) list for the day: it is kept.
      await box.put(
        'old-day',
        WorkoutTemplate(
          id: 'old-day',
          programId: 'p1',
          name: 'Legs',
          createdAt: DateTime.utc(2026, 9),
          exerciseAssignments: [
            WorkoutTemplateExerciseAssignment(
              assignmentId: 'dl',
              exerciseId: 'repdb:deadlift',
              exerciseNameSnapshot: 'Deadlift',
              referenceType: 'builtIn',
            ),
          ],
        ),
      );
      await phone.fetchAndSyncFromRemote(box);
    });
    await pumpCard(tester, phone, 'old-day');
    expect(find.byKey(const ValueKey('day-sync-notice-old-day')), findsNothing);
    expect(
      find.byKey(const ValueKey('day-earlier-version-old-day')),
      findsOneWidget,
    );
  });

  for (final language in ['en', 'ar']) {
    testWidgets('$language · small phone, text ×1.3: the review sheet fits', (
      tester,
    ) async {
      useSmallPhone(tester, textScale: 1.3);
      cloud.docs['old-day'] = _oldDoc();
      final phone = _phone(uid('small'), storage, cloud);
      await tester.runAsync(
        () async => phone.fetchAndSyncFromRemote(await phone.getUserBox()),
      );
      await pumpCard(tester, phone, 'old-day', language: language);
      expectNoOverflow(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DaySyncNotice)),
      )!;
      await tester.tap(find.text(l10n.syncReviewAction));
      await settle(tester);
      expectNoOverflow(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('sync-review-secondary')),
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(
        find.byKey(const ValueKey('sync-review-secondary')),
      );
      expect(
        button.bottom,
        lessThanOrEqualTo(smallPhone.height - navigationBar),
      );
    });
  }

  Map<String, dynamic> bigOldDoc(int count) => {
    ..._oldDoc(),
    'exerciseAssignments': [
      for (var i = 0; i < count; i++)
        WorkoutTemplateExerciseAssignment(
          assignmentId: 'old$i',
          exerciseId: 'repdb:old$i',
          exerciseNameSnapshot: 'Old exercise $i',
          referenceType: 'builtIn',
        ).toJson(),
    ],
  };

  testWidgets(
    'more earlier exercises than a day holds: the preview says where each '
    'one goes, and all are restored',
    (tester) async {
      const limit = WorkoutLimits.maxActivitiesPerDay;
      cloud.docs['old-day'] = bigOldDoc(limit + 3);
      final phone = _phone(uid('big-restore'), storage, cloud);
      await tester.runAsync(
        () async => phone.fetchAndSyncFromRemote(await phone.getUserBox()),
      );
      await pumpCard(tester, phone, 'old-day');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DaySyncNotice)),
      )!;
      await tester.tap(find.text(l10n.syncReviewAction));
      await settle(tester);
      expect(
        find.text(l10n.syncLegacySplitNotice(limit, 3, 1)),
        findsOneWidget,
      );
      final sheet = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text(l10n.syncNewDayLabel('Legs (2)')),
        300,
        scrollable: sheet,
      );
      expect(find.text(l10n.syncNewDayLabel('Legs (2)')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sync-review-primary')),
        300,
        scrollable: sheet,
      );
      await tester.tap(find.byKey(const ValueKey('sync-review-primary')));
      await settle(tester);

      final all = (await tester.runAsync(
        () async => (await phone.getUserBox()).values.toList(),
      ))!;
      final day = all.firstWhere((d) => d.id == 'old-day');
      final extra = all.firstWhere((d) => d.id != 'old-day');
      expect(day.exerciseAssignments, hasLength(limit));
      expect(extra.name, 'Legs (2)');
      expect(extra.exerciseAssignments.map((a) => a.assignmentId), [
        for (var i = limit; i < limit + 3; i++) 'old$i',
      ]);
    },
  );

  testWidgets(
    'a day over the limit shows why it does not sync, and splits only after '
    'confirmation',
    (tester) async {
      const limit = WorkoutLimits.maxActivitiesPerDay;
      final phone = _phone(uid('big-local'), storage, cloud);
      await tester.runAsync(() async {
        final box = await phone.getUserBox();
        await box.put(
          'big',
          WorkoutTemplate(
            id: 'big',
            programId: 'p1',
            name: 'Everything',
            createdAt: DateTime.utc(2026, 10),
            exerciseAssignments: [
              for (var i = 0; i < limit + 2; i++)
                WorkoutTemplateExerciseAssignment(
                  assignmentId: 'e$i',
                  exerciseId: 'repdb:e$i',
                  exerciseNameSnapshot: 'Exercise $i',
                  referenceType: 'builtIn',
                ),
            ],
            syncData: SyncMeta.empty.migratedAsNew().toMap(),
          ),
        );
      });
      await pumpCard(tester, phone, 'big');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DaySyncNotice)),
      )!;
      expect(find.byKey(const ValueKey('day-too-many-big')), findsOneWidget);
      expect(find.text(l10n.syncTooManyBody(limit + 2, limit)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('day-split-big')));
      await settle(tester);
      expect(find.text(l10n.syncSplitConfirmBody(limit, 1)), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await settle(tester);
      var days = (await tester.runAsync(
        () async => (await phone.getUserBox()).values.toList(),
      ))!;
      expect(days, hasLength(1)); // nothing changed

      await tester.tap(find.byKey(const ValueKey('day-split-big')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('day-split-confirm')));
      await settle(tester);
      days = (await tester.runAsync(
        () async => (await phone.getUserBox()).values.toList(),
      ))!;
      expect(days, hasLength(2));
      expect(
        days.firstWhere((d) => d.id == 'big').exerciseAssignments,
        hasLength(limit),
      );
      expect(find.byKey(const ValueKey('day-too-many-big')), findsNothing);
    },
  );
}
