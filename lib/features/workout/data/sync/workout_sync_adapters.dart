import 'package:ae_coaching/core/sync/canonical_hash.dart';
import 'package:ae_coaching/core/sync/revision_cloud.dart';
import 'package:ae_coaching/core/sync/revision_sync_engine.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';

/// Workout days (`users/{uid}/workout_templates`).
class WorkoutTemplateSyncAdapter extends SyncAdapter<WorkoutTemplate> {
  @override
  String get kind => 'template';

  @override
  SyncMeta metaOf(WorkoutTemplate item) => item.syncMeta;

  @override
  WorkoutTemplate withMeta(WorkoutTemplate item, SyncMeta meta) =>
      item.withSyncMeta(meta);

  @override
  String fingerprint(WorkoutTemplate item) => item.contentFingerprint;

  @override
  Map<String, dynamic> cloudContent(WorkoutTemplate item) =>
      item.toCloudContent();

  @override
  Map<String, dynamic> extraCloudFields(WorkoutTemplate item) => {
    if (item.syncMeta.legacyDecision != null)
      'legacyDecision': item.syncMeta.legacyDecision,
  };

  /// The rules refuse a day with more than the activity limit: it stays on
  /// this device, flagged, until the user splits it.
  static const tooManyActivities = 'tooManyActivities';

  @override
  String? cannotSync(WorkoutTemplate item) =>
      item.exerciseAssignments.length > WorkoutLimits.maxActivitiesPerDay
      ? tooManyActivities
      : null;

  @override
  WorkoutTemplate fromCloud(CloudDoc doc, SyncMeta meta) {
    var resolved = meta;
    final decision = doc.data['legacyDecision'];
    if (decision is String && resolved.legacyDecision == null) {
      // Decided on another device: never ask here again.
      resolved = resolved.withLegacyDecision(decision);
    }
    return WorkoutTemplate.fromCloudContent(
      Map<String, dynamic>.from(doc.data),
      syncData: resolved.toMap(),
    );
  }

  /// Only the header of an old-format document: its old exercise list is
  /// never imported silently (it may be outdated, or deleted on purpose).
  @override
  WorkoutTemplate? fromLegacyCloud(CloudDoc doc) => WorkoutTemplate.fromJson(
    Map<String, dynamic>.from(doc.data),
  ).copyWith(exerciseAssignments: const []);

  @override
  Map<String, dynamic>? legacyCloudContent(CloudDoc doc) =>
      WorkoutTemplate.fromJson(
        Map<String, dynamic>.from(doc.data),
      ).toCloudContent();

  @override
  bool isLegacyShell(WorkoutTemplate item) =>
      item.syncMeta.origin == 'serverLegacy' &&
      item.exerciseAssignments.isEmpty &&
      item.syncMeta.legacyDecision == null;

  /// The legacy restoration decision matrix (Stage 2 design §4). An empty
  /// local list is never taken as proof that data was lost:
  ///
  /// | local list | old cloud list | situation                          | outcome                        |
  /// |------------|----------------|------------------------------------|--------------------------------|
  /// | any        | (decided)      | user already answered              | migrate, never ask again       |
  /// | any        | empty/missing  | nothing to restore                 | migrate local                  |
  /// | non-empty  | non-empty      | local is authoritative (as today)  | migrate; manual restore only   |
  /// | empty      | non-empty      | local edited after the cloud copy  | migrate; manual restore only   |
  /// | empty      | non-empty      | not newer / unknown                | wait: offer with preview       |
  /// | (none)     | non-empty      | new device, no local history       | wait: offer with preview       |
  ///
  /// The old cloud list is never deleted or changed (rules forbid it).
  @override
  LegacyOutcome legacyPlan(WorkoutTemplate local, CloudDoc legacyDoc) {
    final legacy = _legacyActivities(legacyDoc);
    if (local.syncMeta.legacyDecision != null || legacy.isEmpty) {
      return const LegacyOutcome.migrate();
    }
    final savedAt =
        legacyDoc.data['updatedAt'] as String? ??
        legacyDoc.data['createdAt'] as String?;
    Map<String, Object?> candidate({required bool prompt}) => {
      'prompt': prompt,
      'savedAt': ?savedAt,
      'items': [for (final item in legacy) item.toActivityMap()],
    };
    if (local.exerciseAssignments.isNotEmpty) {
      final same =
          contentHash([
            for (final a in local.exerciseAssignments) a.toActivityMap(),
          ]) ==
          contentHash([for (final a in legacy) a.toActivityMap()]);
      return LegacyOutcome.migrate(
        candidate: same ? null : candidate(prompt: false),
      );
    }
    if (local.syncMeta.origin == 'serverLegacy') {
      return LegacyOutcome.awaitUser(candidate(prompt: true));
    }
    final serverUpdated = savedAt == null ? null : DateTime.tryParse(savedAt);
    final localUpdated = local.updatedAt;
    if (localUpdated != null &&
        serverUpdated != null &&
        localUpdated.isAfter(serverUpdated)) {
      return LegacyOutcome.migrate(candidate: candidate(prompt: false));
    }
    return LegacyOutcome.awaitUser(candidate(prompt: true));
  }

  static List<WorkoutTemplateExerciseAssignment> _legacyActivities(
    CloudDoc doc,
  ) {
    final raw = doc.data['exerciseAssignments'];
    if (raw is! List) return const [];
    final result = <WorkoutTemplateExerciseAssignment>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(
          WorkoutTemplateExerciseAssignment.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      } catch (_) {
        // A malformed old entry is skipped, never guessed.
      }
    }
    return result;
  }
}

/// Custom exercises (`users/{uid}/custom_exercises`): document id = the
/// local id, so migrating twice or from two devices can never duplicate.
class CustomExerciseSyncAdapter extends SyncAdapter<CustomExercise> {
  @override
  String get kind => 'customExercise';

  @override
  SyncMeta metaOf(CustomExercise item) => item.syncMeta;

  @override
  CustomExercise withMeta(CustomExercise item, SyncMeta meta) =>
      item.withSyncMeta(meta);

  @override
  String fingerprint(CustomExercise item) => item.contentFingerprint;

  @override
  Map<String, dynamic> cloudContent(CustomExercise item) =>
      item.toCloudContent();

  @override
  CustomExercise fromCloud(CloudDoc doc, SyncMeta meta) =>
      CustomExercise.fromCloudContent(
        Map<String, dynamic>.from(doc.data),
        syncData: meta.toMap(),
      );
}
