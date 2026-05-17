import 'package:flutter/material.dart';

/// Centralized color palette and themes for the Mentora app.
///
/// All UI should reference these tokens instead of hardcoding hex values so
/// theme changes propagate consistently throughout the app.
class AppTheme {
  AppTheme._();

  // --- Brand palette --------------------------------------------------------
  static const Color primary = Color(0xFF7C3AED); // Electric Purple
  static const Color secondary = Color(0xFF2563EB); // Blue
  static const Color accent = Color(0xFFA3E635); // Lime

  static const Color backgroundLight = Color(0xFFFAFAFA); // Near White
  static const Color backgroundDark = Color(0xFF020617); // Deep Navy
  static const Color cardDark = Color(0xFF0F172A); // Slate
  static const Color cardDarkElevated = Color(0xFF111C33); // Slate +1
  static const Color textLight = Color(0xFFF8FAFC); // White
  static const Color textDark = Color(0xFF111827); // Ink

  // Supportive tones derived from the palette.
  static const Color outlineDark = Color(0xFF1E293B);
  static const Color outlineLight = Color(0xFFE2E8F0);
  static const Color mutedDark = Color(0xFF94A3B8);
  static const Color mutedLight = Color(0xFF475569);

  // --- Light theme ----------------------------------------------------------
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: textLight,
      primaryContainer: Color(0xFFEDE4FF),
      onPrimaryContainer: Color(0xFF2E1065),
      secondary: secondary,
      onSecondary: textLight,
      secondaryContainer: Color(0xFFDBEAFE),
      onSecondaryContainer: Color(0xFF0B2A66),
      tertiary: accent,
      onTertiary: textDark,
      tertiaryContainer: Color(0xFFE6F8C6),
      onTertiaryContainer: Color(0xFF1A2E05),
      error: Color(0xFFDC2626),
      onError: textLight,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: backgroundLight,
      onSurface: textDark,
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF5F5F7),
      surfaceContainer: Color(0xFFEEEFF3),
      surfaceContainerHigh: Color(0xFFE7E9EE),
      surfaceContainerHighest: Color(0xFFDEE1E8),
      onSurfaceVariant: mutedLight,
      outline: outlineLight,
      outlineVariant: Color(0xFFEEF2F7),
      inverseSurface: cardDark,
      onInverseSurface: textLight,
      inversePrimary: Color(0xFFB199FF),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return _buildTheme(scheme);
  }

  // --- Dark theme -----------------------------------------------------------
  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: textLight,
      primaryContainer: Color(0xFF3B127A),
      onPrimaryContainer: Color(0xFFEDE4FF),
      secondary: secondary,
      onSecondary: textLight,
      secondaryContainer: Color(0xFF153E8C),
      onSecondaryContainer: Color(0xFFDBEAFE),
      tertiary: accent,
      onTertiary: textDark,
      tertiaryContainer: Color(0xFF3A5A12),
      onTertiaryContainer: Color(0xFFE6F8C6),
      error: Color(0xFFF87171),
      onError: textDark,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: backgroundDark,
      onSurface: textLight,
      surfaceContainerLowest: Color(0xFF010410),
      surfaceContainerLow: Color(0xFF0A1124),
      surfaceContainer: cardDark,
      surfaceContainerHigh: cardDarkElevated,
      surfaceContainerHighest: Color(0xFF152138),
      onSurfaceVariant: mutedDark,
      outline: outlineDark,
      outlineVariant: Color(0xFF1C2740),
      inverseSurface: backgroundLight,
      onInverseSurface: textDark,
      inversePrimary: Color(0xFFB199FF),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return _buildTheme(scheme);
  }

  static ThemeData _buildTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? cardDark : Colors.white,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? scheme.onPrimaryContainer : scheme.primary)
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          // Visible thumb when off, even on light surfaces.
          return isDark ? scheme.onSurfaceVariant : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return isDark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return scheme.outline;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
    );
  }
}
