import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../application/controllers/credit_card_controller.dart';
import '../../application/providers/credit_card_providers.dart';
import '../../domain/entities/credit_card_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../widgets/card_purchase_form_dialog.dart';
import '../widgets/credit_card_form_dialog.dart';
import '../widgets/pay_invoice_dialog.dart';

/// Tela de gerenciamento de cartões de crédito, limites, ciclos de fatura e compras.
class CreditCardsPage extends ConsumerStatefulWidget {
  const CreditCardsPage({super.key});

  @override
  ConsumerState<CreditCardsPage> createState() => _CreditCardsPageState();
}

class _CreditCardsPageState extends ConsumerState<CreditCardsPage> {
  bool _showArchived = false;
  String? _selectedCardId;
  String? _selectedInvoiceId;

  Future<void> _confirmDeleteCard(CreditCardEntity card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cartão'),
        content: Text(
          'Deseja excluir o cartão "${card.name}"? '
          'Se houver compras ou faturas vinculadas, recomendamos arquivá-lo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref
        .read(creditCardControllerProvider.notifier)
        .deleteCard(card.id);
  }

  Future<void> _confirmRefundPurchase(TransactionEntity tx) async {
    if (tx.kind == TransactionKind.cardRefund) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover estorno avulso'),
          content: Text(
            'Deseja remover o estorno "${tx.description}"? '
            'O valor será readicionado ao total da fatura e ao limite utilizado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover estorno'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref
          .read(creditCardControllerProvider.notifier)
          .refundOrCancelCardPurchase(transactionId: tx.id);
      return;
    }

    final isInstallment =
        tx.installmentPlanId != null && (tx.totalInstallments ?? 1) > 1;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estornar compra no cartão'),
        content: Text(
          isInstallment
              ? 'Deseja estornar apenas esta parcela (${tx.installmentNumber}/${tx.totalInstallments}) de "${tx.description}" ou cancelar todas as parcelas em aberto do parcelamento?'
              : 'Deseja estornar a compra "${tx.description}" e recompor o limite do cartão?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Voltar'),
          ),
          if (isInstallment)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop('single'),
              child: const Text('Apenas esta parcela'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () =>
                Navigator.of(context).pop(isInstallment ? 'plan' : 'single'),
            child: Text(
              isInstallment ? 'Estornar parcelamento' : 'Estornar compra',
            ),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;
    await ref
        .read(creditCardControllerProvider.notifier)
        .refundOrCancelCardPurchase(
          transactionId: tx.id,
          cancelEntirePlan: choice == 'plan',
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

    final cardsAsync = ref.watch(creditCardsStreamProvider);
    final activeCards = ref.watch(activeCreditCardsProvider);
    final totalLimitCents = ref.watch(totalCreditLimitCentsProvider);
    final totalUsedCents = ref.watch(totalUsedLimitCentsProvider);
    final totalAvailableCents = ref.watch(totalAvailableLimitCentsProvider);
    final totalOpenInvoicesCents =
        ref.watch(totalOpenInvoicesAmountCentsProvider);
    final invoicesByCard = ref.watch(invoicesByCardProvider);
    final allTransactions =
        ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
    final accountsById = ref.watch(accountsByIdProvider);
    final categoriesById = ref.watch(categoriesByIdProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final isCompact = MediaQuery.of(context).size.width < 680;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões de Crédito'),
        actions: [
          if (isCompact)
            IconButton(
              tooltip: 'Parcelamentos',
              onPressed: () => context.go(AppRoutes.installments),
              icon: const Icon(Icons.view_week_outlined),
            )
          else
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.installments),
              icon: const Icon(Icons.calendar_view_month_rounded, size: 18),
              label: const Text('Parcelamentos'),
            ),
          if (activeCards.isNotEmpty) ...[
            const SizedBox(width: 4),
            if (isCompact)
              IconButton(
                tooltip: 'Estorno avulso',
                onPressed: () => showCardPurchaseFormDialog(
                  context,
                  initialCardId: _selectedCardId,
                  startInRefundMode: true,
                ),
                icon: const Icon(Icons.replay_rounded),
              )
            else
              TextButton.icon(
                onPressed: () => showCardPurchaseFormDialog(
                  context,
                  initialCardId: _selectedCardId,
                  startInRefundMode: true,
                ),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Estorno avulso'),
              ),
            const SizedBox(width: 4),
            if (isCompact)
              IconButton(
                tooltip: 'Compra no cartão',
                onPressed: () => showCardPurchaseFormDialog(
                  context,
                  initialCardId: _selectedCardId,
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
              )
            else
              OutlinedButton.icon(
                onPressed: () => showCardPurchaseFormDialog(
                  context,
                  initialCardId: _selectedCardId,
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Compra no cartão'),
              ),
          ],
          const SizedBox(width: 6),
          if (isCompact)
            IconButton(
              tooltip: 'Novo cartão',
              onPressed: () => showCreditCardFormDialog(context),
              icon: const Icon(Icons.add_card_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showCreditCardFormDialog(context),
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text('Novo cartão'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar cartões',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(creditCardsStreamProvider),
        ),
        data: (cards) {
          final visibleCards = cards
              .where((card) => _showArchived || card.isActive)
              .toList(growable: false);

          if (_selectedCardId == null ||
              !visibleCards.any((c) => c.id == _selectedCardId)) {
            _selectedCardId =
                visibleCards.isNotEmpty ? visibleCards.first.id : null;
          }

          CreditCardEntity? selectedCard;
          if (_selectedCardId != null) {
            for (final card in visibleCards) {
              if (card.id == _selectedCardId) {
                selectedCard = card;
                break;
              }
            }
          }

          final cardInvoices = selectedCard != null
              ? (invoicesByCard[selectedCard.id] ?? const <InvoiceEntity>[])
              : const <InvoiceEntity>[];

          if (_selectedInvoiceId == null ||
              !cardInvoices.any((inv) => inv.id == _selectedInvoiceId)) {
            if (cardInvoices.isNotEmpty) {
              final openOrClosed = cardInvoices.where(
                (inv) => inv.status != InvoiceStatus.paid,
              );
              _selectedInvoiceId = openOrClosed.isNotEmpty
                  ? openOrClosed.last.id
                  : cardInvoices.first.id;
            } else {
              _selectedInvoiceId = null;
            }
          }

          InvoiceEntity? selectedInvoice;
          if (_selectedInvoiceId != null) {
            for (final inv in cardInvoices) {
              if (inv.id == _selectedInvoiceId) {
                selectedInvoice = inv;
                break;
              }
            }
          }

          final invoicePurchases = selectedInvoice != null
              ? allTransactions
                  .where(
                    (tx) =>
                        (tx.kind == TransactionKind.cardPurchase ||
                            tx.kind == TransactionKind.cardRefund) &&
                        tx.invoiceId == selectedInvoice!.id,
                  )
                  .toList(growable: false)
              : const <TransactionEntity>[];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1020),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _SummaryHeaderCard(
                    totalLimitCents: totalLimitCents,
                    totalUsedCents: totalUsedCents,
                    totalAvailableCents: totalAvailableCents,
                    totalOpenInvoicesCents: totalOpenInvoicesCents,
                    showArchived: _showArchived,
                    onToggleArchived: (value) =>
                        setState(() => _showArchived = value),
                    locale: locale,
                    currency: currency,
                  ),
                  const SizedBox(height: 16),
                  if (visibleCards.isEmpty)
                    SizedBox(
                      height: 320,
                      child: EmptyStateView(
                        icon: Icons.credit_card_outlined,
                        title: 'Nenhum cartão cadastrado',
                        description:
                            'Cadastre seus cartões para controlar limites, fechamento automático de faturas e compras parceladas.',
                        actionLabel: 'Cadastrar primeiro cartão',
                        onAction: () => showCreditCardFormDialog(context),
                      ),
                    )
                  else ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isTwoColumn = constraints.maxWidth >= 720;
                        final cardWidth = isTwoColumn
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final card in visibleCards)
                              SizedBox(
                                width: cardWidth,
                                child: _CreditCardTile(
                                  card: card,
                                  isSelected: card.id == selectedCard?.id,
                                  paymentAccountName:
                                      card.paymentAccountId != null
                                          ? accountsById[card.paymentAccountId!]
                                              ?.name
                                          : null,
                                  locale: locale,
                                  currency: currency,
                                  onSelect: () => setState(() {
                                    _selectedCardId = card.id;
                                    _selectedInvoiceId = null;
                                  }),
                                  onNewPurchase: card.isActive
                                      ? () => showCardPurchaseFormDialog(
                                            context,
                                            initialCardId: card.id,
                                            initialInstallments:
                                                card.defaultInstallments,
                                          )
                                      : null,
                                  onNewRefund: card.isActive
                                      ? () => showCardPurchaseFormDialog(
                                            context,
                                            initialCardId: card.id,
                                            startInRefundMode: true,
                                          )
                                      : null,
                                  onEdit: () => showCreditCardFormDialog(
                                    context,
                                    existing: card,
                                  ),
                                  onToggleArchive: () => ref
                                      .read(
                                          creditCardControllerProvider.notifier)
                                      .setArchived(
                                        cardId: card.id,
                                        archived: card.isActive,
                                      ),
                                  onDelete: () => _confirmDeleteCard(card),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (selectedCard != null) ...[
                      const SizedBox(height: 24),
                      _InvoicesSection(
                        card: selectedCard,
                        invoices: cardInvoices,
                        selectedInvoice: selectedInvoice,
                        purchases: invoicePurchases,
                        categoriesById: categoriesById,
                        locale: locale,
                        currency: currency,
                        onSelectInvoice: (id) =>
                            setState(() => _selectedInvoiceId = id),
                        onNewPurchase: selectedCard.isActive
                            ? () => showCardPurchaseFormDialog(
                                  context,
                                  initialCardId: selectedCard!.id,
                                  initialInstallments:
                                      selectedCard.defaultInstallments,
                                )
                            : null,
                        onNewRefund: selectedCard.isActive
                            ? () => showCardPurchaseFormDialog(
                                  context,
                                  initialCardId: selectedCard!.id,
                                  startInRefundMode: true,
                                )
                            : null,
                        onPayInvoice: selectedInvoice != null &&
                                selectedInvoice.status != InvoiceStatus.paid &&
                                selectedInvoice.remainingAmountCents > 0
                            ? () => showPayInvoiceDialog(
                                  context,
                                  invoice: selectedInvoice!,
                                  card: selectedCard!,
                                )
                            : null,
                        onRefundPurchase: _confirmRefundPurchase,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryHeaderCard extends StatelessWidget {
  const _SummaryHeaderCard({
    required this.totalLimitCents,
    required this.totalUsedCents,
    required this.totalAvailableCents,
    required this.totalOpenInvoicesCents,
    required this.showArchived,
    required this.onToggleArchived,
    required this.locale,
    required this.currency,
  });

  final int totalLimitCents;
  final int totalUsedCents;
  final int totalAvailableCents;
  final int totalOpenInvoicesCents;
  final bool showArchived;
  final ValueChanged<bool> onToggleArchived;
  final String locale;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usageRatio = totalLimitCents <= 0
        ? 0.0
        : (totalUsedCents / totalLimitCents).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 14,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetricItem(
                  label: 'Limite Disponível',
                  value: CurrencyFormatter.formatCents(
                    totalAvailableCents,
                    locale: locale,
                    currencyCode: currency,
                  ),
                  color: AppColors.income,
                  isHighlighted: true,
                ),
                _MetricItem(
                  label: 'Limite Utilizado',
                  value: CurrencyFormatter.formatCents(
                    totalUsedCents,
                    locale: locale,
                    currencyCode: currency,
                  ),
                  color: AppColors.warning,
                ),
                _MetricItem(
                  label: 'Limite Total',
                  value: CurrencyFormatter.formatCents(
                    totalLimitCents,
                    locale: locale,
                    currencyCode: currency,
                  ),
                  color: theme.colorScheme.onSurface,
                ),
                _MetricItem(
                  label: 'Faturas em Aberto',
                  value: CurrencyFormatter.formatCents(
                    totalOpenInvoicesCents,
                    locale: locale,
                    currencyCode: currency,
                  ),
                  color: AppColors.expense,
                ),
                FilterChip(
                  label: const Text('Mostrar arquivados'),
                  selected: showArchived,
                  onSelected: onToggleArchived,
                ),
              ],
            ),
            if (totalLimitCents > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usageRatio,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  color: usageRatio > 0.85
                      ? AppColors.expense
                      : (usageRatio > 0.6
                          ? AppColors.warning
                          : AppColors.primaryLight),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.color,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool isHighlighted;

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
          style: (isHighlighted
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

class _CreditCardTile extends StatelessWidget {
  const _CreditCardTile({
    required this.card,
    required this.isSelected,
    required this.paymentAccountName,
    required this.locale,
    required this.currency,
    required this.onSelect,
    required this.onNewPurchase,
    required this.onNewRefund,
    required this.onEdit,
    required this.onToggleArchive,
    required this.onDelete,
  });

  final CreditCardEntity card;
  final bool isSelected;
  final String? paymentAccountName;
  final String locale;
  final String currency;
  final VoidCallback onSelect;
  final VoidCallback? onNewPurchase;
  final VoidCallback? onNewRefund;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ColorUtils.fromHex(card.colorHex);
    final ratio = card.usageRatio;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? accent : Colors.transparent,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accent.withOpacity(0.14),
                    foregroundColor: accent,
                    child: const Icon(Icons.credit_card_rounded, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              card.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            StatusBadge(
                              label: card.brand.label,
                              color: accent,
                            ),
                            if (!card.isActive)
                              const StatusBadge(
                                label: 'Arquivado',
                                color: AppColors.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (card.institution.isNotEmpty) card.institution,
                            'Fecha dia ${card.closingDay}',
                            'Vence dia ${card.dueDay}',
                          ].join(' • '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'purchase':
                          onNewPurchase?.call();
                          break;
                        case 'refund':
                          onNewRefund?.call();
                          break;
                        case 'edit':
                          onEdit();
                          break;
                        case 'archive':
                          onToggleArchive();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (onNewPurchase != null)
                        const PopupMenuItem(
                          value: 'purchase',
                          child: ListTile(
                            leading: Icon(Icons.shopping_bag_outlined),
                            title: Text('Nova compra'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (onNewRefund != null)
                        const PopupMenuItem(
                          value: 'refund',
                          child: ListTile(
                            leading: Icon(
                              Icons.replay_rounded,
                              color: AppColors.income,
                            ),
                            title: Text('Estorno avulso'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar cartão'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(
                            card.isActive
                                ? Icons.archive_outlined
                                : Icons.unarchive_outlined,
                          ),
                          title: Text(
                            card.isActive
                                ? 'Arquivar cartão'
                                : 'Reativar cartão',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.expense,
                          ),
                          title: Text(
                            'Excluir cartão',
                            style: TextStyle(color: AppColors.expense),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor:
                      theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  color: ratio > 0.85
                      ? AppColors.expense
                      : (ratio > 0.6 ? AppColors.warning : accent),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Utilizado', style: theme.textTheme.bodySmall),
                      Text(
                        CurrencyFormatter.formatCents(
                          card.usedLimitCents,
                          locale: locale,
                          currencyCode: currency,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Disponível', style: theme.textTheme.bodySmall),
                      Text(
                        CurrencyFormatter.formatCents(
                          card.availableLimitCents,
                          locale: locale,
                          currencyCode: currency,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (paymentAccountName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Conta padrão: $paymentAccountName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoicesSection extends StatelessWidget {
  const _InvoicesSection({
    required this.card,
    required this.invoices,
    required this.selectedInvoice,
    required this.purchases,
    required this.categoriesById,
    required this.locale,
    required this.currency,
    required this.onSelectInvoice,
    required this.onNewPurchase,
    required this.onNewRefund,
    required this.onPayInvoice,
    required this.onRefundPurchase,
  });

  final CreditCardEntity card;
  final List<InvoiceEntity> invoices;
  final InvoiceEntity? selectedInvoice;
  final List<TransactionEntity> purchases;
  final Map<String, dynamic> categoriesById;
  final String locale;
  final String currency;
  final ValueChanged<String> onSelectInvoice;
  final VoidCallback? onNewPurchase;
  final VoidCallback? onNewRefund;
  final VoidCallback? onPayInvoice;
  final ValueChanged<TransactionEntity> onRefundPurchase;

  Color _statusColor(InvoiceStatus status) {
    return switch (status) {
      InvoiceStatus.open => AppColors.transfer,
      InvoiceStatus.closed => AppColors.warning,
      InvoiceStatus.paid => AppColors.income,
      InvoiceStatus.overdue => AppColors.expense,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Faturas • ${card.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    if (onNewRefund != null)
                      TextButton.icon(
                        onPressed: onNewRefund,
                        icon: const Icon(
                          Icons.replay_rounded,
                          size: 18,
                          color: AppColors.income,
                        ),
                        label: const Text(
                          'Estorno avulso',
                          style: TextStyle(color: AppColors.income),
                        ),
                      ),
                    if (onNewPurchase != null)
                      TextButton.icon(
                        onPressed: onNewPurchase,
                        icon: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 18,
                        ),
                        label: const Text('Lançar compra'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (invoices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma fatura gerada para este cartão ainda.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ao registrar compras no cartão, as faturas serão abertas automaticamente conforme o dia de fechamento (${card.closingDay}).',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final inv in invoices) ...[
                      ChoiceChip(
                        label: Text(
                          '${inv.referenceLabel} • ${CurrencyFormatter.formatCents(inv.totalAmountCents, locale: locale, currencyCode: currency)}',
                        ),
                        selected: inv.id == selectedInvoice?.id,
                        onSelected: (_) => onSelectInvoice(inv.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (selectedInvoice != null) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final effectiveStatus =
                        selectedInvoice!.effectiveStatus(now);
                    final statusColor = _statusColor(effectiveStatus);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Fatura ${selectedInvoice!.referenceLabel}',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: effectiveStatus.label,
                                    color: statusColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fechamento: ${DateFormatter.shortDate(selectedInvoice!.closingDate)} • Vencimento: ${DateFormatter.shortDate(selectedInvoice!.dueDate)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 14,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total da fatura',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    CurrencyFormatter.formatCents(
                                      selectedInvoice!.totalAmountCents,
                                      locale: locale,
                                      currencyCode: currency,
                                    ),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: effectiveStatus ==
                                              InvoiceStatus.paid
                                          ? AppColors.income
                                          : AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                              if (onPayInvoice != null)
                                FilledButton.icon(
                                  onPressed: onPayInvoice,
                                  icon: const Icon(
                                    Icons.payments_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Pagar fatura'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (purchases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nenhuma compra ativa nesta fatura.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final tx in purchases)
                        Builder(
                          builder: (context) {
                            final isRefund =
                                tx.kind == TransactionKind.cardRefund;
                            final tileAccent = isRefund
                                ? AppColors.income
                                : AppColors.primaryLight;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        tileAccent.withOpacity(0.12),
                                    foregroundColor: tileAccent,
                                    child: Icon(
                                      isRefund
                                          ? Icons.replay_rounded
                                          : IconCatalog.resolve(
                                              categoriesById[tx.categoryId]
                                                  ?.iconName,
                                              fallback:
                                                  Icons.shopping_bag_outlined,
                                            ),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tx.description,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${isRefund ? '- ' : ''}${CurrencyFormatter.formatCents(tx.amountCents, locale: locale, currencyCode: currency)}',
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: isRefund
                                                    ? AppColors.income
                                                    : null,
                                              ),
                                            ),
                                            if (!tx.status.isSettled &&
                                                selectedInvoice!.status !=
                                                    InvoiceStatus.paid)
                                              IconButton(
                                                tooltip: isRefund
                                                    ? 'Remover estorno'
                                                    : 'Estornar compra',
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32,
                                                ),
                                                onPressed: () =>
                                                    onRefundPurchase(tx),
                                                icon: Icon(
                                                  isRefund
                                                      ? Icons
                                                          .delete_outline_rounded
                                                      : Icons.undo_rounded,
                                                  size: 18,
                                                  color: AppColors.expense,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              [
                                                DateFormatter.shortDate(
                                                  tx.competencyDate,
                                                ),
                                                categoriesById[tx.categoryId]
                                                        ?.name ??
                                                    (isRefund
                                                        ? 'Crédito'
                                                        : 'Despesa'),
                                              ].join(' • '),
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            if (isRefund)
                                              const StatusBadge(
                                                label: 'Estorno avulso',
                                                color: AppColors.income,
                                              )
                                            else if ((tx.totalInstallments ??
                                                    1) >
                                                1)
                                              StatusBadge(
                                                label:
                                                    '${tx.installmentNumber}/${tx.totalInstallments}',
                                                color: AppColors.primaryLight,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
