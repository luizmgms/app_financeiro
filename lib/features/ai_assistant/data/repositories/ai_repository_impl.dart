import 'dart:convert';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_quota_status.dart';
import '../../domain/entities/ai_transaction_suggestion.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/gemini_datasource.dart';

/// Implementação do repositório do Assistente IA conectada à Cloud Function `aiAssistantQuery`.
class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl(this._datasource);

  final GeminiDatasource _datasource;

  @override
  Future<AiChatResult> sendTextPrompt({
    required String prompt,
    List<AiMessage> history = const [],
    List<String> availableCategories = const [],
    List<String> availableAccounts = const [],
    List<String> availableCards = const [],
  }) async {
    final sanitizedHistory = history
        .where(
          (m) =>
              !m.isError &&
              (m.role == AiMessageRole.user ||
                  m.role == AiMessageRole.assistant),
        )
        .take(8)
        .map(
          (m) => {
            'role': m.role == AiMessageRole.assistant ? 'assistant' : 'user',
            'content': m.content,
          },
        )
        .toList(growable: false);

    final response = await _datasource.invokeAssistantEndpoint(
      payload: {
        'mode': 'chat',
        'prompt': prompt,
        'history': sanitizedHistory,
        'categories': availableCategories,
        'accounts': availableAccounts,
        'cards': availableCards,
      },
    );

    return _parseChatResult(response);
  }

  @override
  Future<AiChatResult> analyzeReceiptImage({
    required List<int> imageBytes,
    required String mimeType,
    String? caption,
    List<String> availableCategories = const [],
    List<String> availableAccounts = const [],
    List<String> availableCards = const [],
  }) async {
    final response = await _datasource.invokeAssistantEndpoint(
      payload: {
        'mode': 'receipt_image',
        'mimeType': mimeType,
        'imageBase64': base64Encode(imageBytes),
        'prompt': caption ?? '',
        'categories': availableCategories,
        'accounts': availableAccounts,
        'cards': availableCards,
      },
    );

    return _parseChatResult(response);
  }

  @override
  Future<AiStatusResult> fetchStatus() async {
    final response = await _datasource.invokeAssistantEndpoint(
      payload: {'mode': 'status'},
    );

    final quotaMap = response['quota'] is Map
        ? GeminiDatasource.normalizePayloadMap(response['quota'])
        : const <String, dynamic>{};
    final privacyMap = response['privacy'] is Map
        ? GeminiDatasource.normalizePayloadMap(response['privacy'])
        : const <String, dynamic>{};

    return AiStatusResult(
      quota: AiQuotaStatus.fromJson(quotaMap),
      aiAssistantEnabled: privacyMap['aiAssistantEnabled'] as bool? ?? true,
      aiShareFinancialContext:
          privacyMap['aiShareFinancialContext'] as bool? ?? true,
      modelName: (response['model'] as String?) ?? 'gemini-3.8-flash',
    );
  }

  AiChatResult _parseChatResult(Map<String, dynamic> response) {
    final normalized = GeminiDatasource.normalizePayloadMap(response);
    final rawSuggestion = normalized['suggestion'] is Map
        ? GeminiDatasource.normalizePayloadMap(normalized['suggestion'])
        : null;

    AiTransactionSuggestion? suggestion;
    if (rawSuggestion != null) {
      if (rawSuggestion['success'] == true &&
          (rawSuggestion['amount_cents'] as num? ?? 0) > 0) {
        suggestion = AiTransactionSuggestion.fromJson(rawSuggestion);
      } else {
        suggestion =
            AiTransactionSuggestion.tryFromResponseJson(rawSuggestion);
      }
    }

    final quotaMap = normalized['quota'] is Map
        ? GeminiDatasource.normalizePayloadMap(normalized['quota'])
        : const <String, dynamic>{};
    final quota = AiQuotaStatus.fromJson(quotaMap);

    final toolsUsed = normalized['tools_used'] is List
        ? (normalized['tools_used'] as List)
            .whereType<String>()
            .toList(growable: false)
        : const <String>[];

    final message = AiMessage(
      id: (normalized['id'] as String?) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.assistant,
      content: (normalized['reply'] as String?) ?? '',
      createdAt: DateTime.now(),
      intent: normalized['intent'] as String?,
      modelName: normalized['model'] as String?,
      toolsUsed: toolsUsed,
      suggestion: suggestion,
      resolution: AiSuggestionResolution.pending,
    );

    return AiChatResult(message: message, quota: quota);
  }
}
