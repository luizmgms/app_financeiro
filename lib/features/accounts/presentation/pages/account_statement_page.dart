import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../shared/models/date_period.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/controllers/transaction_controller.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_filter.dart';
import '../../../transactions/presentation/widgets/transaction_form_dialog.dart';
import '../../../transactions/presentation/widgets/transaction_list_tile.dart';
import '../../application/providers/account_providers.dart';
import '../widgets/account_form_dialog.dart';
import '../widgets/transfer_form_dialog.dart';

/// Tela de extrato filtrado por conta financeira.
class AccountStatementPage extends ConsumerStatefulWidget {
  const AccountStatementPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountStatementPage> createState() =>
      _AccountStatementPageState();
}

class _AccountStatementPageState extends ConsumerState<AccountStatementPage> {
  DatePeriod _period = DatePeriod.fromType(DatePeriodType.thisMonth);
  TransactionStatusFilter _statusFilter = TransactionStatusFilter.all;
  String _searchQuery = '';

  Future<void> _selectPeriod(DatePeriodType type) async {
    if (type != DatePeriodType.custom) {
      setState(() => _period = DatePeriod.fromType(type));
      return;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _period.start, end: _period.end),
    );
    if (picked != null && mounted) {
      setState(() {
        _period = DatePeriod(
          type: DatePeriodType.custom,
          start: picked.start,
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
            999,
          ),
        );
      });
    }
  }

  Future<void> _confirmDelete(TransactionEntity tx) async {
    final isTransfer = tx.kind == TransactionKind.transfer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isTransfer ? 'Excluir transferência' : 'Excluir lançamento'),
        content: Text(
          isTransfer
              ? 'Esta transferência será removida das duas contas e os saldos serão revertidos.'
              : 'Deseja excluir "${tx.description}"? Se já estiver liquidada, o saldo da conta será recalculado.',
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

    if (confirmed == true && mounted) {
      await ref
          .read(transactionControllerProvider.notifier)
          .deleteTransaction(tx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsMap = ref.watch(accountsByIdProvider);
    final account = accountsMap[widget.accountId];
    final categoriesMap = ref.watch(categoriesByIdProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final theme = Theme.of(context);

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extrato da conta')),
        body: const EmptyStateView(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Conta não encontrada',
          description: 'Esta conta foi removida ou não está mais disponível.',
        ),
      );
    }

    final accent = ColorUtils.fromHex(account.colorHex);
    final filter = TransactionFilter(
      period: _period,
      accountId: account.id,
      statusFilter: _statusFilter,
      searchQuery: _searchQuery,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            tooltip: 'Editar conta',
            onPressed: () => showAccountFormDialog(context, existing: account),
            icon: const Icon(Icons.edit_outlined),
          ),
          if (account.isActive) ...[
            IconButton(
              tooltip: 'Transferir',
              onPressed: () => showTransferFormDialog(
                context,
                initialSourceAccountId: account.id,
              ),
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
            IconButton(
              tooltip: 'Novo lançamento',
              onPressed: () => showTransactionFormDialog(
                context,
                initialAccountId: account.id,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                IconCatalog.resolve(
                                  account.iconName,
                                  fallback: Icons.account_balance_rounded,
                                ),
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.institution.isNotEmpty
                                      ? '${account.type.label} • ${account.institution}'
                                      : account.type.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatCents(
                                    account.currentBalanceCents,
                                    locale: locale,
                                    currencyCode: currency,
                                  ),
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: account.currentBalanceCents >= 0
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!account.isActive)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: StatusBadge(
                                  label: 'Arquivada',
                                  color: AppColors.warning,
                                ),
                              ),
                            Text(
                              'Saldo inicial: ${CurrencyFormatter.formatCents(account.initialBalanceCents, locale: locale, currencyCode: currency)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Aberta em ${DateFormatter.shortDate(account.openedAt, locale: locale)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Filtrar extrato por descrição ou observação...',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final type in DatePeriodType.values)
                          ChoiceChip(
                            label: Text(type.label),
                            selected: _period.type == type,
                            onSelected: (_) => _selectPeriod(type),
                          ),
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<TransactionStatusFilter>(
                            value: _statusFilter,
                            isExpanded: true,
                            isDense: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              for (final item in TransactionStatusFilter.values)
                                DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _statusFilter = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: transactionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => EmptyStateView(
                    icon: Icons.error_outline_rounded,
                    title: 'Erro ao carregar extrato',
                    description: error.toString(),
                  ),
                  data: (allTransactions) {
                    final filtered = allTransactions
                        .where(filter.matches)
                        .toList(growable: false);

                    if (filtered.isEmpty) {
                      return EmptyStateView(
                        icon: Icons.receipt_long_outlined,
                        title: 'Nenhuma movimentação neste período',
                        description:
                            'Registre uma receita, despesa ou transferência vinculada a esta conta.',
                        actionLabel: account.isActive ? 'Novo lançamento' : null,
                        onAction: account.isActive
                            ? () => showTransactionFormDialog(
                                  context,
                                  initialAccountId: account.id,
                                )
                            : null,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        return TransactionListTile(
                          transaction: tx,
                          category: tx.categoryId == null
                              ? null
                              : categoriesMap[tx.categoryId!],
                          account: account,
                          counterpartyAccount: tx.destinationAccountId == null
                              ? null
                              : accountsMap[tx.destinationAccountId!],
                          locale: locale,
                          currencyCode: currency,
                          onMarkAsSettled: () => ref
                              .read(transactionControllerProvider.notifier)
                              .markAsSettled(tx.id),
                          onEdit: () =>
                              showTransactionFormDialog(context, existing: tx),
                          onDuplicate: () => showTransactionFormDialog(
                            context,
                            duplicateFrom: tx,
                          ),
                          onDelete: () => _confirmDelete(tx),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
