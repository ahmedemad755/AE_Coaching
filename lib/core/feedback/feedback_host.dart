import 'dart:async';

import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/feedback/feedback_card.dart';
import 'package:ae_coaching/core/feedback/feedback_controller.dart';
import 'package:ae_coaching/core/feedback/feedback_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Root-level host for transient feedback. Install it once, in
/// `MaterialApp.builder`, so it sits above the Navigator: cards stay above
/// every route, dialog and bottom sheet, survive navigation, and are never
/// covered by a route pushed later.
///
/// - One card at a time, near the top: below the status bar and the
///   toolbar row, so Back and app-bar actions stay reachable. Touches
///   outside the card go straight to the app (nothing else is hit-testable).
/// - Exactly two animation controllers for the whole app (entrance/exit,
///   and the optional visible countdown bar), never one per notification,
///   and the app subtree is never rebuilt by feedback changes.
/// - Auto-dismiss runs on a timer, not on frames: nothing repaints while a
///   message is simply on screen (unless it opts into the countdown bar).
/// - Reduced motion: no entrance/exit motion; timing is unchanged.
/// - Auto-dismiss pauses while the app is in the background and resumes
///   with the remaining time.
/// - When the signed-in user changes, feedback created for another user
///   (including loading) is dropped.
class AppFeedbackHost extends StatefulWidget {
  const AppFeedbackHost({
    super.key,
    required this.child,
    this.controller,
    this.currentUser,
    this.userChanges,
  });

  /// Convenience for `MaterialApp(builder: AppFeedbackHost.builder)`.
  static Widget builder(BuildContext context, Widget? child) =>
      AppFeedbackHost(child: child ?? const SizedBox.shrink());

  final Widget child;

  /// Defaults to a controller owned by this host.
  final AppFeedbackController? controller;

  /// The signed-in user's id, recorded on each feedback entry.
  final String? Function()? currentUser;

  /// Emits the signed-in user's id (`null` when signed out). Read once.
  final Stream<String?>? userChanges;

  static const enterDuration = Duration(milliseconds: 300);
  static const exitDuration = Duration(milliseconds: 200);

  /// Gap between the top safe area and the card: one toolbar row plus a
  /// small margin, so app-bar controls stay reachable while a card shows.
  static const toolbarClearance = kToolbarHeight + 6;

  @override
  State<AppFeedbackHost> createState() => _AppFeedbackHostState();
}

