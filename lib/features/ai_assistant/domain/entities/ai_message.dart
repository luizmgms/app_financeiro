import 'package:equatable/equatable.dart';
import 'ai_transaction_suggestion.dart';

enum AiMessageRole { user, assistant, system }

/// Estado explícito da proposta associada a uma mensagem do assistente.
enum AiSuggestionResolution {
  pending,
  confirmed,
  canceled,
}

/// Mensagem da interface conversacional do Assistente Financeiro IA.
class AiMessage extends Equatable {
  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.intent,
    this.modelName,
    this.toolsUsed = const [],
    this.suggestion,
    this.resolution = AiSuggestionResolution.pending,
    this.attachmentLabel,
    this.isError = false,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final String? intent;
  final String? modelName;
  final List<String> toolsUsed;
  final AiTransactionSuggestion? suggestion;
  final AiSuggestionResolution resolution;
  final String? attachmentLabel;
  final bool isError;

  AiMessage copyWith({
    String? content,
    AiTransactionSuggestion? suggestion,
    bool clearSuggestion = false,
    AiSuggestionResolution? resolution,
    List<String>? toolsUsed,
    bool? isError,
  }) {
    return AiMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      intent: intent,
      modelName: modelName,
      toolsUsed: toolsUsed ?? this.toolsUsed,
      suggestion: clearSuggestion ? null : (suggestion ?? this.suggestion),
      resolution: resolution ?? this.resolution,
      attachmentLabel: attachmentLabel,
      isError: isError ?? this.isError,
    );
  }

  @override
  List<Object?> get props => [
        id,
        role,
        content,
        createdAt,
        intent,
        modelName,
        toolsUsed,
        suggestion,
        resolution,
        attachmentLabel,
        isError,
      ];
}
