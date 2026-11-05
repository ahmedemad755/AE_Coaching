// ignore_for_file: subtype_of_sealed_class

import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _TemplateSnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> value;

  _TemplateSnapshot(this.id, this.value);

  @override
  Map<String, dynamic> data() => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TemplateRemote implements WorkoutTemplateRemoteDataSource {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> documents = [];

  @override
  Future<void> deleteTemplate(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteTemplates() async => documents;

  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {}
}

class _SessionRemote implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => [];

  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}
}

class _SetsRemote implements WorkoutRemoteDataSource {
  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}

  @override
  Future<void> deleteSet(String key) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSets() async => [];

  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}
}

void main() {
  late Directory tempDir;
  late UserStorageManager storage;
  late _TemplateRemote templateRemote;
  late WorkoutTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('template_session_flow_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExerciseSetAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
    }

    storage = UserStorageManager();
    templateRemote = _TemplateRemote();
    templateRepository = WorkoutTemplateRepository(
      remoteDataSource: templateRemote,
      storageManager: storage,
      uidOverride: () => 'template-flow-user',
    );
    sessionRepository = WorkoutSessionRepository(
      remoteDataSource: _SessionRemote(),
      storageManager: storage,
      uidOverride: () => 'template-flow-user',
    );
    setRepository = SessionExerciseRepository(
      remoteDataSource: _SetsRemote(),
      storageManager: storage,
      uidOverride: () => 'template-flow-user',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'partial completion and stale remote data do not shrink next session template',
    () async {
      final template = await templateRepository.createTemplate(
        programId: 'push-program',
        name: 'Push A',
      );
      for (var index = 0; index < 6; index++) {
        await templateRepository.addExerciseAssignment(
          templateId: template.id,
          exerciseId: 'exercise-$index',
          exerciseNameSnapshot: 'Exercise $index',
          referenceType: WorkoutExerciseReferenceType.builtIn,
        );
      }

      final originalTemplate = (await templateRepository.getUserBox()).get(
        template.id,
      )!;
      final originalAssignments = originalTemplate.exerciseAssignments;
      final firstSession = await sessionRepository.startWorkoutSession(
        programId: template.programId,
        workoutTemplateId: template.id,
        workoutNameSnapshot: template.name,
        templateExerciseAssignments: originalAssignments,
      );

      for (final assignment in originalAssignments.take(4)) {
        await setRepository.addSet(
          programId: template.programId,
          workoutTemplateId: template.id,
          workoutSessionId: firstSession.id,
          exerciseName: assignment.exerciseNameSnapshot,
          weight: 50,
          reps: 8,
        );
      }
      await sessionRepository.completeWorkoutSession(
        sessionId: firstSession.id,
        totalVolume: 1600,
      );

      final afterCompletion = (await templateRepository.getUserBox()).get(
        template.id,
      )!;
      expect(afterCompletion.exerciseAssignments, hasLength(6));

      // Older clients may have persisted a shortened assignment list remotely.
      templateRemote.documents = [
        _TemplateSnapshot(template.id, {
          ...afterCompletion.toJson(),
          'exerciseAssignments': originalAssignments
              .take(4)
              .map((assignment) => assignment.toJson())
              .toList(),
        }),
      ];
      await templateRepository.fetchAndSyncFromRemote(
        await templateRepository.getUserBox(),
      );

      final reloadedTemplate = (await templateRepository.getUserBox()).get(
        template.id,
      )!;
      expect(
        reloadedTemplate.exerciseAssignments.map((item) => item.assignmentId),
        originalAssignments.map((item) => item.assignmentId),
      );
      expect(
        reloadedTemplate.exerciseAssignments.map((item) => item.exerciseId),
        originalAssignments.map((item) => item.exerciseId),
      );
      expect(
        reloadedTemplate.exerciseAssignments.map(
          (item) => item.exerciseNameSnapshot,
        ),
        originalAssignments.map((item) => item.exerciseNameSnapshot),
      );

      final secondSession = await sessionRepository.startWorkoutSession(
        programId: reloadedTemplate.programId,
        workoutTemplateId: reloadedTemplate.id,
        workoutNameSnapshot: reloadedTemplate.name,
        templateExerciseAssignments: reloadedTemplate.exerciseAssignments,
      );
      expect(
        secondSession.templateExerciseAssignmentsSnapshot.map(
          (item) => item.exerciseNameSnapshot,
        ),
        originalAssignments.map((item) => item.exerciseNameSnapshot),
      );
      expect(
        (await setRepository.getUserBox()).values.where(
          (set) => set.workoutSessionId == firstSession.id,
        ),
        hasLength(4),
      );

      await sessionRepository.cancelWorkoutSession(secondSession.id);
      final intentionallyRemovedId = originalAssignments[2].assignmentId;
      await templateRepository.removeExerciseAssignment(
        templateId: template.id,
        assignmentId: intentionallyRemovedId,
      );
      await templateRepository.fetchAndSyncFromRemote(
        await templateRepository.getUserBox(),
      );
      final intentionallyEdited = (await templateRepository.getUserBox()).get(
        template.id,
      )!;
      expect(
        intentionallyEdited.exerciseAssignments.map(
          (item) => item.assignmentId,
        ),
        originalAssignments
            .where((item) => item.assignmentId != intentionallyRemovedId)
            .map((item) => item.assignmentId),
      );
      final reordered = await templateRepository.reorderExerciseAssignments(
        templateId: template.id,
        orderedAssignmentIds: intentionallyEdited.exerciseAssignments.reversed
            .map((item) => item.assignmentId)
            .toList(),
      );
      final futureSession = await sessionRepository.startWorkoutSession(
        programId: template.programId,
        workoutTemplateId: template.id,
        workoutNameSnapshot: template.name,
        templateExerciseAssignments: reordered.exerciseAssignments,
      );
      expect(
        futureSession.templateExerciseAssignmentsSnapshot.map(
          (item) => item.assignmentId,
        ),
        reordered.exerciseAssignments.map((item) => item.assignmentId),
      );
      await sessionRepository.cancelWorkoutSession(futureSession.id);
    },
  );

  test(
    'cancelled and resumable sessions leave template assignments intact',
    () async {
      final template = await templateRepository.createTemplate(
        programId: 'push-program',
        name: 'Push A',
      );
      for (var index = 0; index < 6; index++) {
        await templateRepository.addExerciseAssignment(
          templateId: template.id,
          exerciseId: 'exercise-$index',
          exerciseNameSnapshot: 'Exercise $index',
          referenceType: WorkoutExerciseReferenceType.builtIn,
        );
      }
      final assignments = (await templateRepository.getUserBox())
          .get(template.id)!
          .exerciseAssignments;

      final resumable = await sessionRepository.startWorkoutSession(
        programId: template.programId,
        workoutTemplateId: template.id,
        workoutNameSnapshot: template.name,
        templateExerciseAssignments: assignments,
      );
      final first = assignments.first;
      await setRepository.addSet(
        programId: template.programId,
        workoutTemplateId: template.id,
        workoutSessionId: resumable.id,
        exerciseName: first.exerciseNameSnapshot,
        weight: 40,
        reps: 10,
      );

      await storage.closeForUser('template-flow-user');
      storage = UserStorageManager();
      templateRepository = WorkoutTemplateRepository(
        remoteDataSource: templateRemote,
        storageManager: storage,
        uidOverride: () => 'template-flow-user',
      );
      sessionRepository = WorkoutSessionRepository(
        remoteDataSource: _SessionRemote(),
        storageManager: storage,
        uidOverride: () => 'template-flow-user',
      );
      setRepository = SessionExerciseRepository(
        remoteDataSource: _SetsRemote(),
        storageManager: storage,
        uidOverride: () => 'template-flow-user',
      );

      final restoredSession = (await sessionRepository.getUserBox()).get(
        resumable.id,
      )!;
      expect(restoredSession.isInProgress, isTrue);
      expect(
        restoredSession.templateExerciseAssignmentsSnapshot.map(
          (item) => item.assignmentId,
        ),
        assignments.map((item) => item.assignmentId),
      );
      expect(
        (await templateRepository.getUserBox())
            .get(template.id)!
            .exerciseAssignments,
        hasLength(6),
      );

      await sessionRepository.cancelWorkoutSession(resumable.id);
      final empty = await sessionRepository.startWorkoutSession(
        programId: template.programId,
        workoutTemplateId: template.id,
        workoutNameSnapshot: template.name,
        templateExerciseAssignments: assignments,
      );
      await sessionRepository.cancelWorkoutSession(empty.id);
      expect(
        (await templateRepository.getUserBox())
            .get(template.id)!
            .exerciseAssignments
            .map((item) => item.assignmentId),
        assignments.map((item) => item.assignmentId),
      );
      expect(
        (await setRepository.getUserBox()).values.where(
          (set) => set.workoutSessionId == resumable.id,
        ),
        hasLength(1),
      );
    },
  );
}