class _AppFeedbackHostState extends State<AppFeedbackHost>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AppFeedbackController _controller =
      widget.controller ??
      AppFeedbackController(currentUser: widget.currentUser);

  // Created eagerly in initState: a lazily created controller would be first
  // touched in dispose() when no feedback was ever shown, and creating a
  // ticker on a deactivated element throws.
  late final AnimationController _presence;
  late final CurvedAnimation _presenceCurve;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  // Only drives the opt-in countdown bar. `preserve` keeps it in step with
  // the real timer even when the platform asks to reduce animations.
  late final AnimationController _countdown;

  // Auto-dismiss: a timer for the remaining time, paused in the background.
  Timer? _dismissTimer;
  final Stopwatch _runningFor = Stopwatch();
  Duration _remaining = Duration.zero;

  StreamSubscription<String?>? _userSubscription;
  FeedbackEntry? _shown;
  bool _exiting = false;
  bool _appActive = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _presence = AnimationController(
      vsync: this,
      duration: AppFeedbackHost.enterDuration,
      reverseDuration: AppFeedbackHost.exitDuration,
    );
    _presenceCurve = CurvedAnimation(
      parent: _presence,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(_presenceCurve);
    _scale = Tween<double>(begin: 0.96, end: 1).animate(_presenceCurve);
    _countdown = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    AppFeedback.attachHost(_controller);
    _controller.addListener(_sync);
    WidgetsBinding.instance.addObserver(this);
    _userSubscription = widget.userChanges?.listen(_controller.onUserChanged);
    final initial = _controller.current;
    if (initial != null) {
      _shown = initial;
      _presence.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shown?.id == initial.id) {
          _announce(initial);
          _restartCountdown(initial);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    active ? _resumeDismissTimer() : _pauseDismissTimer();
  }

  void _sync() {
    if (!mounted) return;
    final target = _controller.current;
    final shown = _shown;
    if (shown != null && target != null && target.id == shown.id) {
      if (target.revision != shown.revision) {
        final resolved = target.type != shown.type;
        setState(() => _shown = target);
        if (resolved) _announce(target);
        _restartCountdown(target);
      }
      return;
    }
    if (_exiting) return; // the running exit shows the latest target next
    if (shown == null) {
      _enter(target);
      return;
    }
    _exiting = true;
    _pauseDismissTimer();
    if (_reduceMotion) {
      _presence.value = 0;
      _afterExit();
    } else {
      _presence.reverse().whenCompleteOrCancel(_afterExit);
    }
  }

  void _afterExit() {
    if (!mounted) return;
    _exiting = false;
    setState(() => _shown = null);
    _enter(_controller.current);
  }

  void _enter(FeedbackEntry? target) {
    if (target == null) return;
    setState(() => _shown = target);
    if (_reduceMotion) {
      _presence.value = 1;
    } else {
      _presence.forward(from: 0);
    }
    _announce(target);
    _restartCountdown(target);
  }

  void _restartCountdown(FeedbackEntry entry) {
    _pauseDismissTimer();
    _countdown.value = 0;
    final duration = entry.duration;
    if (duration == null) return; // loading: stays until resolved
    _remaining = duration;
    _countdown.duration = duration;
    if (_appActive) _resumeDismissTimer();
  }

  void _resumeDismissTimer() {
    final shown = _shown;
    if (shown == null ||
        shown.duration == null ||
        _exiting ||
        _dismissTimer != null) {
      return;
    }
    _runningFor
      ..reset()
      ..start();
    _dismissTimer = Timer(_remaining, () {
      _dismissTimer = null;
      if (mounted && !_exiting && _shown?.id == shown.id) {
        _controller.dismiss(shown.id);
      }
    });
    if (shown.showCountdown) _countdown.forward();
  }

  void _pauseDismissTimer() {
    final timer = _dismissTimer;
    if (timer != null) {
      timer.cancel();
      _dismissTimer = null;
      _remaining -= _runningFor.elapsed;
      if (_remaining.isNegative) _remaining = Duration.zero;
    }
    _runningFor.stop();
    _countdown.stop();
  }

  void _announce(FeedbackEntry entry) {
    final label = FeedbackStyle.of(context, entry.type).label;
    final message = entry.message;
    final text = message == null || message.isEmpty
        ? '$label: ${entry.title}'
        : '$label: ${entry.title}. $message';
    unawaited(SemanticsService.announce(text, Directionality.of(context)));
  }

  /// A swipe removes the card at once (no exit animation), as Dismissible
  /// requires the dismissed widget to leave the tree immediately.
  void _onSwiped(FeedbackEntry entry) {
    _pauseDismissTimer();
    _presence.value = 0;
    setState(() => _shown = null);
    _controller.dismiss(entry.id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userSubscription?.cancel();
    _dismissTimer?.cancel();
    _controller.removeListener(_sync);
    AppFeedback.detachHost(_controller);
    if (widget.controller == null) _controller.dispose();
    _presenceCurve.dispose();
    _presence.dispose();
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (shown != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              // Below the status bar AND the toolbar row, so the card never
              // covers a screen's Back button or app-bar actions.
              padding: EdgeInsetsDirectional.only(
                top:
                    MediaQuery.paddingOf(context).top +
                    AppFeedbackHost.toolbarClearance,
                start: 12 + MediaQuery.paddingOf(context).left,
                end: 12 + MediaQuery.paddingOf(context).right,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  opacity: _presenceCurve,
                  child: SlideTransition(
                    position: _slide,
                    child: ScaleTransition(
                      scale: _scale,
                      alignment: Alignment.topCenter,
                      child: _swipeable(shown),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _swipeable(FeedbackEntry entry) {
    final card = FeedbackCard(
      key: ValueKey('feedback-card-${entry.id}'),
      entry: entry,
      countdown: _countdown,
      onDismiss: () => _controller.dismiss(entry.id),
    );
    if (!entry.dismissible) return card;
    return Dismissible(
      key: ValueKey('feedback-swipe-${entry.id}'),
      direction: DismissDirection.horizontal,
      resizeDuration: null,
      onDismissed: (_) => _onSwiped(entry),
      child: card,
    );
  }
}
