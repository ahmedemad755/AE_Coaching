import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/presentation/profile_avatar.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Home-specific surfaces built from the app's existing semantic colors.
abstract final class HomeDashboardStyle {
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xff071321)
      : context.appColors.canvas;

  static BoxDecoration card(BuildContext context, {bool emphasized = false}) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: emphasized ? scheme.primary : colors.border,
        width: emphasized ? 2 : 1,
      ),
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: emphasized
            ? [
                Color.alphaBlend(
                  (Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.brandBlue
                          : scheme.primary)
                      .withValues(alpha: 0.34),
                  scheme.surface,
                ),
                Color.alphaBlend(
                  AppTheme.brandBlue.withValues(alpha: 0.14),
                  scheme.surface,
                ),
              ]
            : [colors.surfaceRaised, scheme.surface],
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.onProfile,
    required this.onSettings,
    this.photoPath,
    this.onImageError,
  });

  final String name;
  final String? photoPath;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback? onImageError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.homeGreetingMorning
        : hour < 18
        ? l10n.homeGreetingAfternoon
        : l10n.homeGreetingEvening;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'AE',
                      style: TextStyle(
                        fontSize: 29,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(text: ' Coaching'),
                  ],
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: onSettings,
              tooltip: l10n.appSettingsTitle,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 4),
            ProfileAvatar(
              name: name,
              photoPath: photoPath,
              semanticLabel: l10n.personalHubTitle,
              size: 48,
              showActionBadge: false,
              onTap: onProfile,
              onImageError: onImageError,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        if (name.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            name,
            key: const ValueKey('home-user-name'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.homeDashboardSubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class HomeNavigationCard extends StatelessWidget {
  const HomeNavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  TextStyle? _titleStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

  TextStyle? _subtitleStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: context.appColors.textMuted);

  /// Both grid rows share a height that fits the current locale and scale.
  double heightForWidth(BuildContext context, double width) {
    final border = emphasized ? 4.0 : 2.0;
    double textHeight(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
      )..layout(maxWidth: width - 32 - border);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // Ink also reserves the decoration's border in addition to card padding.
    return 86 +
        border +
        textHeight(title, _titleStyle(context)) +
        textHeight(subtitle, _subtitleStyle(context));
  }

  @override
  Widget build(BuildContext context) => _HomeCardSurface(
    emphasized: emphasized,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: context.appColors.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: _titleStyle(context)),
          const SizedBox(height: 6),
          Text(subtitle, style: _subtitleStyle(context)),
        ],
      ),
    ),
  );
}

class HomeQuickActionCard extends StatelessWidget {
  const HomeQuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _HomeCardSurface(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class ActiveProgramCard extends StatelessWidget {
  const ActiveProgramCard({
    super.key,
    required this.program,
    this.sessionsCompletedThisWeek,
    required this.onTap,
  });
  final WorkoutProgram program;
  final int? sessionsCompletedThisWeek;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    return _HomeCardSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.fitness_center, color: primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (sessionsCompletedThisWeek != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.homeWorkoutsCompletedThisWeekLabel(
                        sessionsCompletedThisWeek!,
                      ),
                      style: TextStyle(color: context.appColors.textMuted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n.activeProgramLabel,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _HomeCardSurface extends StatelessWidget {
  const _HomeCardSurface({
    required this.child,
    required this.onTap,
    this.emphasized = false,
  });
  final Widget child;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: HomeDashboardStyle.card(context, emphasized: emphasized),
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}
