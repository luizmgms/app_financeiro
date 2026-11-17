import 'package:finance_control/features/ai_assistant/domain/entities/ai_transaction_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiTransactionSuggestion', () {
    test('parses valid structured JSON and enforces requiresConfirmation', () {
      final suggestion = AiTransactionSuggestion.fromJson(const {
        'success': true,
        'transaction_type': 'expense',
        'description': 'Compra no supermercado',
        'amount_cents': 15000,
        'currency': 'BRL',
        'date': '2026-11-17',
        'category_suggestion': 'Alimentação',
        'payment_method': 'credit_card',
        'credit_card_name': 'Nubank',
        'account_name': null,
        'installments': 1,
        'confidence': 0.96,
        // Mesmo que viesse false da IA, a entidade deve exigir confirmação.
        'requires_confirmation': false,
        'missing_information': <String>[],
      });

      expect(suggestion.amountCents, 15000);
      expect(suggestion.creditCardName, 'Nubank');
      expect(suggestion.requiresConfirmation, isTrue);
      expect(suggestion.hasMissingInformation, isFalse);
    });

    test('rejects invalid non-positive amount_cents', () {
      expect(
        () => AiTransactionSuggestion.fromJson(const {
          'success': true,
          'transaction_type': 'expense',
          'description': 'Teste',
          'amount_cents': 0,
          'date': '2026-11-17',
        }),
        throwsFormatException,
      );
    });
  });
}
