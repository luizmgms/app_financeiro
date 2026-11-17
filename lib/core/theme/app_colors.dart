import 'package:flutter/material.dart';

/// Paleta de cores do Finance Control inspirada em dashboards financeiros modernos.
abstract final class AppColors {
  // Identidade principal (Esmeralda Profundo / Teal)
  static const Color primaryLight = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF14B8A6);
  static const Color secondaryAccent = Color(0xFF059669);

  // Superfícies
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEEF2F6);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color darkBackground = Color(0xFF0A0F1A);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF283548);

  // Semânticas financeiras
  static const Color income = Color(0xFF10B981);
  static const Color expense = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color transfer = Color(0xFF3B82F6);
  static const Color credit = Color(0xFF8B5CF6);
  static const Color aiAccent = Color(0xFF6366F1);
}
