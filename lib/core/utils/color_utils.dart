import 'package:flutter/material.dart';

/// Utilitários para conversão e paleta padrão de cores em formato hexadecimal.
abstract final class ColorUtils {
  static const List<String> presetHexColors = <String>[
    '#0F766E',
    '#10B981',
    '#059669',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#06B6D4',
    '#64748B',
  ];

  static Color fromHex(
    String? hex, {
    Color fallback = const Color(0xFF0F766E),
  }) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final cleaned = hex.trim().replaceFirst('#', '');
    final buffer = StringBuffer();
    if (cleaned.length == 6) {
      buffer.write('ff');
      buffer.write(cleaned);
    } else if (cleaned.length == 8) {
      buffer.write(cleaned);
    } else {
      return fallback;
    }

    final parsed = int.tryParse(buffer.toString(), radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  static String toHex(Color color) {
    final rgb = color.value & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
