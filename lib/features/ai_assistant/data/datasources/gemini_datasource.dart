import '../../../../core/errors/app_exception.dart';

/// Fonte de dados que se comunicará exclusivamente com Cloud Functions / Cloud Run
/// autenticadas (nunca expondo chave Gemini no aplicativo Flutter).
class GeminiDatasource {
  Future<Map<String, dynamic>> invokeAssistantEndpoint({
    required Map<String, dynamic> payload,
  }) async {
    throw const AppException(
      'Backend do Assistente Gemini (Cloud Functions) será conectado na Etapa 6.',
      code: 'ai-backend-not-deployed',
    );
  }
}
