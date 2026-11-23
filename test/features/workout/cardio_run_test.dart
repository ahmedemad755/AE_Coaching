import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_run.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_timer_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const countdown = CardioPlan(mode: CardioMode.countdown, durationSeconds: 1200);
const stopwatch = CardioPlan(mode: CardioMode.stopwatch);
const stopwatchTarget = CardioPlan(
  mode: CardioMode.stopwatch,
  durationSeconds: 600,
);
const intervals = CardioPlan(
  mode: CardioMode.intervals,
  warmupSeconds: 60,
  workSeconds: 30,
  intervalRestSeconds: 15,
  rounds: 3,
  cooldownSeconds: 45,
);

const t0 = 1700000000000;
int at(int seconds) => t0 + seconds * 1000;

class _Remote implements WorkoutSessionRemoteDataSource {
  final docs = <String, Map<String, dynamic>>{};

  @override
  Future<void> syncSession(String id, WorkoutSession session) async =>
      docs[id] = session.toJson();

  @override
  Future<void> deleteSession(String id) async => docs.remove(id);

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => [
    for (final entry in docs.entries) _Doc(entry.key, entry.value),
  ];
}

// ignore: subtype_of_sealed_class
class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => Map.of(_data);
}

void main() {
  group('the timer (pure)', () {
    test('countdown: nothing runs until started; pause keeps the time; '
        'it completes itself at the planned time', () {
      var run = const CardioRun();
      expect(run.elapsedAt(at(500)), 0);
      run = run.start(at(0));
      expect(run.elapsedAt(at(100)), 100000);
      run = run.pause(at(100));
      expect(run.elapsedAt(at(900)), 100000, reason: 'paused time not counted');
      run = run.resume(at(1000));
      expect(run.elapsedAt(at(1050)), 150000);
      expect(run.settle(at(1050), countdown).status, CardioRunStatus.running);

      // Ran out while the app was away: completed at the planned time, with
      // the moment it actually ran out.
      final done = run.settle(at(5000), countdown);
      expect(done.status, CardioRunStatus.completed);
      expect(done.actualSeconds, 1200);
      expect(done.endedAtMs, at(1000 + 1100));
    });

    test('finishing early is "ended early", never completed; skipping keeps '
        'the time but is never completed', () {
      final run = const CardioRun().start(at(0));
      final early = run.finish(at(300), countdown);
      expect(early.status, CardioRunStatus.endedEarly);
      expect(early.actualSeconds, 300);

      final skipped = run.skip(at(300));
      expect(skipped.status, CardioRunStatus.skipped);
      expect(skipped.countsAsTraining, isFalse);
      expect(
        skipped.finish(at(400), countdown).status,
        CardioRunStatus.skipped,
      );
      expect(const CardioRun().skip(at(0)).status, CardioRunStatus.skipped);
      // A skipped activity can still be done afterwards, from zero.
      final again = skipped.start(at(1000));
      expect(again.status, CardioRunStatus.running);
      expect(again.elapsedAt(at(1010)), 10000);
    });

    test('stopwatch: counts up with no end; finishing without a target is '
        'completed, before its target is ended early', () {
      final run = const CardioRun().start(at(0));
      expect(run.settle(at(4000), stopwatch).status, CardioRunStatus.running);
      expect(run.finish(at(4000), stopwatch).status, CardioRunStatus.completed);
      expect(
        run.finish(at(300), stopwatchTarget).status,
        CardioRunStatus.endedEarly,
      );
      expect(
        run.finish(at(700), stopwatchTarget).status,
        CardioRunStatus.completed,
      );
    });

    test('a timer left running for days stops at the longest time allowed', () {
      final run = const CardioRun().start(at(0));
      final settled = run.settle(at(3 * 24 * 3600), stopwatch);
      expect(settled.status, CardioRunStatus.paused);
      expect(settled.actualSeconds, CardioRun.maxSeconds);
    });

    test('the clock moved back: a running timer never counts backwards', () {
      final run = const CardioRun().start(at(100));
      expect(run.elapsedAt(at(50)), 0);
      final rebased = run.rebase(at(50), 30000);
      expect(rebased.elapsedAt(at(60)), 40000);
    });

    test('intervals: warm-up, work and rest per round (no rest after the '
        'last), cool-down; the total matches the planned time', () {
      final phases = intervalPhases(intervals);
      expect(
        [for (final p in phases) '${p.kind.name}${p.round}'],
        ['warmup0', 'work1', 'rest1', 'work2', 'rest2', 'work3', 'cooldown0'],
      );
      expect(
        phases.fold<int>(0, (total, p) => total + p.seconds),
        intervals.plannedSeconds,
      );
      expect(
        intervalPositionAt(phases, 0)!.phase.kind,
        IntervalPhaseKind.warmup,
      );
      final work1 = intervalPositionAt(phases, 60)!;
      expect(work1.phase.kind, IntervalPhaseKind.work);
      expect(work1.remainingSeconds, 30);
      expect(work1.next!.kind, IntervalPhaseKind.rest);
      expect(
        intervalPositionAt(phases, 95)!.phase.kind,
        IntervalPhaseKind.rest,
      );
      final last = intervalPositionAt(phases, intervals.plannedSeconds! - 1)!;
      expect(last.phase.kind, IntervalPhaseKind.cooldown);
      expect(last.next, isNull);
      expect(intervalPositionAt(phases, intervals.plannedSeconds!), isNull);
      // The whole plan completes by itself.
      final done = const CardioRun()
          .start(at(0))
          .settle(at(intervals.plannedSeconds!), intervals);
      expect(done.status, CardioRunStatus.completed);
    });

    test('saved and read back; malformed records never throw', () {
      final run = CardioRun.planned(
        plan: intervals,
        name: 'Rowing',
        exerciseId: 'repdb:rowing',
      ).start(at(0)).pause(at(42));
      final back = CardioRun.fromMap(run.toMap());
      expect(back.toMap(), run.toMap());
      expect(back.plannedSeconds, intervals.plannedSeconds);

      expect(CardioRun.fromMap(null).status, CardioRunStatus.notStarted);
      final odd = CardioRun.fromMap({
        'status': 'running', // no start time: cannot keep counting
        'elapsedMs': 'x',
        'mode': 7,
        'name': 3,
      });
      expect(odd.status, CardioRunStatus.paused);
      expect(odd.elapsedMs, 0);
      expect(
        CardioRun.fromMap({'status': 'weird'}).status,
        CardioRunStatus.notStarted,
      );
      expect(CardioRun.fromMap({'elapsedMs': -5}).elapsedMs, 0);
      expect(readActivityRuns(null), isEmpty, reason: 'records from before');
      expect(readActivityRuns('nope'), isEmpty);
      expect(
        readActivityRuns({
          1: {},
          'a': 'b',
          'ok': {'status': 'paused'},
        }),
        {
          'ok': {'status': 'paused'},
        },
      );
    });
  });

  group('the timer on screen (controller)', () {
    late int now;
    late List<CardioRun> saved;
    late List<CardioCue> cues;

    CardioTimerController controller(CardioPlan plan, [CardioRun? initial]) =>
        CardioTimerController(
          plan: plan,
          initial: initial ?? const CardioRun(),
          save: (run) async => saved.add(run),
          onCue: cues.add,
          now: () => now,
        );

    setUp(() {
      now = t0;
      saved = [];
      cues = [];
    });

    test('start, pause, resume and finish are each saved once', () async {
      final timer = controller(countdown);
      expect(await timer.start(), isTrue);
      expect(await timer.start(), isFalse, reason: 'no duplicate start');
      now = at(60);
      timer.tick();
      expect(timer.remainingSeconds, 1140);
      expect(await timer.pause(), isTrue);
      now = at(600);
      timer.tick();
      expect(timer.elapsedSeconds, 60);
      expect(await timer.resume(), isTrue);
      now = at(660);
      timer.tick();
      expect(timer.elapsedSeconds, 120);
      expect(await timer.finish(), isTrue);
      expect(
        [for (final run in saved) run.status],
        [
          CardioRunStatus.running,
          CardioRunStatus.paused,
          CardioRunStatus.running,
          CardioRunStatus.endedEarly,
        ],
      );
      timer.dispose();
    });

    test('a failed save leaves the timer where it was', () async {
      final timer = CardioTimerController(
        plan: countdown,
        initial: const CardioRun(),
        save: (_) async => throw Exception('disk full'),
        now: () => now,
      );
      await expectLater(timer.start(), throwsException);
      expect(timer.status, CardioRunStatus.notStarted);
      timer.dispose();
    });

    test(
      'interval phases change by themselves, with a cue each time',
      () async {
        final timer = controller(intervals);
        await timer.start();
        now = at(59);
        timer.tick();
        expect(timer.position!.phase.kind, IntervalPhaseKind.warmup);
        expect(cues, isEmpty);
        now = at(60);
        timer.tick();
        expect(timer.position!.phase.kind, IntervalPhaseKind.work);
        expect(timer.position!.phase.round, 1);
        now = at(90);
        timer.tick();
        expect(timer.position!.phase.kind, IntervalPhaseKind.rest);
        expect(cues, [CardioCue.phaseChanged, CardioCue.phaseChanged]);
        now = at(intervals.plannedSeconds! + 5);
        timer.tick();
        expect(timer.status, CardioRunStatus.completed);
        expect(cues.last, CardioCue.finished);
        expect(saved.last.status, CardioRunStatus.completed);
        timer.dispose();
      },
    );

    test('reopened after the app was closed: the time kept counting; a plan '
        'that ran out meanwhile is completed without a cue', () async {
      final running = const CardioRun().start(at(0));
      now = at(300);
      final restored = controller(countdown, running);
      expect(restored.status, CardioRunStatus.running);
      expect(restored.elapsedSeconds, 300);
      restored.dispose();

      now = at(5000);
      final over = controller(countdown, running);
      expect(over.status, CardioRunStatus.completed);
      expect(over.run.actualSeconds, 1200);
      expect(cues, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(saved.single.status, CardioRunStatus.completed);
      over.dispose();
    });

    test(
      'the clock moved back while running: the time shown never drops',
      () async {
        final timer = controller(stopwatch);
        await timer.start();
        now = at(120);
        timer.tick();
        expect(timer.elapsedSeconds, 120);
        now = at(20); // the phone's clock went back 100 s
        timer.tick();
        expect(timer.elapsedSeconds, 120);
        now = at(30);
        timer.tick();
        expect(timer.elapsedSeconds, 130);
        timer.dispose();
      },
    );

    test(
      'redraws only when the time shown changes, not on every tick',
      () async {
        final timer = controller(countdown);
        await timer.start();
        var redraws = 0;
        timer.addListener(() => redraws++);
        for (final ms in [100, 250, 500, 750, 999]) {
          now = t0 + ms;
          timer.tick();
        }
        expect(redraws, 0, reason: 'still 20:00 on screen');
        now = at(1);
        timer.tick();
        expect(redraws, 1);
        timer.dispose();
      },
    );

    test('stopwatch target: one cue when reached, it keeps running', () async {
      final timer = controller(stopwatchTarget);
      await timer.start();
      now = at(600);
      timer.tick();
      now = at(700);
      timer.tick();
      expect(cues, [CardioCue.targetReached]);
      expect(timer.status, CardioRunStatus.running);
      timer.dispose();
    });
  });

  group('saved with the workout session', () {
    late Directory dir;
    late _Remote remote;
    late WorkoutSessionRepository sessions;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cardio_run_test_');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(WorkoutSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
      }
      remote = _Remote();
      sessions = WorkoutSessionRepository(
        remoteDataSource: remote,
        storageManager: UserStorageManager(),
        uidOverride: () => 'u1',
      );
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final run = WorkoutTemplateExerciseAssignment(
      assignmentId: 'run',
      exerciseId: 'repdb:running',
      exerciseNameSnapshot: 'Running',
      referenceType: 'builtIn',
    ).withActivity(type: ActivityType.cardio, cardio: countdown);

    test('kept through a reopen, a note edit and a cloud merge; never sent '
        'to the cloud', () async {
      final session = await sessions.startWorkoutSession(
        programId: 'p',
        workoutTemplateId: 'd',
        workoutNameSnapshot: 'Day',
        templateExerciseAssignments: [run],
      );
      final started = CardioRun.planned(
        plan: countdown,
        name: 'Running',
        exerciseId: 'repdb:running',
      ).start(at(0));
      await sessions.saveActivityRun(
        sessionId: session.id,
        assignmentId: 'run',
        run: started,
      );
      await sessions.updateSessionNote(sessionId: session.id, note: 'legs');
      final box = await sessions.getUserBox();
      await sessions.fetchAndSyncFromRemote(box);
      await box.close();

      final reopened = (await sessions.getUserBox()).get(session.id)!;
      expect(reopened.runFor('run').toMap(), started.toMap());
      expect(reopened.workoutNote, 'legs');
      expect(remote.docs[session.id]!.containsKey('activityRuns'), isFalse);
      expect(remote.docs[session.id].toString(), isNot(contains('Running')));
    });

    test('finishing the workout closes an open timer with the time it had: '
        'ended early, not completed', () async {
      final session = await sessions.startWorkoutSession(
        programId: 'p',
        workoutTemplateId: 'd',
        workoutNameSnapshot: 'Day',
        templateExerciseAssignments: [run],
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await sessions.saveActivityRun(
        sessionId: session.id,
        assignmentId: 'run',
        run: const CardioRun().start(nowMs - 300000),
      );
      final done = await sessions.completeWorkoutSession(
        sessionId: session.id,
        totalVolume: 0,
      );
      final closed = done.runFor('run');
      expect(closed.status, CardioRunStatus.endedEarly);
      expect(closed.actualSeconds, inInclusiveRange(299, 302));
      await expectLater(
        sessions.saveActivityRun(
          sessionId: session.id,
          assignmentId: 'run',
          run: const CardioRun(),
        ),
        throwsException,
        reason: 'a finished workout is not changed by a timer',
      );
    });

    test('a session without timers reads as none', () async {
      final box = await sessions.getUserBox();
      await box.put(
        'old',
        WorkoutSession(
          id: 'old',
          programId: 'p',
          workoutTemplateId: 'd',
          workoutNameSnapshot: 'Day',
          date: DateTime(2026),
          startedAt: DateTime(2026),
          status: 'completed',
        ),
      );
      await box.close();
      final read = (await sessions.getUserBox()).get('old')!;
      expect(read.activityRuns, isEmpty);
      expect(read.runFor('x').status, CardioRunStatus.notStarted);
    });
  });
}
