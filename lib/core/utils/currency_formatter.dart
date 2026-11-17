import 'package:intl/intl.dart';

/// Utilitário de formatação e leitura monetária com precisão em centavos inteiros.
abstract final class CurrencyFormatter {
  static String formatCents(
    int cents, {
    String locale = 'pt_BR',
    String currencyCode = 'BRL',
  }) {
    final symbol = switch (currencyCode.toUpperCase()) {
      'BRL' => r'R$',
      'USD' => r'US$',
      'EUR' => '€',
      _ => currencyCode,
    };

    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(cents / 100.0);
  }

  /// Converte texto monetário (ex.: "1.234,56" ou "45.90") para centavos inteiros.
  /// Retorna `null` se o valor for inválido.
  static int? parseToCents(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-') return null;

    final isNegative = cleaned.startsWith('-');
    final unsigned = cleaned.replaceAll('-', '');
    if (unsigned.isEmpty) return null;

    final lastComma = unsigned.lastIndexOf(',');
    final lastDot = unsigned.lastIndexOf('.');

    String normalized;
    if (lastComma > lastDot) {
      // Formato brasileiro: 1.234,56
      normalized = unsigned.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma && lastComma != -1) {
      // Formato americano: 1,234.56
      normalized = unsigned.replaceAll(',', '');
    } else if (lastComma != -1) {
      normalized = unsigned.replaceAll(',', '.');
    } else {
      normalized = unsigned;
    }

    final parts = normalized.split('.');
    if (parts.length > 2) return null;

    final wholePart = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (wholePart == null) return null;

    var fractionalCents = 0;
    if (parts.length == 2) {
      final frac = parts[1];
      if (frac.length == 1) {
        fractionalCents = (int.tryParse(frac) ?? 0) * 10;
      } else if (frac.length >= 2) {
        final twoDigits = int.tryParse(frac.substring(0, 2));
        if (twoDigits == null) return null;
        fractionalCents = twoDigits;
      }
    }

    final totalCents = wholePart * 100 + fractionalCents;
    return isNegative ? -totalCents : totalCents;
  }
}
