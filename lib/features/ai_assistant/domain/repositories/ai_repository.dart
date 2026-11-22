import '../entities/ai_message.dart';
import '../entities/ai_quota_status.dart';

/// Resposta completa de uma interação conversacional ou multimodal com a IA.
class AiChatResult {
  const AiChatResult({
    required this.message,
    required this.quota,
  });

  final AiMessage message;
  final AiQuotaStatus quota;
}

/// Diagnóstico atual de cota e privacidade do Assistente IA no backend.
class AiStatusResult {
  const AiStatusResult({
    required this.quota,
    required this.aiAssistantEnabled,
    required this.aiShareFinancialContext,
    required this.modelName,
  });

  final AiQuotaStatus quota;
  final bool aiAssistantEnabled;
  final bool aiShareFinancialContext;
  final String modelName;
}

/// Contrato independente do Assistente Financeiro IA.
abstract interface class AiRepository {
  Future<AiChatResult> sendTextPrompt({
    required String prompt,
    List<AiMessage> history = const [],
    List<String> availableCategories = const [],
    List<String> availableAccounts = const [],
    List<String> availableCards = const [],
  });

  Future<AiChatResult> analyzeReceiptImage({
    required List<int> imageBytes,
    required String mimeType,
    String? caption,
    List<String> availableCategories = const [],
    List<String> availableAccounts = const [],
    List<String> availableCards = const [],
  });

  Future<AiStatusResult> fetchStatus();
}
