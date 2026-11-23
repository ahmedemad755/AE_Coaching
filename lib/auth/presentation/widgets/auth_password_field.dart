import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Password input shared by every auth screen. It handles the
/// visibility toggle with an accessible, localized tooltip, keeps the
/// keyboard from learning or suggesting the password, and sets autofill
/// hints. The value is never trimmed or otherwise altered here.
class AuthPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final FocusNode? focusNode;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final Key? toggleKey;

  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.decoration,
    this.focusNode,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.fieldKey,
    this.toggleKey,
  });

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: widget.decoration.copyWith(
        errorMaxLines: 3,
        suffixIcon: IconButton(
          key: widget.toggleKey,
          tooltip: _obscured
              ? l10n.showPasswordTooltip
              : l10n.hidePasswordTooltip,
          icon: Icon(
            _obscured ? Icons.visibility_off : Icons.visibility,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
