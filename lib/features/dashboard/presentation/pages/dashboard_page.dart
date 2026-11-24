import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../shared/models/date_period.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../../shared/widgets/summary_metric_card.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/presentation/pages/account_statement_page.dart';
import '../../../accounts/presentation/widgets/account_form_dialog.dart';
import '../../../accounts/presentation/widgets/transfer_form_dialog.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../budgets/application/providers/budget_providers.dart';
import '../../../budgets/domain/services/budget_calculator.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../../credit_cards/presentation/widgets/card_purchase_form_dialog.dart';
import '../../../notifications/application/controllers/notification_controller.dart';
import '../../../notifications/application/providers/notification_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../recurring/application/controllers/recurring_controller.dart';
import '../../../reports/domain/services/financial_analytics_service.dart';
import '../../../reports/presentation/widgets/financial_charts.dart';
import '../../../transactions/application/controllers/transaction_controller.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_form_dialog.dart';
import '../../../transactions/presentation/widgets/transaction_list_tile.dart';

/// Tela inicial (Dashboard) com visão completa em tempo real, projeção até o fim do mês,
/// contas a pagar/receber, faturas abertas, vencimentos próximos, orçamentos e gráficos `fl_chart`.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DatePeriod _activePeriod = DatePeriod.fromType(DatePeriodType.thisMonth);
  int _lastMonthStartDay = 1;
  String? _syncedSessionUid;

  void _scheduleAutomationSyncIfNeeded({
    required bool isReady,
    required String? uid,
  }) {
    if (!isReady || uid == null || Firebase.apps.isEmpty) return;
    if (_syncedSessionUid == uid) return;
    _syncedSessionUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(recurringControllerProvider.notifier).syncNow(silent: true);
      if (!mounted) return;
      await ref
          .read(notificationControllerProvider.notifier)
          .syncAlerts(silent: true);
    });
  }

  Future<void> _selectPeriod(DatePeriodType type, int monthStartDay) async {
    if (type != DatePeriodType.custom) {
      setState(
        () => _activePeriod = DatePeriod.fromType(
          type,
          monthStartDay: monthStartDay,
        ),
      );
      return;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _activePeriod.start,
        end: _activePeriod.end,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _activePeriod = DatePeriod(
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

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapStateProvider);
    final authUser = ref.watch(currentAuthUserProvider);
    _scheduleAutomationSyncIfNeeded(
      isReady: bootstrap.firebase.isReady,
      uid: authUser?.uid,
    );
    final unreadNotificationsCount =
        ref.watch(unreadNotificationsCountProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final monthStartDay = profile?.monthStartDay ?? 1;
    if (_activePeriod.type != DatePeriodType.custom &&
        _lastMonthStartDay != monthStartDay) {
      _lastMonthStartDay = monthStartDay;
      _activePeriod = DatePeriod.fromType(
        _activePeriod.type,
        monthStartDay: monthStartDay,
      );
    }

    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final activeAccounts = ref.watch(activeAccountsProvider);
    final accountsMap = ref.watch(accountsByIdProvider);
    final categoriesMap = ref.watch(categoriesByIdProvider);
    final cards = ref.watch(creditCardsStreamProvider).valueOrNull ?? const [];
    final activeCards = ref.watch(activeCreditCardsProvider);
    final cardsMap = ref.watch(creditCardsByIdProvider);
    final invoices = ref.watch(invoicesStreamProvider).valueOrNull ?? const [];
    final plans =
        ref.watch(installmentPlansStreamProvider).valueOrNull ?? const [];
    final budgetUsages = ref.watch(currentMonthBudgetUsagesProvider);
    final allTransactions =
        ref.watch(transactionsStreamProvider).valueOrNull ?? const [];

    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final theme = Theme.of(context);

    final snapshot = FinancialAnalyticsService.buildSnapshot(
      period: _activePeriod,
      allTransactions: allTransactions,
      accounts: accounts,
      cards: cards,
      invoices: invoices,
      installmentPlans: plans,
      categoriesById: categoriesMap,
      monthStartDay: monthStartDay,
    );

    String fmt(int cents) => CurrencyFormatter.formatCents(
          cents,
          locale: locale,
          currencyCode: currency,
        );

    final recentTransactions = allTransactions.take(5).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Finance Control'),
            Text(
              authUser != null
                  ? 'Olá, ${profile?.displayName ?? authUser.displayName}'
                  : 'Visão geral financeira',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificações',
            onPressed: () => context.push(AppRoutes.notifications),
            icon: Badge(
              isLabelVisible: unreadNotificationsCount > 0,
              label: Text(
                unreadNotificationsCount > 99
                    ? '99+'
                    : '$unreadNotificationsCount',
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: authUser != null ? 'Perfil' : 'Entrar',
            onPressed: () => context.push(
              authUser != null ? AppRoutes.profile : AppRoutes.login,
            ),
            icon: Icon(
              authUser != null
                  ? Icons.account_circle_rounded
                  : Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bootstrap.firebase.isReady || accounts.isNotEmpty) ...[
                  _AccountsBalancesCard(
                    accounts: activeAccounts,
                    archivedCount: accounts.length - activeAccounts.length,
                    totalBalanceCents: snapshot.totalBalanceCents,
                    formatMoney: fmt,
                    onManageAccounts: () => context.go(AppRoutes.accounts),
                    onAddAccount: () => showAccountFormDialog(context),
                    onOpenAccount: (account) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountStatementPage(
                            accountId: account.id,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (bootstrap.firebase.isReady) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _CompactQuickActionButton(
                        label: 'Nova receita',
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.income,
                        onPressed: () => showTransactionFormDialog(
                          context,
                          initialKind: TransactionKind.income,
                        ),
                      ),
                      _CompactQuickActionButton(
                        label: 'Nova despesa',
                        icon: Icons.trending_down_rounded,
                        iconColor: AppColors.expense,
                        onPressed: () => showTransactionFormDialog(
                          context,
                          initialKind: TransactionKind.expense,
                        ),
                      ),
                      if (activeCards.isNotEmpty)
                        _CompactQuickActionButton(
                          label: 'Compra no cartão',
                          icon: Icons.credit_card_rounded,
                          iconColor: AppColors.credit,
                          onPressed: () => showCardPurchaseFormDialog(context),
                        ),
                      if (activeAccounts.length >= 2)
                        _CompactQuickActionButton(
                          label: 'Transferir',
                          icon: Icons.swap_horiz_rounded,
                          outlined: true,
                          onPressed: () => showTransferFormDialog(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final period in DatePeriodType.values)
                      _CompactPeriodChip(
                        label: period.label,
                        selected: _activePeriod.type == period,
                        onSelected: () => _selectPeriod(period, monthStartDay),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        '${DateFormatter.shortDate(_activePeriod.start, locale: locale)} - '
                        '${DateFormatter.shortDate(_activePeriod.end, locale: locale)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 560
                            ? 2
                            : 1;
                    final itemWidth =
                        (constraints.maxWidth - (12 * (columns - 1))) / columns;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Saldo total disponível',
                            valueText: fmt(snapshot.totalBalanceCents),
                            subtitle: activeAccounts.isEmpty
                                ? 'Aguardando contas cadastradas'
                                : '${activeAccounts.length} conta(s) ativa(s)',
                            icon: Icons.account_balance_wallet_outlined,
                            accentColor: AppColors.primaryLight,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Receitas do período',
                            valueText: fmt(snapshot.summary.totalIncomeCents),
                            subtitle: snapshot.summary.totalIncomeCents == 0
                                ? 'Nenhuma receita registrada'
                                : 'Recebido: ${fmt(snapshot.summary.receivedIncomeCents)}',
                            icon: Icons.trending_up_rounded,
                            accentColor: AppColors.income,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Despesas do período',
                            valueText: fmt(snapshot.summary.totalExpenseCents),
                            subtitle: snapshot.summary.totalExpenseCents == 0
                                ? 'Nenhuma despesa registrada'
                                : 'Pago: ${fmt(snapshot.summary.paidExpenseCents)}',
                            icon: Icons.trending_down_rounded,
                            accentColor: AppColors.expense,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Saldo projetado',
                            valueText: fmt(snapshot.projectedEndOfMonthCents),
                            subtitle: snapshot.totalOpenInvoicesCents > 0
                                ? 'Faturas em aberto: ${fmt(snapshot.totalOpenInvoicesCents)}'
                                : 'Considera pendências e faturas até o fim do período',
                            icon: Icons.auto_graph_rounded,
                            accentColor: AppColors.credit,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 780
                        ? 3
                        : constraints.maxWidth >= 500
                            ? 2
                            : 1;
                    final itemWidth =
                        (constraints.maxWidth - (12 * (columns - 1))) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _CompactMetricStripCard(
                            label: 'Contas a pagar (pendentes)',
                            value: fmt(snapshot.summary.pendingExpenseCents),
                            icon: Icons.event_busy_outlined,
                            color: AppColors.expense,
                            onTap: () => context.go(AppRoutes.transactions),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _CompactMetricStripCard(
                            label: 'Contas a receber (pendentes)',
                            value: fmt(snapshot.summary.pendingIncomeCents),
                            icon: Icons.schedule_rounded,
                            color: AppColors.income,
                            onTap: () => context.go(AppRoutes.transactions),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _CompactMetricStripCard(
                            label: 'Faturas abertas dos cartões',
                            value: fmt(snapshot.totalOpenInvoicesCents),
                            icon: Icons.credit_card_outlined,
                            color: AppColors.credit,
                            onTap: () => context.go(AppRoutes.creditCards),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _IncomeExpenseChartCard(
                  period: _activePeriod,
                  transactions: snapshot.periodTransactions,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCols = constraints.maxWidth >= 820;
                    final cardWidth = twoCols
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: CategoryExpensesPieChartCard(
                            items: snapshot.byCategory,
                            locale: locale,
                            currencyCode: currency,
                            actionLabel: 'Relatórios',
                            onActionTap: () => context.go(AppRoutes.reports),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: MonthlyEvolutionLineChartCard(
                            points: snapshot.monthlyEvolution,
                            title: 'Evolução financeira mensal',
                            showEquityLine: false,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (bootstrap.firebase.isReady) ...[
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoCols = constraints.maxWidth >= 820;
                      final cardWidth = twoCols
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _UpcomingDueBillsCard(
                              items: snapshot.upcomingDueItems,
                              formatMoney: fmt,
                              locale: locale,
                              onOpenNotifications: () =>
                                  context.push(AppRoutes.notifications),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _DashboardBudgetsCard(
                              usages: budgetUsages,
                              categoriesMap: categoriesMap,
                              formatMoney: fmt,
                              onOpenBudgets: () =>
                                  context.push(AppRoutes.budgets),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Últimas movimentações',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.go(AppRoutes.transactions),
                                child: const Text('Ver todas'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (recentTransactions.isEmpty)
                            Text(
                              'Nenhuma movimentação registrada ainda. Use os botões acima para fazer seu primeiro lançamento.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (var i = 0;
                                    i < recentTransactions.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  TransactionListTile(
                                    transaction: recentTransactions[i],
                                    category:
                                        recentTransactions[i].categoryId == null
                                            ? null
                                            : categoriesMap[
                                                recentTransactions[i]
                                                    .categoryId!],
                                    account:
                                        recentTransactions[i].accountId == null
                                            ? null
                                            : accountsMap[
                                                recentTransactions[i]
                                                    .accountId!],
                                    counterpartyAccount: recentTransactions[i]
                                                .destinationAccountId ==
                                            null
                                        ? null
                                        : accountsMap[recentTransactions[i]
                                            .destinationAccountId!],
                                    card: recentTransactions[i].cardId == null
                                        ? null
                                        : cardsMap[
                                            recentTransactions[i].cardId!],
                                    locale: locale,
                                    currencyCode: currency,
                                    onMarkAsSettled: () => ref
                                        .read(transactionControllerProvider
                                            .notifier)
                                        .markAsSettled(
                                          recentTransactions[i].id,
                                        ),
                                    onEdit: () => showTransactionFormDialog(
                                      context,
                                      existing: recentTransactions[i],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _ModulesDirectoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMetricStripCard extends StatelessWidget {
  const _CompactMetricStripCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withOpacity(0.14),
                foregroundColor: color,
                child: Icon(icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingDueBillsCard extends StatelessWidget {
  const _UpcomingDueBillsCard({
    required this.items,
    required this.formatMoney,
    required this.locale,
    required this.onOpenNotifications,
  });

  final List<UpcomingDueItem> items;
  final String Function(int) formatMoney;
  final String locale;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = items.take(4).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Contas com vencimento próximo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenNotifications,
                  child: const Text('Alertas'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhuma conta ou fatura vencendo nos próximos 15 dias.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final item in top)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        item.isOverdue
                            ? Icons.warning_amber_rounded
                            : (item.isInvoice
                                ? Icons.credit_card_rounded
                                : Icons.event_note_rounded),
                        size: 18,
                        color: item.isOverdue
                            ? AppColors.expense
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${DateFormatter.shortDate(item.dueDate, locale: locale)} • ${item.subtitle}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatMoney(item.amountCents),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: item.isOverdue
                              ? AppColors.expense
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBudgetsCard extends StatelessWidget {
  const _DashboardBudgetsCard({
    required this.usages,
    required this.categoriesMap,
    required this.formatMoney,
    required this.onOpenBudgets,
  });

  final List<BudgetUsageItem> usages;
  final Map<String, dynamic> categoriesMap;
  final String Function(int) formatMoney;
  final VoidCallback onOpenBudgets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = usages.take(4).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Orçamentos do mês',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenBudgets,
                  child: const Text('Gerenciar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Defina tetos por categoria em Orçamentos para acompanhar o consumo mensal aqui.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final u in top) ...[
                Builder(
                  builder: (context) {
                    final color = switch (u.healthStatus) {
                      BudgetHealthStatus.healthy => AppColors.income,
                      BudgetHealthStatus.warning => AppColors.warning,
                      BudgetHealthStatus.exceeded => AppColors.expense,
                    };
                    final catName =
                        categoriesMap[u.budget.categoryId]?.name ?? 'Categoria';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                catName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${formatMoney(u.spentCents)} / ${formatMoney(u.limitCents)} (${u.consumedPercent}%)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: u.consumedRatio.clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.5),
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _CompactQuickActionButton extends StatelessWidget {
  const _CompactQuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      visualDensity: VisualDensity(horizontal: -2, vertical: -3),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: MaterialStatePropertyAll(Size(0, 32)),
      padding: MaterialStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      textStyle: MaterialStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    final iconWidget = Icon(icon, size: 15, color: iconColor);
    final labelWidget = Text(label, maxLines: 1, softWrap: false);

    if (outlined) {
      return OutlinedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: iconWidget,
        label: labelWidget,
      );
    }

    return FilledButton.tonalIcon(
      style: style,
      onPressed: onPressed,
      icon: iconWidget,
      label: labelWidget,
    );
  }
}

class _CompactPeriodChip extends StatelessWidget {
  const _CompactPeriodChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, maxLines: 1, softWrap: false),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
    );
  }
}

class _IncomeExpenseChartCard extends StatelessWidget {
  const _IncomeExpenseChartCard({
    required this.period,
    required this.transactions,
  });

  final DatePeriod period;
  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final incomeBuckets = List<double>.filled(4, 0);
    final expenseBuckets = List<double>.filled(4, 0);
    final totalMs =
        math.max(1, period.end.difference(period.start).inMilliseconds);

    var hasData = false;
    for (final tx in transactions) {
      if (!tx.kind.countsAsIncomeOrExpense) continue;
      hasData = true;
      final offset = tx.competencyDate.difference(period.start).inMilliseconds;
      final ratio = (offset / totalMs).clamp(0.0, 0.9999);
      final bucketIndex = (ratio * 4).floor().clamp(0, 3);
      final valueReais = tx.amountCents / 100.0;

      if (tx.kind == TransactionKind.income) {
        incomeBuckets[bucketIndex] += valueReais;
      } else if (tx.kind == TransactionKind.cardRefund) {
        expenseBuckets[bucketIndex] =
            math.max(0, expenseBuckets[bucketIndex] - valueReais);
      } else {
        expenseBuckets[bucketIndex] += valueReais;
      }
    }

    var peak = 100.0;
    for (var i = 0; i < 4; i++) {
      peak = math.max(peak, math.max(incomeBuckets[i], expenseBuckets[i]));
    }
    final maxY = hasData ? (peak * 1.2) : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Receitas x Despesas no período',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  label: hasData ? 'Dados reais' : 'Sem lançamentos',
                  color: hasData ? AppColors.income : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasData
                  ? 'Comparativo de entradas e saídas distribuídas ao longo do período selecionado.'
                  : 'O gráfico exibirá valores reais assim que você registrar receitas ou despesas no período.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 2,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4'];
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[idx],
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 4; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: incomeBuckets[i],
                            width: 14,
                            color: AppColors.income,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          BarChartRodData(
                            toY: expenseBuckets[i],
                            width: 14,
                            color: AppColors.expense,
                            borderRadius: BorderRadius.circular(6),
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
    );
  }
}

class _ModulesDirectoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modules = [
      ('Categorias', Icons.category_outlined, AppRoutes.categories),
      ('Contas', Icons.account_balance_wallet_outlined, AppRoutes.accounts),
      ('Movimentações', Icons.swap_horiz_rounded, AppRoutes.transactions),
      ('Orçamentos', Icons.pie_chart_outline_rounded, AppRoutes.budgets),
      ('Recorrências', Icons.repeat_rounded, AppRoutes.recurring),
      ('Parcelamentos', Icons.view_week_outlined, AppRoutes.installments),
      ('Notificações', Icons.notifications_active_outlined,
          AppRoutes.notifications),
      ('Perfil', Icons.badge_outlined, AppRoutes.profile),
      ('Assistente IA', Icons.auto_awesome_rounded, AppRoutes.aiAssistant),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atalhos dos módulos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Acesse diretamente os módulos de organização e controle financeiro.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in modules)
                  ActionChip(
                    avatar: Icon(item.$2, size: 18),
                    label: Text(item.$1),
                    onPressed: () {
                      if (item.$3 == AppRoutes.accounts ||
                          item.$3 == AppRoutes.transactions ||
                          item.$3 == AppRoutes.reports ||
                          item.$3 == AppRoutes.creditCards) {
                        context.go(item.$3);
                      } else {
                        context.push(item.$3);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card inicial exibindo o saldo individual de todas as contas ativas do usuário.
class _AccountsBalancesCard extends StatelessWidget {
  const _AccountsBalancesCard({
    required this.accounts,
    required this.archivedCount,
    required this.totalBalanceCents,
    required this.formatMoney,
    required this.onManageAccounts,
    required this.onAddAccount,
    required this.onOpenAccount,
  });

  final List<AccountEntity> accounts;
  final int archivedCount;
  final int totalBalanceCents;
  final String Function(int) formatMoney;
  final VoidCallback onManageAccounts;
  final VoidCallback onAddAccount;
  final ValueChanged<AccountEntity> onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileColor = isDark
        ? AppColors.darkSurfaceElevated.withOpacity(0.55)
        : AppColors.lightSurfaceMuted.withOpacity(0.8);
    final tileBorderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final totalColor =
        totalBalanceCents >= 0 ? AppColors.primaryLight : AppColors.expense;

    final subtitleText = accounts.isEmpty
        ? (archivedCount > 0
            ? '$archivedCount conta(s) arquivada(s)'
            : 'Nenhuma conta ativa cadastrada')
        : '${accounts.length} conta(s) ativa(s)'
            '${archivedCount > 0 ? ' • +$archivedCount arquivada(s)' : ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 17,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo das contas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onManageAccounts,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMoney(totalBalanceCents),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: totalColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (accounts.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      archivedCount > 0
                          ? 'Todas as contas estão arquivadas no momento.'
                          : 'Cadastre uma conta para acompanhar seu saldo aqui.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        archivedCount > 0 ? onManageAccounts : onAddAccount,
                    child: Text(
                      archivedCount > 0 ? 'Gerenciar' : 'Nova conta',
                    ),
                  ),
                ],
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 860
                      ? 3
                      : constraints.maxWidth >= 520
                          ? 2
                          : 1;
                  final tileWidth =
                      (constraints.maxWidth - (8 * (columns - 1))) / columns;

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final account in accounts)
                        SizedBox(
                          width: tileWidth,
                          child: _AccountBalanceMiniTile(
                            account: account,
                            balanceText: formatMoney(
                              account.currentBalanceCents,
                            ),
                            backgroundColor: tileColor,
                            borderColor: tileBorderColor,
                            onTap: () => onOpenAccount(account),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountBalanceMiniTile extends StatelessWidget {
  const _AccountBalanceMiniTile({
    required this.account,
    required this.balanceText,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final AccountEntity account;
  final String balanceText;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ColorUtils.fromHex(account.colorHex);
    final iconData = IconCatalog.resolve(
      account.iconName,
      fallback: Icons.account_balance_rounded,
    );
    final balanceColor = account.currentBalanceCents >= 0
        ? AppColors.income
        : AppColors.expense;
    final subLabel = account.institution.isNotEmpty
        ? account.institution
        : account.type.label;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, size: 16, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                balanceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: balanceColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
