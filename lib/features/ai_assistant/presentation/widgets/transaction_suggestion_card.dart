import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_transaction_suggestion.dart';

/// Cartão estruturado com revisão, resolução de ambiguidades, separação de itens
/// da nota e confirmação explícita obrigatória antes de gravar no Firestore.
class TransactionSuggestionCard extends StatelessWidget {
  const TransactionSuggestionCard({
    super.key,
    required this.suggestion,
    required this.resolution,
    required this.isSaving,
    required this.accounts,
    required this.cards,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
    required this.onSelectSuggestion,
  });

  final AiTransactionSuggestion suggestion;
  final AiSuggestionResolution resolution;
  final bool isSaving;
  final List<AccountEntity> accounts;
  final List<CreditCardEntity> cards;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final ValueChanged<AiTransactionSuggestion> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = resolution == AiSuggestionResolution.pending;

    final badgeData = switch (resolution) {
      AiSuggestionResolution.confirmed => (
          label: 'Confirmado e salvo',
          color: AppColors.income,
          icon: Icons.check_circle_outline_rounded,
        ),
      AiSuggestionResolution.canceled => (
          label: 'Cancelado (não salvo)',
          color: theme.colorScheme.outline,
          icon: Icons.cancel_outlined,
        ),
      AiSuggestionResolution.pending => (
          label: suggestion.success
              ? 'Aguardando confirmação'
              : 'Dados incompletos',
          color: suggestion.success ? AppColors.aiAccent : AppColors.warning,
          icon: suggestion.success
              ? Icons.verified_user_outlined
              : Icons.help_outline_rounded,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeData.color.withOpacity(0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                label: badgeData.label,
                color: badgeData.color,
                icon: badgeData.icon,
              ),
              if (suggestion.confidence > 0)
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    'Confiança ${(suggestion.confidence * 100).round()}% (auxiliar)',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoLine(
            label: 'Tipo',
            value: _typeLabel(suggestion.transactionType),
          ),
          _InfoLine(label: 'Descrição', value: suggestion.description),
          _InfoLine(
            label: 'Valor',
            value: suggestion.amountCents > 0
                ? CurrencyFormatter.formatCents(suggestion.amountCents)
                : 'Não identificado',
            valueColor: suggestion.amountCents > 0
                ? _amountColor(suggestion.transactionType)
                : AppColors.warning,
          ),
          _InfoLine(
            label: 'Data',
            value: (suggestion.date.hour != 0 || suggestion.date.minute != 0)
                ? DateFormatter.shortDateTime(suggestion.date)
                : DateFormatter.shortDate(suggestion.date),
          ),
          if ((suggestion.categorySuggestion ?? '').isNotEmpty)
            _InfoLine(
              label: 'Categoria',
              value: suggestion.categoryIsNew
                  ? '${suggestion.categorySuggestion!} (nova ao confirmar)'
                  : suggestion.categorySuggestion!,
            ),
          if ((suggestion.accountName ?? '').isNotEmpty)
            _InfoLine(
              label: suggestion.transactionType == 'transfer'
                  ? 'Conta origem'
                  : 'Conta',
              value: suggestion.accountName!,
            ),
          if ((suggestion.destinationAccountName ?? '').isNotEmpty)
            _InfoLine(
              label: 'Conta destino',
              value: suggestion.destinationAccountName!,
            ),
          if ((suggestion.creditCardName ?? '').isNotEmpty)
            _InfoLine(
              label: 'Cartão',
              value: suggestion.installments > 1
                  ? '${suggestion.creditCardName!} (${suggestion.installments}x)'
                  : suggestion.creditCardName!,
            ),
          if ((suggestion.merchantName ?? '').isNotEmpty)
            _InfoLine(
              label: 'Estabelecimento',
              value: suggestion.merchantName!,
            ),
          if (suggestion.discountCents != null || suggestion.taxCents != null)
            _InfoLine(
              label: 'Detalhes da nota',
              value: [
                if (suggestion.discountCents != null)
                  'Desconto ${CurrencyFormatter.formatCents(suggestion.discountCents!)}',
                if (suggestion.taxCents != null)
                  'Impostos ${CurrencyFormatter.formatCents(suggestion.taxCents!)}',
              ].join(' • '),
            ),
          if (suggestion.hasMultipleItems && isPending) ...[
            const SizedBox(height: 10),
            Text(
              'Itens identificados no documento (${suggestion.extractedItems.length}):',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Registrar valor total'),
                  selected: !suggestion.splitIntoItems,
                  onSelected: (_) => onSelectSuggestion(
                    suggestion.copyWith(splitIntoItems: false),
                  ),
                ),
                ChoiceChip(
                  label: Text(
                    'Separar ${suggestion.extractedItems.length} itens',
                  ),
                  selected: suggestion.splitIntoItems,
                  onSelected: (_) => onSelectSuggestion(
                    suggestion.copyWith(splitIntoItems: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in suggestion.extractedItems.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatCents(item.amountCents),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (isPending && suggestion.ambiguousCards.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Escolha qual cartão utilizar:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final card in cards.where(
                  (c) => suggestion.ambiguousCards.contains(c.name),
                ))
                  ActionChip(
                    label: Text(card.name),
                    onPressed: () => onSelectSuggestion(
                      suggestion.copyWith(
                        creditCardId: card.id,
                        creditCardName: card.name,
                        ambiguousCards: const [],
                        missingInformation: const [],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (isPending && suggestion.ambiguousAccounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Escolha qual conta utilizar:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final acc in accounts.where(
                  (a) => suggestion.ambiguousAccounts.contains(a.name),
                ))
                  ActionChip(
                    label: Text(acc.name),
                    onPressed: () => onSelectSuggestion(
                      suggestion.copyWith(
                        accountId: acc.id,
                        accountName: acc.name,
                        ambiguousAccounts: const [],
                        missingInformation: const [],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (suggestion.hasMissingInformation) ...[
            const SizedBox(height: 10),
            _WarningBox(
              icon: Icons.info_outline_rounded,
              color: AppColors.warning,
              lines: suggestion.missingInformation,
            ),
          ],
          if ((suggestion.potentialDuplicateWarning ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _WarningBox(
              icon: Icons.warning_amber_rounded,
              color: AppColors.expense,
              lines: [suggestion.potentialDuplicateWarning!],
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isSaving || suggestion.amountCents <= 0
                      ? null
                      : onConfirm,
                  icon: isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirmar e salvar'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: isSaving ? null : onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _typeLabel(String type) {
    return switch (type) {
      'income' => 'Receita',
      'card_purchase' => 'Compra no cartão',
      'card_refund' => 'Estorno avulso no cartão',
      'transfer' => 'Transferência entre contas',
      'invoice_payment' => 'Pagamento de fatura',
      'recurring_expense' => 'Despesa recorrente',
      'recurring_income' => 'Receita recorrente',
      _ => 'Despesa',
    };
  }

  static Color _amountColor(String type) {
    return switch (type) {
      'income' || 'recurring_income' || 'card_refund' => AppColors.income,
      'transfer' => AppColors.transfer,
      _ => AppColors.expense,
    };
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({
    required this.icon,
    required this.color,
    required this.lines,
  });

  final IconData icon;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
