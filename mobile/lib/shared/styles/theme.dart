import 'package:flutter/material.dart';

import 'colors.dart';

/// App ThemeData — Cairo (bundled, offline-safe), M3, >=48dp targets.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      // Cairo is bundled; the elderly-friendly 1.15 scale-up is applied via
      // MediaQuery textScaler in main.dart (Typography styles here carry
      // null sizes, so TextTheme.apply(fontSizeFactor:) would assert).
      textTheme: base.textTheme.apply(
        fontFamily: 'Cairo',
        bodyColor: brightness == Brightness.light ? null : Colors.white,
        displayColor: brightness == Brightness.light ? null : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: brightness == Brightness.light ? const Color(0xFF183B32) : Colors.white,
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.light ? Colors.white.withValues(alpha: .68) : const Color(0xFF172A24).withValues(alpha: .78),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: brightness == Brightness.light ? Colors.white.withValues(alpha: .78) : Colors.white12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white.withValues(alpha: .62)
            : Colors.white.withValues(alpha: .05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(
          height: 1.3,
          fontSize: 15,
          color: brightness == Brightness.light ? Colors.black87 : Colors.white70,
        ),
        floatingLabelStyle: TextStyle(
          height: 1.3,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Size.fromHeight(56) sets width = INFINITY — any button that is a
          // non-flex child of a Row then eats the whole row width and
          // collapses neighbouring Expanded texts to zero width (letters
          // stacked vertically). Keep the 56 height, use a finite 64 min
          // width: full-width buttons stay full-width via their parent
          // (Expanded / stretch / SizedBox(infinity)); inline buttons size
          // to their content as expected.
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(
              fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Same fix as elevatedButtonTheme above (was Size.fromHeight(56)).
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(
              fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
