import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// What the user wants to add to a workout day. Timed exercises join with
/// their settings screen (a later stage); until then they are not offered.
enum AddActivityChoice { strength, cardio, myLibrary }

/// The "Add activity" bottom sheet (design screen 2).
Future<AddActivityChoice?> showAddActivitySheet(BuildContext context) =>
    showModalBottomSheet<AddActivityChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddActivitySheet(),
    );

class AddActivitySheet extends StatelessWidget {
  const AddActivitySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.addActivityTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _ActivityOption(
            key: const ValueKey('add-activity-strength'),
            icon: Icons.fitness_center,
            title: l10n.addActivityStrengthTitle,
            body: l10n.addActivityStrengthBody,
            choice: AddActivityChoice.strength,
          ),
          const SizedBox(height: 10),
          _ActivityOption(
            key: const ValueKey('add-activity-cardio'),
            icon: Icons.directions_run,
            title: l10n.addActivityCardioTitle,
            body: l10n.addActivityCardioBody,
            choice: AddActivityChoice.cardio,
          ),
          const SizedBox(height: 10),
          _ActivityOption(
            key: const ValueKey('add-activity-library'),
            icon: Icons.bookmarks_outlined,
            title: l10n.addActivityLibraryTitle,
            body: l10n.addActivityLibraryBody,
            choice: AddActivityChoice.myLibrary,
          ),
        ],
      ),
    );
  }
}

class _ActivityOption extends StatelessWidget {
  const _ActivityOption({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.choice,
  });

  final IconData icon;
  final String title;
  final String body;
  final AddActivityChoice choice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final primary = theme.colorScheme.primary;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: colors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, choice),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  rtl ? Icons.chevron_left : Icons.chevron_right,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
