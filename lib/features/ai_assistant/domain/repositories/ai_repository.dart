import '../entities/ai_message.dart';
import '../entities/ai_transaction_suggestion.dart';

/// Contrato independente do Assistente Financeiro IA.
abstract interface class AiRepository {
  Future<AiMessage> sendTextPrompt({
    required String prompt,
    required List<String> availableCategories,
    required List<String> availableAccounts,
    required List<String> availableCards,
  });

  Future<AiTransactionSuggestion?> analyzeReceiptImage({
    required List<int> imageBytes,
    required String mimeType,
  });
}
