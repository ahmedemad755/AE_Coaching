import 'package:ae_coaching/core/feedback/feedback_models.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Visual identity of one feedback type: icon, accent colour, and the
/// accessibility prefix ("Error: …").
class FeedbackStyle {
  const FeedbackStyle({
    required this.icon,
    required this.accent,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String label;

  static FeedbackStyle of(BuildContext context, FeedbackType type) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      FeedbackType.success => FeedbackStyle(
        icon: Icons.check_circle_rounded,
        accent: colors.success,
        label: l10n?.feedbackSuccessLabel ?? 'Success',
      ),
      FeedbackType.error => FeedbackStyle(
        icon: Icons.error_rounded,
        accent: colors.error,
        label: l10n?.feedbackErrorLabel ?? 'Error',
      ),
      FeedbackType.warning => FeedbackStyle(
        icon: Icons.warning_amber_rounded,
        accent: colors.warning,
        label: l10n?.feedbackWarningLabel ?? 'Warning',
      ),
      FeedbackType.info => FeedbackStyle(
        icon: Icons.info_rounded,
        accent: scheme.primary,
        label: l10n?.feedbackInfoLabel ?? 'Information',
      ),
      FeedbackType.emailVerification => FeedbackStyle(
        icon: Icons.mark_email_read_rounded,
        accent: scheme.primary,
        label: l10n?.feedbackInfoLabel ?? 'Information',
      ),
      FeedbackType.loading => FeedbackStyle(
        icon: Icons.hourglass_top_rounded,
        accent: scheme.primary,
        label: l10n?.feedbackLoadingLabel ?? 'In progress',
      ),
    };
  }
}

/// A floating, theme-aware feedback card. Stateless: the host owns the
/// single entrance/exit and countdown animations, so a card never creates
/// its own animation controllers.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.entry,
    required this.countdown,
    required this.onDismiss,
  });

  static const radius = 20.0;
  static const maxWidth = 560.0;

  final FeedbackEntry entry;

  /// 0 → 1 over the auto-dismiss duration; drives the opt-in countdown bar.
  final Animation<double> countdown;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final style = FeedbackStyle.of(context, entry.type);
    final l10n = AppLocalizations.of(context);
    final message = entry.message;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceRaised : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.border.withValues(alpha: isDark ? 0.9 : 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Badge(entry: entry, style: style),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            key: const ValueKey('feedback-title'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          if (message != null && message.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              message,
                              key: const ValueKey('feedback-message'),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (entry.action != null)
                      TextButton(
                        key: const ValueKey('feedback-action'),
                        style: TextButton.styleFrom(
                          foregroundColor: style.accent,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          entry.action!.onPressed();
                          onDismiss();
                        },
                        child: Text(entry.action!.label),
                      ),
                    if (entry.dismissible)
                      // Its own node, so screen readers can focus and
                      // activate Dismiss separately from the message.
                      Semantics(
                        container: true,
                        button: true,
                        label: l10n?.feedbackDismiss ?? 'Dismiss',
                        excludeSemantics: true,
                        child: InkResponse(
                          key: const ValueKey('feedback-dismiss'),
                          onTap: onDismiss,
                          radius: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
              _ProgressBar(entry: entry, countdown: countdown, style: style),
            ],
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Semantics(container: true, label: style.label, child: card),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.entry, required this.style});

  final FeedbackEntry entry;
  final FeedbackStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: entry.isLoading
          ? SizedBox(
              key: const ValueKey('feedback-spinner'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: style.accent,
              ),
            )
          : Icon(
              style.icon,
              key: ValueKey('feedback-icon-${entry.type.name}'),
              size: 21,
              color: style.accent,
            ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.entry,
    required this.countdown,
    required this.style,
  });

  final FeedbackEntry entry;
  final Animation<double> countdown;
  final FeedbackStyle style;

  @override
  Widget build(BuildContext context) {
    final track = style.accent.withValues(alpha: 0.12);
    final fill = style.accent.withValues(alpha: 0.6);
    if (entry.isLoading) {
      final progress = entry.progress;
      if (progress == null) return const SizedBox.shrink();
      return LinearProgressIndicator(
        key: const ValueKey('feedback-progress'),
        value: progress,
        minHeight: 3,
        backgroundColor: track,
        color: fill,
      );
    }
    if (!entry.showCountdown || entry.duration == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      key: const ValueKey('feedback-countdown'),
      height: 2.5,
      child: AnimatedBuilder(
        animation: countdown,
        builder: (context, _) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: (1 - countdown.value).clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: fill),
          ),
        ),
      ),
    );
  }
}
