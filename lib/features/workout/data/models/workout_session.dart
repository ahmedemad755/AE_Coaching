import 'package:hive/hive.dart';

part 'workout_session.g.dart';

/// One actual execution of a [WorkoutTemplate] (e.g. "Push 1 — Sep 1").
///
/// The template is reusable; a session is a historical, immutable-in-
/// identity record of one time it was trained. [programId],
/// [workoutTemplateId], and [workoutNameSnapshot] are captured at
/// creation and never change afterward — so if a template is later
/// renamed, old sessions keep showing the name they had *at the time*,
/// never a silently-updated one.
@HiveType(typeId: 5)
class WorkoutSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String programId;

  @HiveField(2)
  final String workoutTemplateId;

  @HiveField(3)
  final String workoutNameSnapshot;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final DateTime startedAt;

  @HiveField(6)
  final DateTime? completedAt;

  /// Stable string value of [WorkoutSessionStatus] — deliberately a
  /// String, not a raw Dart enum index, so Hive/Firestore storage never
  /// breaks if the enum's declaration order ever changes later. Use
  /// [statusValue] to work with it as a real enum in code.
  @HiveField(7)
  final String status;

  @HiveField(8)
  final double totalVolume;

  @HiveField(9)
  final String? previousSessionId;

  /// Session-level note (Phase 18 already plans this — added now as a
  /// nullable field to avoid a second migration later; unused until
  /// then).
  @HiveField(10)
  final String? workoutNote;

  WorkoutSession({
    required this.id,
    required this.programId,
    required this.workoutTemplateId,
    required this.workoutNameSnapshot,
    required this.date,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.totalVolume = 0,
    this.previousSessionId,
    this.workoutNote,
  });

  WorkoutSessionStatus get statusValue => WorkoutSessionStatusX.fromValue(status);
  bool get isInProgress => statusValue == WorkoutSessionStatus.inProgress;
  bool get isCompleted => statusValue == WorkoutSessionStatus.completed;
  bool get isCancelled => statusValue == WorkoutSessionStatus.cancelled;

  /// [id], [programId], [workoutTemplateId], [workoutNameSnapshot],
  /// [date], and [startedAt] are hard-copied from `this` — a session's
  /// historical identity never changes through this method.
  WorkoutSession copyWith({
    DateTime? completedAt,
    String? status,
    double? totalVolume,
    String? previousSessionId,
    String? workoutNote,
  }) {
    return WorkoutSession(
      id: id,
      programId: programId,
      workoutTemplateId: workoutTemplateId,
      workoutNameSnapshot: workoutNameSnapshot,
      date: date,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      totalVolume: totalVolume ?? this.totalVolume,
      previousSessionId: previousSessionId ?? this.previousSessionId,
      workoutNote: workoutNote ?? this.workoutNote,
    );
  }

  // Cloud sync (Firestore). programId + workoutTemplateId are always
  // included so remote documents carry full comparison context.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'programId': programId,
      'workoutTemplateId': workoutTemplateId,
      'workoutNameSnapshot': workoutNameSnapshot,
      'date': date.toIso8601String(),
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status,
      'totalVolume': totalVolume,
      'previousSessionId': previousSessionId,
      'workoutNote': workoutNote,
    };
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      programId: json['programId'] as String,
      workoutTemplateId: json['workoutTemplateId'] as String,
      workoutNameSnapshot: json['workoutNameSnapshot'] as String,
      date: DateTime.parse(json['date'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      status: json['status'] as String,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0,
      previousSessionId: json['previousSessionId'] as String?,
      workoutNote: json['workoutNote'] as String?,
    );
  }
}

/// Required states only: inProgress, completed, cancelled.
enum WorkoutSessionStatus { inProgress, completed, cancelled }

extension WorkoutSessionStatusX on WorkoutSessionStatus {
  /// Stable string persisted to Hive/Firestore — matches `.name`
  /// exactly today, but resolving through this getter (rather than
  /// scattering raw `.name` calls) keeps every read/write in one
  /// documented place if that ever needs to diverge.
  String get value => name;

  static WorkoutSessionStatus fromValue(String value) {
    return WorkoutSessionStatus.values.firstWhere(
      (s) => s.value == value,
      // Unknown/corrupt value: fail safe rather than crash — treat as
      // inProgress so it surfaces to the user instead of silently
      // vanishing from history. Should not happen in practice since
      // this is the only place session status strings are produced.
      orElse: () => WorkoutSessionStatus.inProgress,
    );
  }
}
