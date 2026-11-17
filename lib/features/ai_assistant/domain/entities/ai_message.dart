import 'package:equatable/equatable.dart';
import 'ai_transaction_suggestion.dart';

enum AiMessageRole { user, assistant, system }

/// Mensagem da interface conversacional do Assistente Financeiro IA.
class AiMessage extends Equatable {
  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.suggestion,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final AiTransactionSuggestion? suggestion;

  @override
  List<Object?> get props => [id, role, content, createdAt, suggestion];
}
