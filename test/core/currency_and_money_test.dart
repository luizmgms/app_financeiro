import 'package:finance_control/core/utils/currency_formatter.dart';
import 'package:finance_control/shared/models/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money & CurrencyFormatter', () {
    test('splitEqually preserves exact total cents without rounding drift', () {
      const total = Money(cents: 10000); // R$ 100,00
      final installments = total.splitEqually(3);

      expect(installments.length, 3);
      expect(installments.map((m) => m.cents), [3334, 3333, 3333]);
      final sum = installments.fold<int>(0, (acc, item) => acc + item.cents);
      expect(sum, total.cents);
    });

    test('parseToCents parses Brazilian and plain decimal formats', () {
      expect(CurrencyFormatter.parseToCents('1.234,56'), 123456);
      expect(CurrencyFormatter.parseToCents('45,9'), 4590);
      expect(CurrencyFormatter.parseToCents('R\$ 58,90'), 5890);
      expect(CurrencyFormatter.parseToCents('150'), 15000);
      expect(CurrencyFormatter.parseToCents(''), isNull);
    });

    test('formatCents formats BRL currency cleanly', () {
      final formatted = CurrencyFormatter.formatCents(15025);
      expect(formatted, contains('150,25'));
      expect(formatted, contains('R\$'));
    });
  });
}
