import 'package:equatable/equatable.dart';
import '../../core/utils/currency_formatter.dart';

/// Objeto de valor monetário que garante armazenamento exato em centavos inteiros.
class Money extends Equatable {
  const Money({
    required this.cents,
    this.currencyCode = 'BRL',
  });

  const Money.zero({this.currencyCode = 'BRL'}) : cents = 0;

  final int cents;
  final String currencyCode;

  bool get isZero => cents == 0;
  bool get isPositive => cents > 0;
  bool get isNegative => cents < 0;

  Money operator +(Money other) {
    assert(currencyCode == other.currencyCode, 'Moedas incompatíveis');
    return Money(cents: cents + other.cents, currencyCode: currencyCode);
  }

  Money operator -(Money other) {
    assert(currencyCode == other.currencyCode, 'Moedas incompatíveis');
    return Money(cents: cents - other.cents, currencyCode: currencyCode);
  }

  /// Divide o valor total em [parts] parcelas garantindo que a soma exata
  /// das parcelas seja igual ao valor original, sem perda de centavos.
  List<Money> splitEqually(int parts) {
    if (parts <= 0) {
      throw ArgumentError.value(parts, 'parts', 'Deve ser maior que zero');
    }

    final baseAmount = cents ~/ parts;
    final remainder = cents.remainder(parts);
    final sign = remainder >= 0 ? 1 : -1;
    final absRemainder = remainder.abs();

    return List<Money>.generate(parts, (index) {
      final extraCent = index < absRemainder ? sign : 0;
      return Money(
        cents: baseAmount + extraCent,
        currencyCode: currencyCode,
      );
    });
  }

  String format({String locale = 'pt_BR'}) {
    return CurrencyFormatter.formatCents(
      cents,
      locale: locale,
      currencyCode: currencyCode,
    );
  }

  @override
  List<Object?> get props => [cents, currencyCode];
}
