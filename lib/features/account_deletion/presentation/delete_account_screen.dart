import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/account_deletion/presentation/cubit/account_deletion_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Explains the consequences, re-authenticates with the password, asks for
/// an explicit confirmation, then deletes the account immediately.
///
/// Layout: the explanation and the form scroll; the destructive button sits
/// in a pinned bottom bar that stays above the system navigation bar (or
/// gesture area) and rises with the keyboard, so it is never hidden.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const _gutter = 20.0;

  final _password = TextEditingController();
  bool _understood = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool _canSubmit(AccountDeletionState state) => !state.submitting && _understood && _password.text.isNotEmpty;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    final loading = AppFeedback.loading(l10n.deleteAccountSubmitting);
    final outcome = await context.read<AccountDeletionCubit>().deleteAccount(_password.text);
    switch (outcome) {
      case AccountDeletionOutcome.deleted:
        loading.success(l10n.accountDeletedNotice);
      case AccountDeletionOutcome.wrongPassword:
        loading.error(l10n.deleteAccountWrongPassword);
      case AccountDeletionOutcome.tooManyAttempts:
        loading.error(l10n.deleteAccountTooManyAttempts);
      case AccountDeletionOutcome.offline:
        loading.error(l10n.deleteAccountOffline);
      case AccountDeletionOutcome.recentSignInRequired:
        loading.error(l10n.deleteAccountReauthRequired);
      case AccountDeletionOutcome.unsupportedSignIn:
        loading.error(l10n.deleteAccountUnsupported);
      case AccountDeletionOutcome.failed:
        loading.error(l10n.deleteAccountFailed);
      case AccountDeletionOutcome.busy:
        loading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<AccountDeletionCubit, AccountDeletionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status && current.status == AccountDeletionStatus.accountDeleted,
      listener: (context, state) => Navigator.of(context).pushNamedAndRemoveUntil(AppNavigator.login, (route) => false),
      builder: (context, state) => Scaffold(
        backgroundColor: context.appColors.canvas,
        appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
        body: switch (state.status) {
          AccountDeletionStatus.loading ||
          AccountDeletionStatus.accountDeleted => const Center(child: CircularProgressIndicator()),
          AccountDeletionStatus.unavailable => SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.deleteAccountReauthRequired, textAlign: TextAlign.center),
              ),
            ),
          ),
          AccountDeletionStatus.ready => _form(context, state, l10n),
        },
        bottomNavigationBar: state.status == AccountDeletionStatus.ready
            ? _ActionBar(
                submitting: state.submitting,
                label: l10n.deleteAccountSubmit,
                onPressed: _canSubmit(state) ? _submit : null,
              )
            : null,
      ),
    );
  }

  Widget _form(BuildContext context, AccountDeletionState state, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final error = theme.colorScheme.error;
    // Side insets cover landscape cut-outs; the bottom is handled by the
    // pinned action bar (the Scaffold removes it from the body).
    final insets = MediaQuery.paddingOf(context);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(_gutter + insets.left, 16, _gutter + insets.right, 24),
      children: [
        if (state.incomplete) ...[
          Container(
            key: const ValueKey('delete-account-incomplete'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.warning.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: colors.warning),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.deleteAccountIncomplete, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: error.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.warning_amber_rounded, color: error, size: 34),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.deleteAccountIntro,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              for (final item in [
                l10n.deleteAccountItemWorkouts,
                l10n.deleteAccountItemMeasurements,
                l10n.deleteAccountItemProfile,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.remove_circle_outline, color: error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.deleteAccountIrreversible, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted)),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('delete-account-password'),
          controller: _password,
          obscureText: _obscure,
          enabled: !state.submitting,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          // Keep the field clear of the pinned bar when the keyboard opens.
          scrollPadding: const EdgeInsets.only(bottom: 140),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_canSubmit(state)) _submit();
          },
          decoration: InputDecoration(
            labelText: l10n.deleteAccountPasswordLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const ValueKey('delete-account-confirm'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _understood,
          onChanged: state.submitting ? null : (value) => setState(() => _understood = value ?? false),
          title: Text(l10n.deleteAccountConfirmCheckbox, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// The pinned destructive action: above the keyboard when it is open,
/// otherwise above the system navigation bar / gesture area.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.submitting, required this.label, required this.onPressed});

  final bool submitting;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final error = theme.colorScheme.error;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.canvas,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          // Breathing room even on devices without a navigation bar inset.
          minimum: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _DeleteAccountScreenState._gutter,
              12,
              _DeleteAccountScreenState._gutter,
              0,
            ),
            child: FilledButton.icon(
              key: const ValueKey('delete-account-submit'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: onPressed,
              icon: submitting
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onError),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
