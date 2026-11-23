import 'package:ae_coaching/core/feedback/feedback_models.dart';
import 'package:flutter/foundation.dart';

/// The single source of truth for which feedback is visible and what waits.
///
/// Pure logic (no widgets, no timers), so every rule is unit-testable:
/// - at most one card is visible ([current]); the rest wait in a short
///   queue, so rapid messages never stack on screen;
/// - identical feedback (same [FeedbackEntry.dedupeKey]) is never queued
///   twice; re-showing the visible one only bumps its revision so the host
///   restarts its timer;
/// - critical feedback (errors) jumps ahead of normal feedback and replaces
///   a visible normal message; a replaced loading card is kept and comes
///   back afterwards, because it is still in progress;
/// - the queue is bounded ([maxQueued]); when full, the oldest normal,
///   non-loading message is dropped, never an error or a loading card;
/// - feedback created for another user is dropped when the signed-in user
///   changes ([onUserChanged]).
class AppFeedbackController extends ChangeNotifier {
  AppFeedbackController({String? Function()? currentUser})
    : _currentUser = currentUser;

  static const maxQueued = 3;

  final String? Function()? _currentUser;
  final List<FeedbackEntry> _queue = [];
  FeedbackEntry? _current;
  int _nextId = 1;

  FeedbackEntry? get current => _current;
  List<FeedbackEntry> get queued => List.unmodifiable(_queue);

  /// Shows (or queues) new feedback and returns its id. An identical
  /// visible or queued message is reused instead (its id is returned).
  int show({
    required FeedbackType type,
    required String title,
    String? message,
    FeedbackAction? action,
    Duration? duration,
    FeedbackPriority? priority,
    bool dismissible = true,
    double? progress,
    String? dedupeKey,
    bool showCountdown = false,
  }) {
    final key = dedupeKey ?? '${type.name}|$title|${message ?? ''}';
    final current = _current;
    if (current != null && current.dedupeKey == key) {
      _current = current.copyWith(); // same card: restart its timer
      notifyListeners();
      return current.id;
    }
    for (final queued in _queue) {
      if (queued.dedupeKey == key) return queued.id;
    }

    final entry = FeedbackEntry(
      id: _nextId++,
      type: type,
      title: title,
      message: message,
      action: action,
      duration: type == FeedbackType.loading
          ? null
          : (duration ?? FeedbackDurations.forType(type)),
      priority:
          priority ??
          (type == FeedbackType.error
              ? FeedbackPriority.critical
              : FeedbackPriority.normal),
      dismissible: dismissible,
      progress: progress,
      dedupeKey: key,
      ownerUid: _currentUser?.call(),
      showCountdown: showCountdown && type != FeedbackType.loading,
    );

    if (current == null) {
      _current = entry;
    } else if (_preempts(entry, current)) {
      if (current.isLoading) _queue.insert(0, current);
      _current = entry;
    } else {
      _enqueue(entry);
    }
    notifyListeners();
    return entry.id;
  }

  bool _preempts(FeedbackEntry next, FeedbackEntry visible) =>
      next.priority == FeedbackPriority.critical &&
      visible.priority != FeedbackPriority.critical;

  void _enqueue(FeedbackEntry entry) {
    if (entry.priority == FeedbackPriority.critical) {
      final firstNormal = _queue.indexWhere(
        (e) => e.priority != FeedbackPriority.critical,
      );
      _queue.insert(firstNormal < 0 ? _queue.length : firstNormal, entry);
    } else {
      _queue.add(entry);
    }
    while (_queue.length > maxQueued) {
      final droppable = _queue.indexWhere(
        (e) => e.priority == FeedbackPriority.normal && !e.isLoading,
      );
      if (droppable < 0) break; // only errors/loading left: keep them
      _queue.removeAt(droppable);
    }
  }

  /// Updates feedback in place (same card), for example a loading handle
  /// changing its text or progress, or resolving to success/error. Returns
  /// false when the feedback is already gone.
  bool update(
    int id, {
    FeedbackType? type,
    String? title,
    String? message,
    bool clearMessage = false,
    double? progress,
    bool clearProgress = false,
  }) {
    FeedbackEntry apply(FeedbackEntry e) {
      final resolvedType = type ?? e.type;
      final resolving = e.isLoading && resolvedType != FeedbackType.loading;
      return e.copyWith(
        type: resolvedType,
        title: title,
        message: message,
        clearMessage: clearMessage,
        progress: progress,
        clearProgress: clearProgress || resolving,
        duration: resolving ? FeedbackDurations.forType(resolvedType) : null,
        priority: resolvedType == FeedbackType.error
            ? FeedbackPriority.critical
            : null,
        dedupeKey:
            '${resolvedType.name}|${title ?? e.title}|'
            '${clearMessage ? '' : (message ?? e.message ?? '')}',
      );
    }

    if (_current?.id == id) {
      _current = apply(_current!);
      notifyListeners();
      return true;
    }
    final index = _queue.indexWhere((e) => e.id == id);
    if (index < 0) return false;
    _queue[index] = apply(_queue[index]);
    notifyListeners();
    return true;
  }

  /// Removes feedback (visible or queued). Safe to call twice or with an
  /// id that no longer exists.
  void dismiss(int id) {
    if (_current?.id == id) {
      _current = _queue.isEmpty ? null : _queue.removeAt(0);
      notifyListeners();
      return;
    }
    final before = _queue.length;
    _queue.removeWhere((e) => e.id == id);
    if (_queue.length != before) notifyListeners();
  }

  /// Whether feedback with [id] is still visible or queued.
  bool contains(int id) =>
      _current?.id == id || _queue.any((entry) => entry.id == id);

  /// Removes everything (visible, queued and loading).
  void clear() {
    if (_current == null && _queue.isEmpty) return;
    _current = null;
    _queue.clear();
    notifyListeners();
  }

  /// The signed-in user changed (sign-out, account switch, session
  /// invalidation): drop every feedback created for someone else, including
  /// loading cards, so nothing of the previous user's session survives.
  /// Feedback created for the new state (for example a notice shown right
  /// after signing out) is kept.
  void onUserChanged(String? uid) {
    final stale = <int>[
      if (_current != null && _current!.ownerUid != uid) _current!.id,
      for (final e in _queue)
        if (e.ownerUid != uid) e.id,
    ];
    if (stale.isEmpty) return;
    _queue.removeWhere((e) => e.ownerUid != uid);
    if (_current != null && _current!.ownerUid != uid) {
      _current = _queue.isEmpty ? null : _queue.removeAt(0);
    }
    notifyListeners();
  }
}
