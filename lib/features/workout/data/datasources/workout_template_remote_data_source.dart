import 'package:ae_coaching/core/sync/firestore_revision_cloud.dart';
import 'package:ae_coaching/core/sync/revision_cloud.dart';

/// Cloud copy of workout days: `users/{uid}/workout_templates`, schema 2
/// (activities included, revision-protected). Written only through the sync
/// engine (see WorkoutTemplateRepository), never with a raw `set`/`delete`.
abstract interface class WorkoutTemplateRemoteDataSource
    implements RevisionCloud {}

class WorkoutTemplateRemoteDataSourceImpl extends FirestoreRevisionCloud
    implements WorkoutTemplateRemoteDataSource {
  WorkoutTemplateRemoteDataSourceImpl({
    super.firestore,
    super.auth,
    super.timeout,
  }) : super(collection: 'workout_templates');
}

/// Cloud copy of custom exercises: `users/{uid}/custom_exercises`, schema 2.
/// The document id is the exercise's local id (stable across devices).
abstract interface class CustomExerciseRemoteDataSource
    implements RevisionCloud {}

class CustomExerciseRemoteDataSourceImpl extends FirestoreRevisionCloud
    implements CustomExerciseRemoteDataSource {
  CustomExerciseRemoteDataSourceImpl({
    super.firestore,
    super.auth,
    super.timeout,
  }) : super(collection: 'custom_exercises');
}
