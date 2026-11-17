import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_transaction_suggestion.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/gemini_datasource.dart';

/// Implementação inicial do repositório de IA isolada dos demais módulos.
class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl(this._datasource);

  final GeminiDatasource _datasource;

  @override
  Future<AiMessage> sendTextPrompt({
    required String prompt,
    required List<String> availableCategories,
    required List<String> availableAccounts,
    required List<String> availableCards,
  }) async {
    final response = await _datasource.invokeAssistantEndpoint(
      payload: {
        'mode': 'text',
        'prompt': prompt,
        'categories': availableCategories,
        'accounts': availableAccounts,
        'cards': availableCards,
      },
    );

    final suggestion = response['suggestion'] is Map<String, dynamic>
        ? AiTransactionSuggestion.fromJson(
            response['suggestion'] as Map<String, dynamic>,
          )
        : null;

    return AiMessage(
      id: (response['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.assistant,
      content: (response['reply'] as String?) ?? '',
      createdAt: DateTime.now(),
      suggestion: suggestion,
    );
  }

  @override
  Future<AiTransactionSuggestion?> analyzeReceiptImage({
    required List<int> imageBytes,
    required String mimeType,
  }) async {
    final response = await _datasource.invokeAssistantEndpoint(
      payload: {
        'mode': 'receipt_image',
        'mimeType': mimeType,
        'sizeBytes': imageBytes.length,
      },
    );

    if (response['suggestion'] is Map<String, dynamic>) {
      return AiTransactionSuggestion.fromJson(
        response['suggestion'] as Map<String, dynamic>,
      );
    }
    return null;
  }
}
