import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/presentation/profile_avatar.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class HomeWelcomeSection extends StatelessWidget {
  const HomeWelcomeSection({
    super.key,
    required this.name,
    this.photoPath,
    this.onProfileTap,
    this.onImageError,
  });

  final String name;
  final String? photoPath;
  final VoidCallback? onProfileTap;
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(
                name: name,
                photoPath: photoPath,
                semanticLabel: l10n.personalHubTitle,
                size: 48,
                showActionBadge: false,
                onTap: onProfileTap,
                onImageError: onImageError,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final direction = Directionality.of(context);
                    final locale = Localizations.maybeLocaleOf(context);
                    final textScaler = MediaQuery.textScalerOf(context);
                    var fontSize = 24.0;
                    while (fontSize > 8) {
                      final painter = TextPainter(
                        text: TextSpan(
                          text: name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        textDirection: direction,
                        locale: locale,
                        textScaler: textScaler,
                        maxLines: 2,
                      )..layout(maxWidth: constraints.maxWidth);
                      if (!painter.didExceedMaxLines) break;
                      fontSize -= 1;
                    }

                    return Text(
                      name,
                      key: const ValueKey('home-user-name'),
                      maxLines: 2,
                      softWrap: true,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homeGreetingSubtitle,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
