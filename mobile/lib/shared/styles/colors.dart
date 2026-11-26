import 'package:flutter/material.dart';

/// Unified brand palette.
///
/// The organic GREEN family (previously duplicated as a private `_MediPalette`
/// inside the Today screen) is the app-wide brand identity — calm, medical,
/// elderly-friendly. `primary` seeds the Material ColorScheme, so every
/// screen, button and FAB follows the same identity.
class AppColors {
  AppColors._();

  // ---- Brand (organic green — the single source of truth) ----
  static const primary = Color(0xFF174D3F); // forest
  static const primaryDark = Color(0xFF10392F); // forest deep
  static const teal = Color(0xFF00A396);
  static const tealDark = Color(0xFF14B8A6);

  static const mint = Color(0xFFDAF2E6);
  static const sage = Color(0xFFBFDCCB);
  static const canvas = Color(0xFFF3F8F5);
  static const brandText = Color(0xFF183B32);
  static const secondaryText = Color(0xFF678078);
  static const amberAccent = Color(0xFFE5B65C);

  // ---- Semantic status colors (shared by every screen) ----
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);

  // ---- Surfaces & text ----
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
}
