import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../credit_cards/application/controllers/credit_card_controller.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../../credit_cards/presentation/widgets/card_purchase_form_dialog.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/controllers/transaction_controller.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/installment_plan_entity.dart';

/// Tela dedicada ao acompanhamento de compras parceladas (no cartão ou em conta),
/// progresso das parcelas e saldo futuro comprometido.
class InstallmentsPage extends ConsumerStatefulWidget {
  const InstallmentsPage({super.key});

  @override
  ConsumerState<InstallmentsPage> createState() => _InstallmentsPageState();
}

class _InstallmentsPageState extends ConsumerState<InstallmentsPage> {
  String _statusFilter = 'active';

  Future<void> _confirmCancelCardPlan(
    InstallmentPlanEntity plan,
    TransactionEntity firstOpenSlice,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estornar parcelamento'),
        content: Text(
          'Deseja estornar e cancelar todas as parcelas em aberto de "${plan.description}"? '
          'O limite correspondente será recomposto no cartão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Estornar parcelas em aberto'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref
        .read(creditCardControllerProvider.notifier)
        .refundOrCancelCardPurchase(
          transactionId: firstOpenSlice.id,
          cancelEntirePlan: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CreditCardActionState>(creditCardControllerProvider,
        (prev, next) {
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

    final plansAsync = ref.watch(installmentPlansStreamProvider);
    final allTransactions =
        ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
    final cardsById = ref.watch(creditCardsByIdProvider);
    final accountsById = ref.watch(accountsByIdProvider);
    final categoriesById = ref.watch(categoriesByIdProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final isCompact = MediaQuery.of(context).size.width < 680;

    final txByPlanId = <String, List<TransactionEntity>>{};
    for (final tx in allTransactions) {
      final planId = tx.installmentPlanId;
      if (planId != null && planId.isNotEmpty) {
        txByPlanId.putIfAbsent(planId, () => <TransactionEntity>[]).add(tx);
      }
    }
    for (final list in txByPlanId.values) {
      list.sort(
        (a, b) =>
            (a.installmentNumber ?? 0).compareTo(b.installmentNumber ?? 0),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcelamentos'),
        actions: [
          if (isCompact)
            IconButton(
              tooltip: 'Novo parcelamento',
              onPressed: () => showCardPurchaseFormDialog(
                context,
                initialInstallments: 2,
              ),
              icon: const Icon(Icons.add_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showCardPurchaseFormDialog(
                context,
                initialInstallments: 2,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Novo parcelamento'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar parcelamentos',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(installmentPlansStreamProvider),
        ),
        data: (plans) {
          var totalActiveCents = 0;
          var totalPaidCents = 0;
          var totalRemainingCents = 0;

          final enriched = <_EnrichedPlan>[];
          for (final plan in plans) {
            final slices = txByPlanId[plan.id] ?? const <TransactionEntity>[];
            final paidSlices =
                slices.where((tx) => tx.status.isSettled).toList();
            final pendingSlices =
                slices.where((tx) => !tx.status.isSettled).toList();

            final paidAmount =
                paidSlices.fold<int>(0, (sum, tx) => sum + tx.amountCents);
            final remainingAmount =
                pendingSlices.fold<int>(0, (sum, tx) => sum + tx.amountCents);

            final effectiveStatus = plan.status == InstallmentPlanStatus.canceled
                ? InstallmentPlanStatus.canceled
                : (pendingSlices.isEmpty && slices.isNotEmpty
                    ? InstallmentPlanStatus.completed
                    : InstallmentPlanStatus.active);

            if (effectiveStatus != InstallmentPlanStatus.canceled) {
              totalActiveCents += plan.totalAmountCents;
              totalPaidCents += paidAmount;
              totalRemainingCents += remainingAmount;
            }

            final matchesFilter = switch (_statusFilter) {
              'active' => effectiveStatus == InstallmentPlanStatus.active,
              'completed' => effectiveStatus == InstallmentPlanStatus.completed,
              _ => true,
            };

            if (matchesFilter) {
              enriched.add(
                _EnrichedPlan(
                  plan: plan,
                  slices: slices,
                  paidCount: paidSlices.length,
                  paidAmountCents: paidAmount,
                  remainingAmountCents: remainingAmount,
                  effectiveStatus: effectiveStatus,
                  nextPendingSlice:
                      pendingSlices.isNotEmpty ? pendingSlices.first : null,
                ),
              );
            }
          }

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
                          _PlanMetric(
                            label: 'Comprometido Futuro',
                            value: CurrencyFormatter.formatCents(
                              totalRemainingCents,
                              locale: locale,
                              currencyCode: currency,
                            ),
                            color: AppColors.expense,
                            highlighted: true,
                          ),
                          _PlanMetric(
                            label: 'Total Já Quitado',
                            value: CurrencyFormatter.formatCents(
                              totalPaidCents,
                              locale: locale,
                              currencyCode: currency,
                            ),
                            color: AppColors.income,
                          ),
                          _PlanMetric(
                            label: 'Volume Total Parcelado',
                            value: CurrencyFormatter.formatCents(
                              totalActiveCents,
                              locale: locale,
                              currencyCode: currency,
                            ),
                            color: Theme.of(context).colorScheme.onSurface,
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
                                  'Ativos',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                              ButtonSegment(
                                value: 'completed',
                                label: Text(
                                  'Concluídos',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                              ButtonSegment(
                                value: 'all',
                                label: Text(
                                  'Todos',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                            selected: {_statusFilter},
                            onSelectionChanged: (selection) => setState(
                              () => _statusFilter = selection.first,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (enriched.isEmpty)
                    SizedBox(
                      height: 320,
                      child: EmptyStateView(
                        icon: Icons.calendar_view_month_rounded,
                        title: 'Nenhum parcelamento encontrado',
                        description:
                            'Registre compras parceladas no cartão de crédito ou diretamente em conta para acompanhar o cronograma de parcelas.',
                        actionLabel: 'Novo parcelamento',
                        onAction: () => showCardPurchaseFormDialog(
                          context,
                          initialInstallments: 2,
                        ),
                      ),
                    )
                  else
                    for (final item in enriched)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InstallmentPlanCard(
                          item: item,
                          cardName: item.plan.cardId != null
                              ? cardsById[item.plan.cardId!]?.name
                              : null,
                          accountName: item.plan.accountId != null
                              ? accountsById[item.plan.accountId!]?.name
                              : null,
                          categoryName:
                              categoriesById[item.plan.categoryId]?.name ??
                                  'Despesa',
                          locale: locale,
                          currency: currency,
                          onSettleAccountSlice: (slice) => ref
                              .read(transactionControllerProvider.notifier)
                              .markAsSettled(slice.id),
                          onCancelCardPlan:
                              item.plan.isCardInstallment &&
                                      item.nextPendingSlice != null
                                  ? () => _confirmCancelCardPlan(
                                        item.plan,
                                        item.nextPendingSlice!,
                                      )
                                  : null,
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

class _EnrichedPlan {
  const _EnrichedPlan({
    required this.plan,
    required this.slices,
    required this.paidCount,
    required this.paidAmountCents,
    required this.remainingAmountCents,
    required this.effectiveStatus,
    this.nextPendingSlice,
  });

  final InstallmentPlanEntity plan;
  final List<TransactionEntity> slices;
  final int paidCount;
  final int paidAmountCents;
  final int remainingAmountCents;
  final InstallmentPlanStatus effectiveStatus;
  final TransactionEntity? nextPendingSlice;
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.label,
    required this.value,
    required this.color,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool highlighted;

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
          style: (highlighted
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.titleMedium)
              ?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InstallmentPlanCard extends StatelessWidget {
  const _InstallmentPlanCard({
    required this.item,
    required this.cardName,
    required this.accountName,
    required this.categoryName,
    required this.locale,
    required this.currency,
    required this.onSettleAccountSlice,
    required this.onCancelCardPlan,
  });

  final _EnrichedPlan item;
  final String? cardName;
  final String? accountName;
  final String categoryName;
  final String locale;
  final String currency;
  final ValueChanged<TransactionEntity> onSettleAccountSlice;
  final VoidCallback? onCancelCardPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = item.plan;
    final totalInstallments =
        plan.installmentCount <= 0 ? 1 : plan.installmentCount;
    final progress = (item.paidCount / totalInstallments).clamp(0.0, 1.0);

    final statusColor = switch (item.effectiveStatus) {
      InstallmentPlanStatus.active => AppColors.transfer,
      InstallmentPlanStatus.completed => AppColors.income,
      InstallmentPlanStatus.canceled => AppColors.warning,
    };

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight.withOpacity(0.14),
          foregroundColor: AppColors.primaryLight,
          child: Icon(
            plan.isCardInstallment
                ? Icons.credit_card_rounded
                : Icons.account_balance_wallet_outlined,
          ),
        ),
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              plan.description,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            StatusBadge(
              label: '${item.paidCount}/${plan.installmentCount} pagas',
              color: statusColor,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              [
                if (cardName != null) 'Cartão: $cardName',
                if (accountName != null) 'Conta: $accountName',
                categoryName,
                'Compra em ${DateFormatter.shortDate(plan.firstCompetencyDate)}',
                if (item.nextPendingSlice?.dueDate != null)
                  'Próx. venc.: ${DateFormatter.shortDate(item.nextPendingSlice!.dueDate!)}',
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor:
                    theme.colorScheme.surfaceVariant.withOpacity(0.5),
                color: statusColor,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.formatCents(
                plan.totalAmountCents,
                locale: locale,
                currencyCode: currency,
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Restam ${CurrencyFormatter.formatCents(item.remainingAmountCents, locale: locale, currencyCode: currency)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: item.remainingAmountCents > 0
                    ? AppColors.expense
                    : AppColors.income,
              ),
            ),
          ],
        ),
        children: [
          const Divider(),
          if (onCancelCardPlan != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancelCardPlan,
                icon: const Icon(
                  Icons.undo_rounded,
                  size: 18,
                  color: AppColors.expense,
                ),
                label: const Text(
                  'Estornar parcelas em aberto',
                  style: TextStyle(color: AppColors.expense),
                ),
              ),
            ),
          for (final slice in item.slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                              'Parcela ${slice.installmentNumber}/${slice.totalInstallments}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            StatusBadge(
                              label: slice.status.isSettled
                                  ? 'Quitada'
                                  : 'Em aberto',
                              color: slice.status.isSettled
                                  ? AppColors.income
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slice.dueDate != null
                              ? 'Vencimento: ${DateFormatter.shortDate(slice.dueDate!)}'
                              : 'Data: ${DateFormatter.shortDate(slice.competencyDate)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.formatCents(
                      slice.amountCents,
                      locale: locale,
                      currencyCode: currency,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (!slice.status.isSettled &&
                      slice.kind == TransactionKind.expense)
                    IconButton(
                      tooltip: 'Dar baixa na parcela',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => onSettleAccountSlice(slice),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.income,
                        size: 20,
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
