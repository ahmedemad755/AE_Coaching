import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color canvas;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color success;
  final Color warning;
  final Color error;
  final Color chartGrid;
  final List<Color> chartSeries;

  const AppSemanticColors({
    required this.canvas,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.chartGrid,
    required this.chartSeries,
  });

  static const light = AppSemanticColors(
    canvas: Color(0xfff5f9fc),
    surfaceRaised: Color(0xffeef4fa),
    textPrimary: Color(0xff202936),
    textMuted: Color(0xff657383),
    border: Color(0xffd5e3f2),
    success: Color(0xff18854b),
    warning: Color(0xffa85b00),
    error: Color(0xffc62828),
    chartGrid: Color(0xffd9e1ea),
    chartSeries: [
      Color(0xff2f80ed),
      Color(0xff18854b),
      Color(0xffc62828),
      Color(0xffa85b00),
      Color(0xff7250a5),
    ],
  );

  static const dark = AppSemanticColors(
    canvas: Color(0xff111820),
    surfaceRaised: Color(0xff24313d),
    textPrimary: Color(0xffedf3f8),
    textMuted: Color(0xffaab7c5),
    border: Color(0xff394959),
    success: Color(0xff5ce0a1),
    warning: Color(0xffffc36a),
    error: Color(0xffff8277),
    chartGrid: Color(0xff394959),
    chartSeries: [
      Color(0xff7cb8ff),
      Color(0xff5ce0a1),
      Color(0xffff8277),
      Color(0xffffc36a),
      Color(0xffbc9bff),
    ],
  );

  @override
  AppSemanticColors copyWith({
    Color? canvas,
    Color? surfaceRaised,
    Color? textPrimary,
    Color? textMuted,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
    Color? chartGrid,
    List<Color>? chartSeries,
  }) => AppSemanticColors(
    canvas: canvas ?? this.canvas,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    textPrimary: textPrimary ?? this.textPrimary,
    textMuted: textMuted ?? this.textMuted,
    border: border ?? this.border,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    chartGrid: chartGrid ?? this.chartGrid,
    chartSeries: chartSeries ?? this.chartSeries,
  );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      chartSeries: [
        for (var i = 0; i < chartSeries.length; i++)
          Color.lerp(chartSeries[i], other.chartSeries[i], t)!,
      ],
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}

abstract final class AppTheme {
  static const brandBlue = Color(0xff2f80ed);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static SystemUiOverlayStyle systemUiOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark
          ? AppSemanticColors.dark.canvas
          : AppSemanticColors.light.canvas,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final semantic = isDark ? AppSemanticColors.dark : AppSemanticColors.light;
    final generated = ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: brightness,
    );
    final scheme = generated.copyWith(
      primary: isDark ? const Color(0xff7cb8ff) : brandBlue,
      onPrimary: isDark ? const Color(0xff10243b) : Colors.white,
      surface: isDark ? const Color(0xff1b242e) : Colors.white,
      onSurface: semantic.textPrimary,
      surfaceContainerHighest: semantic.surfaceRaised,
      outline: semantic.border,
      error: semantic.error,
      onError: isDark ? const Color(0xff38110e) : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: semantic.canvas,
      canvasColor: scheme.surface,
      extensions: [semantic],
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: semantic.textPrimary,
        displayColor: semantic.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: semantic.canvas,
        foregroundColor: semantic.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemUiOverlayStyle(brightness),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: semantic.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: semantic.textMuted, fontSize: 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? semantic.surfaceRaised : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: semantic.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: semantic.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: semantic.textMuted),
      ),
      dividerTheme: DividerThemeData(color: semantic.border),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xff303d49)
            : const Color(0xff202936),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: semantic.textPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      iconTheme: IconThemeData(color: semantic.textMuted),
      listTileTheme: ListTileThemeData(
        iconColor: semantic.textMuted,
        textColor: semantic.textPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return semantic.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return semantic.surfaceRaised;
        }),
      ),
    );
  }
}
