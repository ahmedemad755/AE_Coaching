import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/auth/presentation/auth_flow_navigation.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_dialogs.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Missing-profile recovery (status `AuthStatus.incompleteProfile`): the
/// account is verified, but `users/{uid}` was never written and no name
/// could be recovered automatically. Saving creates the profile
/// (create-only), and nothing existing is ever overwritten.
class CompleteProfileView extends StatefulWidget {
  final String email;
  const CompleteProfileView({super.key, required this.email});

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (context.read<AuthCubit>().state is AuthLoading) return;
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().completeEmailProfile(name: _nameController.text);
  }

  Future<void> _confirmSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    if (context.read<AuthCubit>().state is AuthLoading) return;
    if (await confirmAuthSignOut(context, l10n.leaveEmailVerificationBody) &&
        mounted) {
      context.read<AuthCubit>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmSignOut();
      },
      child: Scaffold(
        body: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess && state.user != null) {
              await AuthFlowNavigation.enterApp(
                context,
                state.user!,
                message: state.message,
              );
            } else if (state is AuthProfileUnavailable) {
              AuthFlowNavigation.toAccountCheck(context);
            } else if (state is AuthEmailVerificationRequired) {
              AuthFlowNavigation.toVerifyEmail(context, state.email);
            } else if (state is AuthSignedOut) {
              AuthFlowNavigation.toLogin(context);
            } else if (state is AuthError) {
              showAuthSnackBar(context, state.message, isError: true);
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return AuthCardScaffold(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTitle(
                      title: l10n.completeRegistrationFinishProfileTitle,
                      subtitle: l10n.completeRegistrationFinishProfileSubtitle,
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      key: const Key('complete_profile_name_field'),
                      controller: _nameController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.name],
                      onFieldSubmitted: (_) => _save(),
                      decoration: authFieldDecoration(
                        context,
                        hint: l10n.fullNameHint,
                        icon: Icons.person,
                      ),
                      validator: (value) => localizeNameError(
                        l10n,
                        AuthInputRules.validateName(value ?? ''),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AuthPrimaryButton(
                      key: const Key('complete_profile_save_button'),
                      label: l10n.save,
                      loading: isLoading,
                      onPressed: _save,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isLoading ? null : _confirmSignOut,
                      child: Text(
                        l10n.signOutUseAnotherAccount,
                        style: TextStyle(color: context.authMuted),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
