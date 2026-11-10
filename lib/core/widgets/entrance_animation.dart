import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Entrance motion used across Home, programs, templates and exercise lists:
/// the widget fades in while sliding up a little. Lists stagger their items.
///
/// ```dart
/// MyCard().animateIn();                 // single widget
/// item.animateIn(index: index);         // inside an itemBuilder
/// ListView(children: [...].staggered()) // a whole children list
/// ```
///
/// Implemented with a single [AnimationController] (the delay is an
/// [Interval], not a timer), so it never leaves timers pending in tests and
/// it is skipped entirely when the system asks to reduce motion.
abstract final class EntranceMotion {
  /// Gap between consecutive list items (kept within 50–80 ms).
  static const stagger = Duration(milliseconds: 65);
  static const duration = Duration(milliseconds: 420);

  /// Only the first items of a list wait their turn and animate; from this
  /// index on, items are shown immediately with no animation.
  static const maxStaggeredItems = 8;

  /// How far (in logical pixels) the widget travels while it slides up.
  static const slideDistance = 24.0;
}

class EntranceAnimation extends StatefulWidget {
  const EntranceAnimation({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// Position in a list; adds `index × EntranceMotion.stagger` of delay.
  final int index;

  /// Extra delay before the stagger starts.
  final Duration delay;

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final wait = widget.delay + EntranceMotion.stagger * widget.index;
    final total = wait + EntranceMotion.duration;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    _progress = CurvedAnimation(
      parent: controller,
      curve: Interval(
        wait.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
    if ((MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        NoEntranceAnimation.of(context)) {
      controller.value = 1;
    } else {
      controller.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) {
      final t = _progress.value;
      if (t == 1) return child!;
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * EntranceMotion.slideDistance),
          child: child,
        ),
      );
    },
  );
}

extension EntranceAnimationX on Widget {
  /// Fade in + slide up. Pass [index] inside lists to stagger the items.
  ///
  /// A keyed child gives the wrapper a derived key, so keyed lists (including
  /// ReorderableListView, which needs keyed items) keep matching state by key.
  Widget animateIn({Key? key, int index = 0, Duration delay = Duration.zero}) {
    if (index >= EntranceMotion.maxStaggeredItems) return this;
    final own = this.key;
    return EntranceAnimation(
      key: key ?? (own is LocalKey ? ValueKey(('entrance', own)) : null),
      index: index,
      delay: delay,
      child: this,
    );
  }
}

extension StaggeredEntranceX on List<Widget> {
  /// Staggers every widget of a `children:` list. Spacers are left alone and
  /// don't consume a stagger slot.
  List<Widget> staggered({Duration delay = Duration.zero}) {
    var slot = 0;
    return [
      for (final child in this)
        if (child is SizedBox && child.child == null)
          child
        else
          child.animateIn(index: slot++, delay: delay),
    ];
  }
}

/// Shows descendants in their final state without entrance motion.
///
/// Used for ReorderableListView drag proxies: the dragged copy is a fresh
/// build of the item and must not fade in again while it is being dragged.
class NoEntranceAnimation extends InheritedWidget {
  const NoEntranceAnimation({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NoEntranceAnimation>() != null;

  @override
  bool updateShouldNotify(NoEntranceAnimation oldWidget) => false;
}

/// Drop-in `proxyDecorator` for ReorderableListView: the default lift
/// (elevation 0 → 6) without replaying entrance animations on the proxy.
Widget entranceSafeProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) => NoEntranceAnimation(
  child: AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Material(
      elevation: lerpDouble(0, 6, Curves.easeInOut.transform(animation.value))!,
      color: Colors.transparent,
      shadowColor: Colors.black54,
      child: child,
    ),
  ),
);

/// Wraps a list `itemBuilder` so every item fades + slides in, staggered.
IndexedWidgetBuilder staggeredItemBuilder(IndexedWidgetBuilder builder) =>
    (context, index) => builder(context, index).animateIn(index: index);
