import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Animated shimmer used in place of content-loading spinners.
///
/// Paints a moving highlight over its [child]'s opaque pixels, so the child
/// should be built from [ShimmerBone]s (or the ready-made skeletons below).
/// Button/action spinners stay as progress indicators on purpose: they report
/// an action in progress, not content on its way.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final base = colors.surfaceRaised;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highlight = Color.lerp(base, Colors.white, dark ? 0.12 : 0.7)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label: AppLocalizations.of(context)?.loadingLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            // Sweep from the reading-start edge to the reading-end edge.
            final t = rtl ? 1 - _controller.value : _controller.value;
            final dx = -1.0 + 3.0 * t;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(dx - 1, -0.3),
                end: Alignment(dx + 1, 0.3),
                colors: [base, highlight, base],
                stops: const [0.25, 0.5, 0.75],
              ).createShader(bounds),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// One solid placeholder shape inside an [AppShimmer].
class ShimmerBone extends StatelessWidget {
  const ShimmerBone({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.circle = false,
  });

  const ShimmerBone.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 0,
      circle = true;

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.appColors.surfaceRaised,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

/// A card-like row: optional leading square, a title and a subtitle line.
class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile({required this.leading, required this.height});
  final bool leading;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.appColors.border),
    ),
    child: Row(
      children: [
        if (leading) ...[
          ShimmerBone(width: height - 28, height: height - 28, radius: 12),
          const SizedBox(width: 14),
        ],
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: 0.65,
                child: ShimmerBone(height: 16),
              ),
              SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: 0.4,
                child: ShimmerBone(height: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Skeleton for a vertical list of cards (programs, history, measurements…).
class ShimmerList extends StatelessWidget {
  const ShimmerList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 84,
    this.leading = true,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
  });

  final int itemCount;
  final double itemHeight;
  final bool leading;
  final EdgeInsetsGeometry padding;

  /// Use inside another scroll view (e.g. a Home section).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView.separated(
      key: const ValueKey('shimmer-list'),
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => _ShimmerTile(leading: leading, height: itemHeight),
    ),
  );
}

/// Skeleton for a photo grid.
class ShimmerGrid extends StatelessWidget {
  const ShimmerGrid({super.key, this.crossAxisCount = 2, this.itemCount = 6});
  final int crossAxisCount;
  final int itemCount;

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: GridView.builder(
      key: const ValueKey('shimmer-grid'),
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => const ShimmerBone(radius: 16, height: null),
    ),
  );
}

/// Skeleton for analytics: a stat row, a chart block and a few lines.
class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(
      key: const ValueKey('shimmer-dashboard'),
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        Row(
          children: [
            Expanded(child: ShimmerBone(height: 72, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: ShimmerBone(height: 72, radius: 16)),
          ],
        ),
        SizedBox(height: 16),
        ShimmerBone(height: 220, radius: 20),
        SizedBox(height: 20),
        FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 0.5,
          child: ShimmerBone(height: 18),
        ),
        SizedBox(height: 12),
        ShimmerBone(height: 64, radius: 16),
        SizedBox(height: 12),
        ShimmerBone(height: 64, radius: 16),
      ],
    ),
  );
}

/// Skeleton for a block of text (licenses, long descriptions).
class ShimmerParagraph extends StatelessWidget {
  const ShimmerParagraph({super.key, this.lines = 8});
  final int lines;

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: Column(
      key: const ValueKey('shimmer-paragraph'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FractionallySizedBox(
              widthFactor: i == lines - 1 ? 0.55 : (i.isEven ? 1 : 0.9),
              child: const ShimmerBone(height: 12),
            ),
          ),
      ],
    ),
  );
}

/// Skeleton for a profile page: avatar + name, then list rows.
class ShimmerProfile extends StatelessWidget {
  const ShimmerProfile({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(
      key: const ValueKey('shimmer-profile'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Row(
          children: [
            ShimmerBone.circle(size: 72),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: ShimmerBone(height: 20),
                  ),
                  SizedBox(height: 10),
                  FractionallySizedBox(
                    widthFactor: 0.4,
                    child: ShimmerBone(height: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const ShimmerBone(height: 120, radius: 20),
        const SizedBox(height: 20),
        for (var i = 0; i < 4; i++) ...[
          const ShimmerBone(height: 52, radius: 14),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

/// Skeleton for the Home dashboard while the account box opens.
class ShimmerHome extends StatelessWidget {
  const ShimmerHome({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AppShimmer(
      child: ListView(
        key: const ValueKey('shimmer-home'),
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.35,
                      child: ShimmerBone(height: 16),
                    ),
                    SizedBox(height: 14),
                    FractionallySizedBox(
                      widthFactor: 0.7,
                      child: ShimmerBone(height: 30),
                    ),
                  ],
                ),
              ),
              ShimmerBone.circle(size: 48),
            ],
          ),
          SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: ShimmerBone(height: 130, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBone(height: 130, radius: 20)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ShimmerBone(height: 130, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBone(height: 130, radius: 20)),
            ],
          ),
          SizedBox(height: 24),
          ShimmerBone(height: 150, radius: 20),
        ],
      ),
    ),
  );
}

/// Skeleton for a single list tile row (e.g. a settings row).
class ShimmerTileRow extends StatelessWidget {
  const ShimmerTileRow({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: AppShimmer(
      child: Row(
        children: [
          ShimmerBone(width: 24, height: 24, radius: 6),
          SizedBox(width: 16),
          Expanded(
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.6,
              child: ShimmerBone(height: 14),
            ),
          ),
        ],
      ),
    ),
  );
}
