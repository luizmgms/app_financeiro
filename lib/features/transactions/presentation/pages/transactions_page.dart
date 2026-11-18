import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../shared/models/date_period.dart';
import '../../../../shared/widgets/summary_metric_card.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../accounts/presentation/widgets/transfer_form_dialog.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../application/controllers/transaction_controller.dart';
import '../../application/providers/transaction_providers.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import '../widgets/transaction_form_dialog.dart';
import '../widgets/transaction_list_tile.dart';

/// Tela principal de movimentações financeiras com lançamento rápido, filtros e anexos.
class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectPeriod(DatePeriodType type) async {
    final notifier = ref.read(transactionFilterProvider.notifier);
    if (type != DatePeriodType.custom) {
      notifier.setPeriod(DatePeriod.fromType(type));
      return;
    }

    final current = ref.read(transactionFilterProvider).period;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
    );
    if (picked != null && mounted) {
      notifier.setPeriod(
        DatePeriod(
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
        ),
      );
    }
  }

  Future<void> _confirmDelete(TransactionEntity tx) async {
    final isTransfer = tx.kind == TransactionKind.transfer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isTransfer ? 'Excluir transferência' : 'Excluir movimentação'),
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
    ref.listen<TransactionActionState>(transactionControllerProvider,
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

    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final filtered = ref.watch(filteredTransactionsProvider);
    final summary = ref.watch(filteredTransactionsSummaryProvider);
    final filter = ref.watch(transactionFilterProvider);
    final categories = ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
    final categoriesMap = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final accountsMap = ref.watch(accountsByIdProvider);
    final activeAccountsCount = ref.watch(activeAccountsProvider).length;
    final profile = ref.watch(userProfileProvider).valueOrNull;

    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final theme = Theme.of(context);

    final filterCategories = filter.kind == TransactionKind.income ||
            filter.kind == TransactionKind.expense
        ? categories
            .where((c) =>
                c.type.storageValue == filter.kind!.storageValue)
            .toList(growable: false)
        : categories;

    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimentações'),
        actions: [
          IconButton(
            tooltip: 'Categorias',
            onPressed: () => context.push(AppRoutes.categories),
            icon: const Icon(Icons.category_outlined),
          ),
          if (!isCompact && activeAccountsCount >= 2) ...[
            OutlinedButton.icon(
              onPressed: () => showTransferFormDialog(context),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Transferir'),
            ),
            const SizedBox(width: 8),
          ],
          if (isCompact)
            IconButton(
              tooltip: 'Nova movimentação',
              onPressed: () => showTransactionFormDialog(
                context,
                initialKind: TransactionKind.expense,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showTransactionFormDialog(
                context,
                initialKind: TransactionKind.expense,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Lançar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar movimentações',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(transactionsStreamProvider),
        ),
        data: (_) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => showTransactionFormDialog(
                                  context,
                                  initialKind: TransactionKind.income,
                                ),
                                icon: const Icon(
                                  Icons.trending_up_rounded,
                                  color: AppColors.income,
                                ),
                                label: const Text('Lançamento rápido: Receita'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => showTransactionFormDialog(
                                  context,
                                  initialKind: TransactionKind.expense,
                                ),
                                icon: const Icon(
                                  Icons.trending_down_rounded,
                                  color: AppColors.expense,
                                ),
                                label: const Text('Lançamento rápido: Despesa'),
                              ),
                              if (activeAccountsCount >= 2)
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      showTransferFormDialog(context),
                                  icon: const Icon(Icons.swap_horiz_rounded),
                                  label: const Text('Transferência'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 820
                                  ? 3
                                  : constraints.maxWidth >= 520
                                      ? 2
                                      : 1;
                              final itemWidth = (constraints.maxWidth -
                                      (12 * (columns - 1))) /
                                  columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: itemWidth,
                                    child: SummaryMetricCard(
                                      title: 'Receitas do filtro',
                                      valueText: CurrencyFormatter.formatCents(
                                        summary.totalIncomeCents,
                                        locale: locale,
                                        currencyCode: currency,
                                      ),
                                      subtitle:
                                          'Recebidas: ${CurrencyFormatter.formatCents(summary.receivedIncomeCents, locale: locale, currencyCode: currency)}',
                                      icon: Icons.trending_up_rounded,
                                      accentColor: AppColors.income,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: SummaryMetricCard(
                                      title: 'Despesas do filtro',
                                      valueText: CurrencyFormatter.formatCents(
                                        summary.totalExpenseCents,
                                        locale: locale,
                                        currencyCode: currency,
                                      ),
                                      subtitle:
                                          'Pagas: ${CurrencyFormatter.formatCents(summary.paidExpenseCents, locale: locale, currencyCode: currency)}',
                                      icon: Icons.trending_down_rounded,
                                      accentColor: AppColors.expense,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: SummaryMetricCard(
                                      title: 'Resultado do período',
                                      valueText: CurrencyFormatter.formatCents(
                                        summary.netResultCents,
                                        locale: locale,
                                        currencyCode: currency,
                                      ),
                                      subtitle:
                                          'Transferências não entram nos totais',
                                      icon: Icons.balance_rounded,
                                      accentColor: summary.netResultCents >= 0
                                          ? AppColors.primaryLight
                                          : AppColors.expense,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (value) => ref
                                        .read(transactionFilterProvider.notifier)
                                        .setSearchQuery(value),
                                    decoration: InputDecoration(
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      hintText:
                                          'Pesquisar por descrição ou observações...',
                                      isDense: true,
                                      suffixIcon:
                                          _searchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(
                                                    Icons.clear_rounded,
                                                  ),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    ref
                                                        .read(
                                                          transactionFilterProvider
                                                              .notifier,
                                                        )
                                                        .setSearchQuery('');
                                                  },
                                                )
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      for (final type in DatePeriodType.values)
                                        ChoiceChip(
                                          label: Text(type.label),
                                          selected: filter.period.type == type,
                                          onSelected: (_) =>
                                              _selectPeriod(type),
                                        ),
                                      Text(
                                        '${DateFormatter.shortDate(filter.period.start, locale: locale)} - '
                                        '${DateFormatter.shortDate(filter.period.end, locale: locale)}',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 170,
                                        child: DropdownButtonFormField<
                                            TransactionKind?>(
                                          value: filter.kind,
                                          isExpanded: true,
                                          isDense: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Tipo',
                                            isDense: true,
                                          ),
                                          items: const [
                                            DropdownMenuItem<TransactionKind?>(
                                              value: null,
                                              child: Text('Todos'),
                                            ),
                                            DropdownMenuItem<TransactionKind?>(
                                              value: TransactionKind.expense,
                                              child: Text('Despesas'),
                                            ),
                                            DropdownMenuItem<TransactionKind?>(
                                              value: TransactionKind.income,
                                              child: Text('Receitas'),
                                            ),
                                            DropdownMenuItem<TransactionKind?>(
                                              value: TransactionKind.transfer,
                                              child: Text('Transferências'),
                                            ),
                                          ],
                                          onChanged: (value) => ref
                                              .read(transactionFilterProvider
                                                  .notifier)
                                              .setKind(value),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 190,
                                        child: DropdownButtonFormField<String?>(
                                          value: filterCategories.any(
                                            (c) => c.id == filter.categoryId,
                                          )
                                              ? filter.categoryId
                                              : null,
                                          isExpanded: true,
                                          isDense: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Categoria',
                                            isDense: true,
                                          ),
                                          items: [
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text('Todas'),
                                            ),
                                            for (final category
                                                in filterCategories)
                                              DropdownMenuItem<String?>(
                                                value: category.id,
                                                child: Text(
                                                  category.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                          onChanged: (value) => ref
                                              .read(transactionFilterProvider
                                                  .notifier)
                                              .setCategoryId(value),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 190,
                                        child: DropdownButtonFormField<String?>(
                                          value: accounts.any(
                                            (a) => a.id == filter.accountId,
                                          )
                                              ? filter.accountId
                                              : null,
                                          isExpanded: true,
                                          isDense: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Conta',
                                            isDense: true,
                                          ),
                                          items: [
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text('Todas'),
                                            ),
                                            for (final account in accounts)
                                              DropdownMenuItem<String?>(
                                                value: account.id,
                                                child: Text(
                                                  account.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                          onChanged: (value) => ref
                                              .read(transactionFilterProvider
                                                  .notifier)
                                              .setAccountId(value),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 195,
                                        child: DropdownButtonFormField<
                                            TransactionStatusFilter>(
                                          value: filter.statusFilter,
                                          isExpanded: true,
                                          isDense: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Status',
                                            isDense: true,
                                          ),
                                          items: [
                                            for (final item
                                                in TransactionStatusFilter
                                                    .values)
                                              DropdownMenuItem(
                                                value: item,
                                                child: Text(
                                                  item.label,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              ref
                                                  .read(
                                                    transactionFilterProvider
                                                        .notifier,
                                                  )
                                                  .setStatusFilter(value);
                                            }
                                          },
                                        ),
                                      ),
                                      if (filter.hasActiveSecondaryFilters)
                                        TextButton.icon(
                                          onPressed: () {
                                            _searchController.clear();
                                            ref
                                                .read(transactionFilterProvider
                                                    .notifier)
                                                .resetSecondaryFilters();
                                          },
                                          icon: const Icon(
                                            Icons.filter_alt_off_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Limpar filtros'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateView(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Nenhuma movimentação encontrada',
                        description: filter.hasActiveSecondaryFilters
                            ? 'Nenhum lançamento corresponde aos filtros aplicados.'
                            : 'Registre sua primeira receita ou despesa neste período.',
                        actionLabel: filter.hasActiveSecondaryFilters
                            ? 'Limpar filtros'
                            : 'Nova movimentação',
                        onAction: () {
                          if (filter.hasActiveSecondaryFilters) {
                            _searchController.clear();
                            ref
                                .read(transactionFilterProvider.notifier)
                                .resetSecondaryFilters();
                          } else {
                            showTransactionFormDialog(context);
                          }
                        },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          return TransactionListTile(
                            transaction: tx,
                            category: tx.categoryId == null
                                ? null
                                : categoriesMap[tx.categoryId!],
                            account: tx.accountId == null
                                ? null
                                : accountsMap[tx.accountId!],
                            counterpartyAccount: tx.destinationAccountId == null
                                ? null
                                : accountsMap[tx.destinationAccountId!],
                            locale: locale,
                            currencyCode: currency,
                            onMarkAsSettled: () => ref
                                .read(transactionControllerProvider.notifier)
                                .markAsSettled(tx.id),
                            onEdit: () => showTransactionFormDialog(
                              context,
                              existing: tx,
                            ),
                            onDuplicate: () => showTransactionFormDialog(
                              context,
                              duplicateFrom: tx,
                            ),
                            onDelete: () => _confirmDelete(tx),
                          );
                        },
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
