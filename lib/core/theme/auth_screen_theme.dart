import 'package:flutter/material.dart';

abstract final class AuthScreenTheme {
  static BoxDecoration background(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [scheme.surface, scheme.surfaceContainerHighest]
            : const [Color(0xffdbe9f7), Color(0xff8fb6e6)],
      ),
    );
  }

  static Color panelColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.98 : 0.92,
      );

  static InputDecoration fieldDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final shape = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: scheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: shape.copyWith(
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: shape.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: shape.copyWith(borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: shape.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    );
  }
}
