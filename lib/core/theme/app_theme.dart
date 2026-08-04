import 'package:flutter/material.dart';

/// Liquid-glass dark theme.
///
/// Surfaces are intentionally translucent so the ambient backdrop shows through
/// the blurred panels; opaque component defaults are cleared to transparent to
/// avoid stacking a solid fill on top of the frosted layers.
abstract final class AppTheme {
  static const _seedColor = Color(0xFF8468D7);
  static const _darkSurface = Color(0xFF0E0C15);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      surface: _darkSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        titleSpacing: 16,
        toolbarHeight: 56,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.86),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.88),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        contentTextStyle: TextStyle(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        minTileHeight: 58,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.26),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.05),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.07),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            scheme.surface.withValues(alpha: 0.95),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
        ),
      ),
    );
  }
}
