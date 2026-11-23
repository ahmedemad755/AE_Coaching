import 'dart:async';

import 'package:flutter/foundation.dart';

/// Keeps a kept-alive screen (for example a persistent Home tab) fresh
/// without reloading it on every navigation.
///
/// It reloads only after one of the [watch]ed change sources actually
/// emitted (typically `box.watch()` of exactly the per-user Hive boxes the
/// screen reads), and only while the screen is visible, or as soon as it
/// becomes visible again. Visibility is normally
/// `TickerMode.getNotifier(context)`: it is false for an inactive tab and
/// for a route covered by another route.
///
/// Changes are debounced: a burst of writes (for example finishing a
/// workout writes the session and every set) becomes one reload once the
/// burst is quiet for [debounce]. Reloads never overlap; changes that land
/// during a reload schedule one more after it. All work runs from a timer,
/// so a visibility change reported during a build never mutates state
/// mid-build.
class VisibleDataRefresher {
  VisibleDataRefresher({
    required Future<void> Function() reload,
    this.debounce = const Duration(milliseconds: 150),
  }) : _reload = reload;

  final Future<void> Function() _reload;

  /// Quiet period after the last change before reloading.
  final Duration debounce;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  ValueListenable<bool>? _visibility;
  Timer? _timer;
  bool _dirty = false;
  bool _running = false;
  bool _disposed = false;

  /// Whether a change is waiting to be reloaded (for example until the
  /// screen becomes visible).
  bool get isDirty => _dirty;

  bool get _visible => _visibility?.value ?? true;

  /// Replaces the watched change sources (an empty list stops watching).
  void watch(Iterable<Stream<Object?>> sources) {
    if (_disposed) return;
    _cancelSubscriptions();
    for (final source in sources) {
      _subscriptions.add(
        source.listen((_) => _onChanged(), onError: (Object _) {}),
      );
    }
  }

  /// Follows [visibility]. Safe to call from `didChangeDependencies` on
  /// every dependency change: the same listenable is attached only once.
  void attachVisibility(ValueListenable<bool> visibility) {
    if (_disposed || identical(visibility, _visibility)) return;
    _visibility?.removeListener(_onVisibilityChanged);
    _visibility = visibility..addListener(_onVisibilityChanged);
    _onVisibilityChanged();
  }

  /// A load that reads the current data has just started elsewhere (for
  /// example a mutation-driven reload of the same Cubit), so changes seen
  /// so far are already covered by it.
  void markClean() {
    _dirty = false;
    _timer?.cancel();
  }

  /// Drops pending changes and stops watching (for example when the
  /// signed-in user changes, before watching the new user's data).
  void reset() {
    _cancelSubscriptions();
    _timer?.cancel();
    _dirty = false;
  }

  void _onChanged() {
    if (_disposed) return;
    _dirty = true;
    // While hidden, just remember the change; showing the screen reloads.
    if (_visible) _schedule(debounce);
  }

  void _onVisibilityChanged() {
    if (_visible && _dirty) _schedule(Duration.zero);
  }

  void _schedule(Duration delay) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_disposed || !_visible || !_dirty) return;
      // A reload in progress picks this up when it finishes.
      if (!_running) unawaited(_run());
    });
  }

  Future<void> _run() async {
    _running = true;
    _dirty = false;
    try {
      await _reload();
    } catch (error, stackTrace) {
      // The screen's own loading/error state reports failures; this only
      // keeps a failed refresh from breaking future refreshes.
      debugPrint('Visible data refresh failed: $error\n$stackTrace');
    } finally {
      _running = false;
    }
    // Changes that landed during the reload are not in it yet.
    if (_dirty && _visible && !_disposed) _schedule(debounce);
  }

  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _visibility?.removeListener(_onVisibilityChanged);
    _visibility = null;
    _cancelSubscriptions();
  }
}
