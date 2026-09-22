import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/view/complete_registration_view.dart';
import 'package:ae_coaching/auth/presentation/view/verify_phone_migration_view.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bootstrap gate reached only when Hive says "not logged in" but a
/// Firebase [FirebaseAuth.currentUser] is non-null underneath — i.e. a
/// stray or partially-completed registration session (Phase 3). Runs
/// [AuthCubit.reconcileSession] once and routes to the right place
/// without ever creating a new UID.
class SessionReconciliationView extends StatefulWidget {
  const SessionReconciliationView({super.key});

  @override
  State<SessionReconciliationView> createState() =>
      _SessionReconciliationViewState();
}

class _SessionReconciliationViewState extends State<SessionReconciliationView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthCubit>().reconcileSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffdbe9f7), Color(0xff8fb6e6)],
          ),
        ),
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess) {
              // Phase 4 restart-bypass fix: a completed users/{uid}
              // profile does not by itself mean mandatory phone
              // migration is finished — a legacy account reconciled
              // here can still need it. Check BEFORE writing anything
              // to Hive, so an incomplete migration is never recorded
              // as a fully logged-in session (mirrors LoginView's own
              // ordering for a fresh login).
              if (state.user?.needsPhoneVerification == true) {
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppNavigator.verifyPhoneMigration,
                    (route) => false,
                    arguments: VerifyPhoneMigrationArgs(
                      uid: state.user!.uid,
                      name: state.user!.name,
                      phone: state.user!.phoneNumber,
                    ),
                  );
                }
                return;
              }

              // A completed users/{uid} profile already exists — this is
              // a fully finished registration/login that Hive just
              // hadn't recorded yet. Reconstruct the local session and
              // proceed, silently (no snackbar — this isn't a fresh
              // login the user just performed).
              if (state.user != null) {
                await sl<SessionStorage>().persistLoggedInSession(
                  uid: state.user!.uid,
                  name: state.user!.name,
                  phone: state.user!.phoneNumber,
                );
              }
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppNavigator.home,
                  (route) => false,
                );
              }
            } else if (state is AuthPartialRegistration) {
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppNavigator.completeRegistration,
                  (route) => false,
                  arguments: CompleteRegistrationArgs(
                    step: state.step,
                    phone: state.phone,
                  ),
                );
              }
            } else if (state is AuthInitial || state is AuthError) {
              // Nothing safely resumable — sign out any lingering
              // session (defensive) and send the user to a normal login.
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppNavigator.login,
                  (route) => false,
                );
              }
            }
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xff2f80ed)),
                const SizedBox(height: 16),
                Text(
                  l10n.sessionCheckingMessage,
                  style: const TextStyle(color: Color(0xff7d8792)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
