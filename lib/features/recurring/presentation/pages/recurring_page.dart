import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/controllers/transaction_controller.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_form_dialog.dart';
import '../../application/controllers/recurring_controller.dart';
import '../../application/providers/recurring_providers.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../../domain/services/recurring_schedule_calculator.dart';
import '../widgets/recurring_rule_form_dialog.dart';

/// Tela completa de Contas Recorrentes com geração idempotente, pausa/retomada,
/// cancelamento e edição individual de cada ocorrência sem alterar toda a série.
class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  String _statusFilter = 'active';

  Future<void> _confirmDeleteRule(RecurringRuleEntity rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir recorrência'),
        content: Text(
          'Deseja excluir a regra "${rule.description}"? As ocorrências já lançadas permanecem no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir regra'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(recurringControllerProvider.notifier).deleteRule(rule.id);
    }
  }

  Future<void> _editSingleOccurrence(TransactionEntity tx) async {
    if (tx.kind == TransactionKind.income ||
        tx.kind == TransactionKind.expense) {
      await showTransactionFormDialog(context, existing: tx);
      return;
    }

    if (tx.kind == TransactionKind.cardPurchase && !tx.status.isSettled) {
      final descCtrl = TextEditingController(text: tx.description);
      final amountCtrl = TextEditingController(
        text: (tx.amountCents / 100.0).toStringAsFixed(2).replaceAll('.', ','),
      );
      final notesCtrl = TextEditingController(text: tx.notes ?? '');
      final formKey = GlobalKey<FormState>();

      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: const Text('Ajustar ocorrência no cartão'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 6),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descCtrl,
                      maxLength: 80,
                      decoration:
                          const InputDecoration(labelText: 'Descrição'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Informe a descrição.'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor desta ocorrência (R\$)',
                        prefixText: 'R\$ ',
                      ),
                      validator: (v) {
                        final cents = CurrencyFormatter.parseToCents(v ?? '');
                        if (cents == null || cents <= 0) {
                          return 'Informe um valor válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      maxLength: 240,
                      decoration:
                          const InputDecoration(labelText: 'Observações'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Salvar ocorrência'),
            ),
          ],
        ),
      );

      if (saved == true && mounted) {
        final cents = CurrencyFormatter.parseToCents(amountCtrl.text) ?? 0;
        await ref
            .read(recurringControllerProvider.notifier)
            .updateSingleCardOccurrence(
              transactionId: tx.id,
              description: descCtrl.text,
              amountCents: cents,
              notes: notesCtrl.text,
            );
      }

      descCtrl.dispose();
      amountCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RecurringActionState>(recurringControllerProvider, (prev, next) {
      if (!mounted) return;
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.expense,
          ),
        );
      } else if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }
    });

    final rulesAsync = ref.watch(recurringRulesStreamProvider);
    final allTransactions =
        ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
    final monthlyIncomeCents =
        ref.watch(monthlyEstimatedRecurringIncomeCentsProvider);
    final monthlyExpenseCents =
        ref.watch(monthlyEstimatedRecurringExpenseCentsProvider);
    final categoriesById = ref.watch(categoriesByIdProvider);
    final accountsById = ref.watch(accountsByIdProvider);
    final cardsById = ref.watch(creditCardsByIdProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final isCompact = MediaQuery.of(context).size.width < 680;
    final actionLoading = ref.watch(recurringControllerProvider).isLoading;

    final txByRule = <String, List<TransactionEntity>>{};
    for (final tx in allTransactions) {
      final recId = tx.recurringId;
      if (recId != null && recId.isNotEmpty) {
        txByRule.putIfAbsent(recId, () => <TransactionEntity>[]).add(tx);
      }
    }
    for (final list in txByRule.values) {
      list.sort((a, b) => a.competencyDate.compareTo(b.competencyDate));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas Recorrentes'),
        actions: [
          if (isCompact)
            IconButton(
              tooltip: 'Sincronizar ocorrências',
              onPressed: actionLoading
                  ? null
                  : () =>
                      ref.read(recurringControllerProvider.notifier).syncNow(),
              icon: const Icon(Icons.sync_rounded),
            )
          else
            OutlinedButton.icon(
              onPressed: actionLoading
                  ? null
                  : () =>
                      ref.read(recurringControllerProvider.notifier).syncNow(),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sincronizar'),
            ),
          const SizedBox(width: 6),
          if (isCompact)
            IconButton(
              tooltip: 'Nova recorrência',
              onPressed: () => showRecurringRuleFormDialog(context),
              icon: const Icon(Icons.add_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showRecurringRuleFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova recorrência'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar recorrências',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(recurringRulesStreamProvider),
        ),
        data: (rules) {
          final activeCount =
              rules.where((r) => r.status == RecurringStatus.active).length;
          final pausedCount =
              rules.where((r) => r.status == RecurringStatus.paused).length;

          final visible = switch (_statusFilter) {
            'active' =>
              rules.where((r) => r.status == RecurringStatus.active).toList(),
            'paused' =>
              rules.where((r) => r.status == RecurringStatus.paused).toList(),
            _ => rules,
          };

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 14,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _SummaryStat(
                            label: 'Regras Ativas',
                            value: '$activeCount',
                            color: AppColors.primaryLight,
                          ),
                          _SummaryStat(
                            label: 'Pausadas',
                            value: '$pausedCount',
                            color: AppColors.warning,
                          ),
                          _SummaryStat(
                            label: 'Receitas Fixas / Mês',
                            value: CurrencyFormatter.formatCents(
                              monthlyIncomeCents,
                              locale: locale,
                              currencyCode: currency,
                            ),
                            color: AppColors.income,
                          ),
                          _SummaryStat(
                            label: 'Despesas Fixas / Mês',
                            value: CurrencyFormatter.formatCents(
                              monthlyExpenseCents,
                              locale: locale,
                              currencyCode: currency,
                            ),
                            color: AppColors.expense,
                          ),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: MaterialStatePropertyAll(
                                EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'active',
                                label: Text(
                                  'Ativas',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                              ButtonSegment(
                                value: 'paused',
                                label: Text(
                                  'Pausadas',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                              ButtonSegment(
                                value: 'all',
                                label: Text(
                                  'Todas',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                            selected: {_statusFilter},
                            onSelectionChanged: (sel) =>
                                setState(() => _statusFilter = sel.first),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    SizedBox(
                      height: 320,
                      child: EmptyStateView(
                        icon: Icons.repeat_rounded,
                        title: 'Nenhuma recorrência neste filtro',
                        description:
                            'Cadastre salários, aluguel, assinaturas e contas fixas para gerar ocorrências futuras sem duplicidades.',
                        actionLabel: 'Nova recorrência',
                        onAction: () => showRecurringRuleFormDialog(context),
                      ),
                    )
                  else
                    for (final rule in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecurringRuleCard(
                          rule: rule,
                          occurrences: txByRule[rule.id] ?? const [],
                          categoryName:
                              categoriesById[rule.categoryId]?.name ?? 'Categoria',
                          targetLabel: rule.isCardTarget
                              ? 'Cartão: ${cardsById[rule.cardId!]?.name ?? 'Cartão'}'
                              : 'Conta: ${rule.accountId != null ? (accountsById[rule.accountId!]?.name ?? 'Conta') : 'Conta'}',
                          locale: locale,
                          currency: currency,
                          onEditRule: () => showRecurringRuleFormDialog(
                            context,
                            existing: rule,
                          ),
                          onChangeStatus: (nextStatus) => ref
                              .read(recurringControllerProvider.notifier)
                              .setStatus(ruleId: rule.id, status: nextStatus),
                          onDeleteRule: () => _confirmDeleteRule(rule),
                          onEditOccurrence: _editSingleOccurrence,
                          onSettleOccurrence: (tx) => ref
                              .read(transactionControllerProvider.notifier)
                              .markAsSettled(tx.id),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RecurringRuleCard extends StatelessWidget {
  const _RecurringRuleCard({
    required this.rule,
    required this.occurrences,
    required this.categoryName,
    required this.targetLabel,
    required this.locale,
    required this.currency,
    required this.onEditRule,
    required this.onChangeStatus,
    required this.onDeleteRule,
    required this.onEditOccurrence,
    required this.onSettleOccurrence,
  });

  final RecurringRuleEntity rule;
  final List<TransactionEntity> occurrences;
  final String categoryName;
  final String targetLabel;
  final String locale;
  final String currency;
  final VoidCallback onEditRule;
  final ValueChanged<RecurringStatus> onChangeStatus;
  final VoidCallback onDeleteRule;
  final ValueChanged<TransactionEntity> onEditOccurrence;
  final ValueChanged<TransactionEntity> onSettleOccurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = rule.kind == RecurringKind.income;
    final kindColor = isIncome ? AppColors.income : AppColors.expense;
    final statusColor = switch (rule.status) {
      RecurringStatus.active => AppColors.primaryLight,
      RecurringStatus.paused => AppColors.warning,
      RecurringStatus.canceled => AppColors.expense,
    };

    final nextDate =
        RecurringScheduleCalculator.nextScheduledDateFrom(rule, DateTime.now());

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: CircleAvatar(
          backgroundColor: kindColor.withOpacity(0.14),
          foregroundColor: kindColor,
          child: Icon(
            isIncome ? Icons.trending_up_rounded : Icons.repeat_rounded,
          ),
        ),
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              rule.description,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            StatusBadge(label: rule.status.label, color: statusColor),
            if (rule.isVariableAmount)
              const StatusBadge(label: 'Variável', color: AppColors.transfer),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              [
                rule.frequencySummary,
                categoryName,
                targetLabel,
                if (nextDate != null)
                  'Próx.: ${DateFormatter.shortDate(nextDate)}',
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.formatCents(
                rule.amountCents,
                locale: locale,
                currencyCode: currency,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: kindColor,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEditRule();
                break;
              case 'pause':
                onChangeStatus(RecurringStatus.paused);
                break;
              case 'resume':
                onChangeStatus(RecurringStatus.active);
                break;
              case 'cancel':
                onChangeStatus(RecurringStatus.canceled);
                break;
              case 'delete':
                onDeleteRule();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Editar série'),
            ),
            if (rule.status == RecurringStatus.active)
              const PopupMenuItem(
                value: 'pause',
                child: Text('Pausar recorrência'),
              )
            else if (rule.status == RecurringStatus.paused)
              const PopupMenuItem(
                value: 'resume',
                child: Text('Retomar recorrência'),
              ),
            if (rule.status != RecurringStatus.canceled)
              const PopupMenuItem(
                value: 'cancel',
                child: Text('Cancelar recorrência'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Excluir regra',
                style: TextStyle(color: AppColors.expense),
              ),
            ),
          ],
        ),
        children: [
          const Divider(),
          if (occurrences.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Nenhuma ocorrência gerada ainda para esta regra.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            for (final tx in occurrences.reversed.take(12))
              Builder(
                builder: (context) {
                  final effStatus = tx.effectiveStatus();
                  final badgeColor = switch (effStatus) {
                    TransactionStatus.paid ||
                    TransactionStatus.received =>
                      AppColors.income,
                    TransactionStatus.overdue => AppColors.expense,
                    _ => AppColors.warning,
                  };
                  final canSettle = !effStatus.isSettled &&
                      (tx.kind == TransactionKind.income ||
                          tx.kind == TransactionKind.expense);
                  final canEditIndividual = tx.kind == TransactionKind.income ||
                      tx.kind == TransactionKind.expense ||
                      (tx.kind == TransactionKind.cardPurchase &&
                          !tx.status.isSettled);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    DateFormatter.shortDate(tx.competencyDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: effStatus.label,
                                    color: badgeColor,
                                  ),
                                ],
                              ),
                              if (tx.description != rule.description)
                                Text(
                                  tx.description,
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.formatCents(
                            tx.amountCents,
                            locale: locale,
                            currencyCode: currency,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (canEditIndividual)
                          IconButton(
                            tooltip: 'Editar apenas esta ocorrência',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () => onEditOccurrence(tx),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                        if (canSettle)
                          IconButton(
                            tooltip: 'Dar baixa na ocorrência',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () => onSettleOccurrence(tx),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.income,
                              size: 19,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
