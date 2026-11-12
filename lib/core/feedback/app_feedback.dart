import 'package:ae_coaching/core/feedback/feedback_controller.dart';
import 'package:ae_coaching/core/feedback/feedback_models.dart';
import 'package:flutter/widgets.dart';

export 'package:ae_coaching/core/feedback/feedback_models.dart'
    show FeedbackAction, FeedbackPriority, FeedbackType;

/// The single app-wide API for transient user feedback (success, error,
/// warning, info, email verification and loading).
///
/// Feedback is rendered by the root [AppFeedbackHost] above the Navigator,
/// so it survives route changes and is never covered by later routes.
/// Calls need no BuildContext, but callers must pass already-localized,
/// user-safe text and keep their own `mounted` checks: feedback for an
/// operation that was cancelled or whose screen is gone must not be shown.
///
/// Presentation code decides when to show feedback; repositories and data
/// sources never call this.
abstract final class AppFeedback {
  static final List<AppFeedbackController> _hosts = [];

  /// The controller of the innermost mounted host, or `null` when none is
  /// mounted (for example a widget test without a host): calls are no-ops.
  static AppFeedbackController? get controller =>
      _hosts.isEmpty ? null : _hosts.last;

  /// Called by [AppFeedbackHost]; not for feature code.
  static void attachHost(AppFeedbackController controller) =>
      _hosts.add(controller);

  /// Called by [AppFeedbackHost]; not for feature code.
  static void detachHost(AppFeedbackController controller) =>
      _hosts.remove(controller);

  // Every shortcut takes the same options: an optional supporting
  // [message], one optional [action], a [dedupeKey] (defaults to type +
  // text) and [showCountdown] for a visible auto-dismiss progress bar.

  static int? success(
    String title, {
    String? message,
    FeedbackAction? action,
    String? dedupeKey,
    bool showCountdown = false,
  }) => show(
    FeedbackType.success,
    title,
    message: message,
    action: action,
    dedupeKey: dedupeKey,
    showCountdown: showCountdown,
  );

  /// Errors are critical: they jump ahead of queued normal feedback and
  /// stay longer. Never pass raw exception text; map it to a localized
  /// message first.
  static int? error(
    String title, {
    String? message,
    FeedbackAction? action,
    String? dedupeKey,
    bool showCountdown = false,
  }) => show(
    FeedbackType.error,
    title,
    message: message,
    action: action,
    dedupeKey: dedupeKey,
    showCountdown: showCountdown,
  );

  static int? warning(
    String title, {
    String? message,
    FeedbackAction? action,
    String? dedupeKey,
    bool showCountdown = false,
  }) => show(
    FeedbackType.warning,
    title,
    message: message,
    action: action,
    dedupeKey: dedupeKey,
    showCountdown: showCountdown,
  );

  static int? info(
    String title, {
    String? message,
    FeedbackAction? action,
    String? dedupeKey,
    bool showCountdown = false,
  }) => show(
    FeedbackType.info,
    title,
    message: message,
    action: action,
    dedupeKey: dedupeKey,
    showCountdown: showCountdown,
  );

  /// Email-verification status (link sent, not verified yet, change
  /// requested).
  static int? emailVerification(
    String title, {
    String? message,
    FeedbackAction? action,
    String? dedupeKey,
    bool showCountdown = false,
  }) => show(
    FeedbackType.emailVerification,
    title,
    message: message,
    action: action,
    dedupeKey: dedupeKey,
    showCountdown: showCountdown,
  );

  /// Shows feedback of [type]; prefer the typed shortcuts above. Returns
  /// the feedback id (for [dismiss]), or `null` when no host is mounted.
  static int? show(
    FeedbackType type,
    String title, {
    String? message,
    FeedbackAction? action,
    String? dedupeKey,
    bool showCountdown = false,
  }) => controller?.show(
    type: type,
    title: title,
    message: message,
    action: action,
    dedupeKey: dedupeKey,
    showCountdown: showCountdown,
  );

