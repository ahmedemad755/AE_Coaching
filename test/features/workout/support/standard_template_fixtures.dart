import 'dart:io';
import 'dart:async';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_program_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class TemplateProgramRemote implements WorkoutProgramRemoteDataSource {
  bool fail = false;
  bool hang = false;
  final Map<String, Map<String, dynamic>> documents = {};
  @override
  Future<void> syncProgram(String id, WorkoutProgram program) async {
    if (hang) {
      return Completer<void>().future;
    }
    if (fail) throw const SocketException('Offline');
    documents[id] = program.toJson();
  }

  @override
  Future<void> deleteProgram(String id) async => documents.remove(id);
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemotePrograms() async => [];
}

class TemplateDayRemote implements WorkoutTemplateRemoteDataSource {
  bool fail = false;
  final Map<String, Map<String, dynamic>> documents = {};
  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {
    if (fail) throw const SocketException('Offline');
    documents[id] = template.toJson();
  }

  @override
  Future<void> deleteTemplate(String id) async => documents.remove(id);
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteTemplates() async => [];
}

class TemplateSessionRemote implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}
  @override
  Future<void> deleteSession(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => [];
}

StandardWorkoutTemplateRepository standardTemplateCatalog() =>
    StandardWorkoutTemplateRepository(
      catalog: ExerciseCatalogRepository(
        loadAsset: (path) async => File(path).readAsStringSync(),
      ),
      loadAsset: (path) async => File(path).readAsStringSync(),
    );

class StandardTemplateFixture {
  late Directory directory;
  String uid = 'Owner-A';
  final storage = UserStorageManager();
  final programRemote = TemplateProgramRemote();
  final dayRemote = TemplateDayRemote();
  late final programs = WorkoutProgramRepository(
    storageManager: storage,
    remoteDataSource: programRemote,
    uidOverride: () => uid,
  );
  late final days = WorkoutTemplateRepository(
    storageManager: storage,
    remoteDataSource: dayRemote,
    uidOverride: () => uid,
  );
  late final importer = WorkoutTemplateImportService(
    programs: programs,
    templates: days,
    currentUserId: () => uid,
    catalog: standardTemplateCatalog().catalog,
  );
  Future<void> open() async {
    directory = await Directory.systemTemp.createTemp('ae_standard_templates_');
    Hive.init(directory.path);
    Hive.registerAdapter(WorkoutProgramAdapter(), override: true);
    Hive.registerAdapter(WorkoutTemplateAdapter(), override: true);
    Hive.registerAdapter(
      WorkoutTemplateExerciseAssignmentAdapter(),
      override: true,
    );
    Hive.registerAdapter(WorkoutSessionAdapter(), override: true);
    Hive.registerAdapter(ExerciseSetAdapter(), override: true);
  }

  Future<WorkoutProgramDraft> draft({String language = 'en'}) async {
    final split = (await standardTemplateCatalog().loadTemplates()).first;
    return WorkoutProgramDraft.fromTemplate(
      split: split,
      variant: split.variants.first,
      languageCode: language,
      ownerUid: uid,
    );
  }

  Future<void> close() async {
    await Hive.close();
    await directory.delete(recursive: true);
  }
}
