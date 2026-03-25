import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SameEnergyPalette {
  SameEnergyPalette._();

  static const lightBackground = Color(0xFFF8F7F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFF1EEE6);
  static const lightPrimary = Color(0xFF141414);
  static const lightMuted = Color(0xFF6B665E);
  static const lightBorder = Color(0xFFE1DBCF);

  static const darkBackground = Color(0xFF090B0D);
  static const darkSurface = Color(0xFF121519);
  static const darkElevated = Color(0xFF1A2026);
  static const darkPrimary = Color(0xFFF3F2EE);
  static const darkMuted = Color(0xFF9A9EA4);
  static const darkBorder = Color(0xFF27303A);

  static const defaultAccent = Color(0xFFDB5E36);
  static const accentSoft = Color(0xFFF7E0D8);
  static const error = Color(0xFFE53935);

  /// Preset accent colors for the picker.
  static const List<Color> accentPresets = [
    defaultAccent,
    Color(0xFF4A90D9),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFE91E63),
    Color(0xFF27AE60),
    Color(0xFFE74C3C),
    Color(0xFFF39C12),
  ];
}

class SameEnergyTheme {
  SameEnergyTheme._();

  static ThemeData light({Color? accentColor}) =>
      _build(Brightness.light, accentColor: accentColor);

  static ThemeData dark({Color? accentColor}) =>
      _build(Brightness.dark, accentColor: accentColor);

  static Color surfaceFor(BuildContext context, {bool elevated = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return elevated
          ? SameEnergyPalette.darkElevated
          : SameEnergyPalette.darkSurface;
    }
    return elevated
        ? SameEnergyPalette.lightElevated
        : SameEnergyPalette.lightSurface;
  }

  static Color borderFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? SameEnergyPalette.darkBorder
        : SameEnergyPalette.lightBorder;
  }

  static Color mutedFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? SameEnergyPalette.darkMuted
        : SameEnergyPalette.lightMuted;
  }

  /// Glass-morphism background color (semi-transparent).
  static Color glassColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF121519).withValues(alpha: 0.55)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.55);
  }

  /// Glass-morphism border color.
  static Color glassBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.5);
  }

  /// Standard glass border radius.
  static BorderRadius get glassBorderRadius => BorderRadius.circular(20);

  /// Full glass decoration with backdrop-blur-compatible styling.
  static BoxDecoration glassDecoration(
    BuildContext context, {
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: glassColor(context),
      borderRadius: borderRadius ?? glassBorderRadius,
      border: Border.all(color: glassBorderColor(context), width: 0.8),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.02),
              ]
            : [
                Colors.white.withValues(alpha: 0.72),
                Colors.white.withValues(alpha: 0.40),
              ],
      ),
    );
  }

  /// Wrap a widget with glass blur effect.
  static Widget glassContainer(
    BuildContext context, {
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    double sigmaX = 18,
    double sigmaY = 18,
  }) {
    final br = borderRadius ?? glassBorderRadius;
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          decoration: glassDecoration(context, borderRadius: br),
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  static Color accentSoftFor(Color accent) {
    return HSLColor.fromColor(
      accent,
    ).withSaturation(0.3).withLightness(0.9).toColor();
  }

  static ThemeData _build(Brightness brightness, {Color? accentColor}) {
    final isDark = brightness == Brightness.dark;
    final accent = accentColor ?? SameEnergyPalette.defaultAccent;
    final accentSoft = accentSoftFor(accent);
    final background = isDark
        ? SameEnergyPalette.darkBackground
        : SameEnergyPalette.lightBackground;
    final surface = isDark
        ? SameEnergyPalette.darkSurface
        : SameEnergyPalette.lightSurface;
    final onSurface = isDark
        ? SameEnergyPalette.darkPrimary
        : SameEnergyPalette.lightPrimary;
    final secondary = isDark
        ? SameEnergyPalette.darkMuted
        : SameEnergyPalette.lightMuted;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: Colors.white,
          secondary: secondary,
          onSecondary: onSurface,
          error: SameEnergyPalette.error,
          onError: Colors.white,
          surface: surface,
          onSurface: onSurface,
          tertiary: accentSoft,
          onTertiary: SameEnergyPalette.lightPrimary,
          inverseSurface: onSurface,
          onInverseSurface: background,
          inversePrimary: accent,
          surfaceContainerHighest: isDark
              ? SameEnergyPalette.darkElevated
              : SameEnergyPalette.lightElevated,
          outline: isDark
              ? SameEnergyPalette.darkBorder
              : SameEnergyPalette.lightBorder,
          outlineVariant: isDark
              ? SameEnergyPalette.darkBorder
              : SameEnergyPalette.lightBorder,
        );

    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final textTheme = GoogleFonts.spaceGroteskTextTheme(
      base.textTheme,
    ).apply(bodyColor: onSurface, displayColor: onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      canvasColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF20262E)
            : const Color(0xFF1B1D1F),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: accentSoft,
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: isDark ? 0.26 : 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : secondary,
            size: selected ? 24 : 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : secondary,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface.withValues(alpha: 0.85),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? SameEnergyPalette.darkElevated
            : SameEnergyPalette.lightElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? SameEnergyPalette.darkBorder
            : SameEnergyPalette.lightBorder,
      ),
    );
  }
}