  /// Persistent loading feedback. It stays until the returned handle is
  /// resolved ([FeedbackLoadingHandle.success]/[FeedbackLoadingHandle.error])
  /// or dismissed. Prefer [runWithLoading] or [FeedbackLoadingOwner], which
  /// can never leave a stale loading card behind.
  static FeedbackLoadingHandle loading(
    String title, {
    String? message,
    double? progress,
  }) {
    final host = controller;
    if (host == null) return FeedbackLoadingHandle._(null, null);
    final id = host.show(
      type: FeedbackType.loading,
      title: title,
      message: message,
      progress: progress,
      dismissible: false,
      // Each loading operation is its own card, even with the same text.
      dedupeKey: 'loading#${DateTime.now().microsecondsSinceEpoch}#$title',
    );
    return FeedbackLoadingHandle._(host, id);
  }

  /// Runs [task] under a loading card that is always removed afterwards
  /// (success, error or exception). [successTitle]/[errorTitle] optionally
  /// resolve the card instead of just removing it; exceptions are rethrown
  /// so callers keep their own error handling.
  static Future<T> runWithLoading<T>(
    Future<T> Function() task, {
    required String title,
    String? successTitle,
    String? errorTitle,
  }) async {
    final handle = loading(title);
    try {
      final result = await task();
      successTitle == null ? handle.dismiss() : handle.success(successTitle);
      return result;
    } catch (_) {
      errorTitle == null ? handle.dismiss() : handle.error(errorTitle);
      rethrow;
    }
  }

  static void dismiss(int? id) {
    if (id != null) controller?.dismiss(id);
  }

  /// Removes all feedback (visible, queued and loading).
  static void clear() => controller?.clear();
}

/// Controls one loading card. All methods are safe after the card is gone
/// (they do nothing), so a late completion can never resurrect it.
class FeedbackLoadingHandle {
  FeedbackLoadingHandle._(this._controller, this._id);

  final AppFeedbackController? _controller;
  final int? _id;
  bool _done = false;

  bool get isActive =>
      !_done && _id != null && (_controller?.contains(_id) ?? false);

  /// Changes the loading text and/or determinate [progress] (0–1).
  void update({String? title, String? message, double? progress}) {
    if (!isActive) return;
    _controller!.update(
      _id!,
      title: title,
      message: message,
      progress: progress?.clamp(0.0, 1.0).toDouble(),
    );
  }

  /// Turns the loading card into a success card (auto-dismisses).
  void success(String title, {String? message}) =>
      _resolve(FeedbackType.success, title, message);

  /// Turns the loading card into an error card (auto-dismisses).
  void error(String title, {String? message}) =>
      _resolve(FeedbackType.error, title, message);

  void _resolve(FeedbackType type, String title, String? message) {
    if (!isActive) return;
    _done = true;
    _controller!.update(
      _id!,
      type: type,
      title: title,
      message: message,
      clearMessage: message == null,
    );
  }

  void dismiss() {
    if (_done || _id == null) return;
    _done = true;
    _controller?.dismiss(_id);
  }
}

/// For screens that show loading feedback: every loading card started with
/// [showLoadingFeedback] is removed when the screen is disposed, so a
/// route that is popped mid-operation never leaves a stale loading card.
mixin FeedbackLoadingOwner<T extends StatefulWidget> on State<T> {
  final List<FeedbackLoadingHandle> _feedbackLoadings = [];

  FeedbackLoadingHandle showLoadingFeedback(
    String title, {
    String? message,
    double? progress,
  }) {
    _feedbackLoadings.removeWhere((handle) => !handle.isActive);
    final handle = AppFeedback.loading(
      title,
      message: message,
      progress: progress,
    );
    _feedbackLoadings.add(handle);
    return handle;
  }

  @override
  void dispose() {
    for (final handle in _feedbackLoadings) {
      handle.dismiss();
    }
    _feedbackLoadings.clear();
    super.dispose();
  }
}
