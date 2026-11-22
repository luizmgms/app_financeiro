import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_transaction_suggestion.dart';
import 'transaction_suggestion_card.dart';

/// Bolha de mensagem da conversa com o Assistente IA, exibindo ferramentas usadas
/// (Function Calling) e cartões editáveis de sugestão financeira.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isSavingSuggestion,
    required this.accounts,
    required this.cards,
    required this.onConfirmSuggestion,
    required this.onEditSuggestion,
    required this.onCancelSuggestion,
    required this.onUpdateSuggestion,
  });

  final AiMessage message;
  final bool isSavingSuggestion;
  final List<AccountEntity> accounts;
  final List<CreditCardEntity> cards;
  final VoidCallback onConfirmSuggestion;
  final VoidCallback onEditSuggestion;
  final VoidCallback onCancelSuggestion;
  final ValueChanged<AiTransactionSuggestion> onUpdateSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.role == AiMessageRole.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final isUser = message.role == AiMessageRole.user;
    final bubbleColor = isUser
        ? theme.colorScheme.primary.withOpacity(0.14)
        : (message.isError
            ? AppColors.expense.withOpacity(0.10)
            : theme.cardColor);
    final borderColor = isUser
        ? theme.colorScheme.primary.withOpacity(0.30)
        : (message.isError
            ? AppColors.expense.withOpacity(0.35)
            : theme.dividerColor.withOpacity(0.22));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser
                        ? Icons.person_outline_rounded
                        : (message.isError
                            ? Icons.error_outline_rounded
                            : Icons.auto_awesome_rounded),
                    size: 16,
                    color: isUser
                        ? theme.colorScheme.primary
                        : (message.isError
                            ? AppColors.expense
                            : AppColors.aiAccent),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUser ? 'Você' : 'Assistente IA',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isUser
                          ? theme.colorScheme.primary
                          : (message.isError
                              ? AppColors.expense
                              : AppColors.aiAccent),
                    ),
                  ),
                  if ((message.attachmentLabel ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        avatar: const Icon(Icons.image_outlined, size: 14),
                        label: Text(
                          message.attachmentLabel!,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (message.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(
                  message.content,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (message.toolsUsed.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tool in message.toolsUsed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.aiAccent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _toolLabel(tool),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.aiAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (message.suggestion != null)
                TransactionSuggestionCard(
                  suggestion: message.suggestion!,
                  resolution: message.resolution,
                  isSaving: isSavingSuggestion,
                  accounts: accounts,
                  cards: cards,
                  onConfirm: onConfirmSuggestion,
                  onEdit: onEditSuggestion,
                  onCancel: onCancelSuggestion,
                  onSelectSuggestion: onUpdateSuggestion,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _toolLabel(String toolName) {
    return switch (toolName) {
      'get_monthly_summary' => 'Resumo mensal consultado',
      'get_spending_by_category' => 'Gastos por categoria consultados',
      'get_credit_cards_status' => 'Cartões e faturas consultados',
      'get_upcoming_bills_and_installments' =>
        'Vencimentos e parcelas consultados',
      'get_top_expenses_budgets_and_anomalies' =>
        'Orçamentos e anomalias analisados',
      _ => toolName,
    };
  }
}
