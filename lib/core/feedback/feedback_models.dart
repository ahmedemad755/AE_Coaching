import 'package:flutter/foundation.dart';

/// Kind of transient feedback. Drives the icon, accent colour, default
/// duration and the accessibility prefix of a feedback card.
enum FeedbackType { success, error, warning, info, emailVerification, loading }

/// Critical feedback jumps ahead of queued normal feedback and replaces a
/// visible normal message instead of waiting behind it.
enum FeedbackPriority { normal, critical }

/// Optional single action on a feedback card (for example "Retry").
@immutable
class FeedbackAction {
  const FeedbackAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Default on-screen time per type. Errors and warnings stay longer so they
/// can be read; loading stays until it is explicitly resolved.
abstract final class FeedbackDurations {
  static const success = Duration(seconds: 3);
  static const info = Duration(milliseconds: 3500);
  static const emailVerification = Duration(seconds: 5);
  static const warning = Duration(seconds: 5);
  static const error = Duration(seconds: 6);

  static Duration? forType(FeedbackType type) => switch (type) {
    FeedbackType.success => success,
    FeedbackType.info => info,
    FeedbackType.emailVerification => emailVerification,
    FeedbackType.warning => warning,
    FeedbackType.error => error,
    FeedbackType.loading => null,
  };
}

/// One feedback notification. Immutable: updates produce a copy with a
/// higher [revision], so the host can tell "same card, new content" (for
/// example a loading handle resolving to success) from "new card".
@immutable
class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.dedupeKey,
    this.message,
    this.action,
    this.duration,
    this.priority = FeedbackPriority.normal,
    this.dismissible = true,
    this.progress,
    this.ownerUid,
    this.showCountdown = false,
    this.revision = 0,
  });

  final int id;
  final FeedbackType type;
  final String title;
  final String? message;
  final FeedbackAction? action;

  /// Auto-dismiss delay; `null` keeps the card until it is dismissed
  /// (loading).
  final Duration? duration;
  final FeedbackPriority priority;
  final bool dismissible;

  /// Identical feedback (same key) is never stacked: re-showing it only
  /// restarts the visible card's timer.
  final String dedupeKey;

  /// Determinate progress (0–1) for loading feedback, or `null`.
  final double? progress;

  /// Signed-in user when the feedback was created. Feedback that belongs to
  /// another user is dropped when the signed-in user changes.
  final String? ownerUid;

  /// Shows a thin auto-dismiss progress bar. Off by default: it repaints
  /// every frame while visible, so it is reserved for messages where the
  /// remaining time matters.
  final bool showCountdown;
  final int revision;

  bool get isLoading => type == FeedbackType.loading;

  FeedbackEntry copyWith({
    FeedbackType? type,
    String? title,
    String? message,
    bool clearMessage = false,
    FeedbackAction? action,
    Duration? duration,
    bool clearDuration = false,
    FeedbackPriority? priority,
    bool? dismissible,
    double? progress,
    bool clearProgress = false,
    String? dedupeKey,
  }) => FeedbackEntry(
    id: id,
    type: type ?? this.type,
    title: title ?? this.title,
    message: clearMessage ? null : (message ?? this.message),
    action: action ?? this.action,
    duration: clearDuration ? null : (duration ?? this.duration),
    priority: priority ?? this.priority,
    dismissible: dismissible ?? this.dismissible,
    progress: clearProgress ? null : (progress ?? this.progress),
    dedupeKey: dedupeKey ?? this.dedupeKey,
    ownerUid: ownerUid,
    showCountdown: showCountdown,
    revision: revision + 1,
  );
}
