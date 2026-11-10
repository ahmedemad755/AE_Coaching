import 'package:ae_coaching/auth/domain/validation/profile_integrity.dart';
import 'package:ae_coaching/auth/presentation/auth_flow_navigation.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_dialogs.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/core/theme/auth_screen_theme.dart';
import 'package:ae_coaching/core/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Startup session check (`StartupDestination.sessionCheck`). Reached
/// when Firebase Auth holds an identity that local state can't vouch
/// for. Runs [AuthCubit.resolveEmailSession] (server reload +
/// `users/{uid}`) and routes by the resulting `AuthStatus`:
///
/// - authenticated            → persist the local marker, then Home
/// - pendingEmailVerification → Verify Email (no email is auto-sent)
/// - incompleteProfile        → Complete Profile (name only)
/// - unsupportedLegacyAccount → signed out (nothing deleted), then Login
///                              with an explanation
/// - unauthenticated / dead session → Login
///
/// A failed check (offline, Firestore unavailable) is NOT treated as
/// signed out: the user gets Retry and Sign out. Never creates an
/// account or a new UID.
class SessionReconciliationView extends StatefulWidget {
  const SessionReconciliationView({super.key});

  @override
  State<SessionReconciliationView> createState() =>
      _SessionReconciliationViewState();
}

class _SessionReconciliationViewState extends State<SessionReconciliationView> {
  bool _checkFailed = false;

  /// Set when the profile, not the session, is the problem.
  ProfileFailure? _profileFailure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted) return;
    setState(() {
      _checkFailed = false;
      _profileFailure = null;
    });
    context.read<AuthCubit>().resolveEmailSession();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: AuthScreenTheme.background(context),
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess && state.user != null) {
              // Verified account with a profile that the local marker
              // didn't cover yet. Rebuild the marker and continue
              // silently.
              await AuthFlowNavigation.enterApp(context, state.user!);
            } else if (state is AuthEmailVerificationRequired) {
              AuthFlowNavigation.toVerifyEmail(context, state.email);
            } else if (state is AuthProfileIncomplete) {
              AuthFlowNavigation.toCompleteProfile(context, state.email);
            } else if (state is AuthLegacyAccountSignedOut) {
              AuthFlowNavigation.toLogin(
                context,
                notice: l10n.legacyAccountSignedOutMessage,
              );
            } else if (state is AuthSignedOut) {
              AuthFlowNavigation.toLogin(context);
            } else if (state is AuthProfileUnavailable) {
              setState(() {
                _checkFailed = true;
                _profileFailure = state.failure;
              });
            } else if (state is AuthError) {
              setState(() => _checkFailed = true);
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            if (_checkFailed && !isLoading) {
              return _CheckFailedPanel(
                l10n: l10n,
                profileFailure: _profileFailure,
                onRetry: _check,
                onSignOut: () => context.read<AuthCubit>().signOut(),
              );
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 220, child: ShimmerParagraph(lines: 3)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.sessionCheckingMessage,
                    style: TextStyle(color: context.authMuted),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CheckFailedPanel extends StatelessWidget {
  final AppLocalizations l10n;
  final ProfileFailure? profileFailure;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _CheckFailedPanel({
    required this.l10n,
    this.profileFailure,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              decoration: BoxDecoration(
                color: AuthScreenTheme.panelColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.cloud_off, color: context.authBlue, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    profileFailure == null
                        ? l10n.sessionCheckFailedTitle
                        : l10n.accountSetupFailedTitle,
                    key: const Key('session_check_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.authDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    switch (profileFailure) {
                      null ||
                      ProfileFailure.network => l10n.sessionCheckFailedBody,
                      ProfileFailure.permissionDenied =>
                        l10n.profilePermissionDeniedBody,
                      ProfileFailure.conflicting => l10n.profileConflictingBody,
                      ProfileFailure.unknown => l10n.profileUnknownFailureBody,
                    },
                    key: const Key('session_check_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.authMuted),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    key: const Key('session_check_retry'),
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(l10n.retry),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('session_check_sign_out'),
                    onPressed: onSignOut,
                    child: Text(
                      l10n.signOutButton,
                      style: TextStyle(color: context.authMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
