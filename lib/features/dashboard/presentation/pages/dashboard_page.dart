import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/platform_info.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../shared/models/date_period.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../../shared/widgets/summary_metric_card.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../accounts/presentation/widgets/transfer_form_dialog.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../../credit_cards/presentation/widgets/card_purchase_form_dialog.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/controllers/transaction_controller.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_filter.dart';
import '../../../transactions/domain/entities/transaction_summary.dart';
import '../../../transactions/presentation/widgets/transaction_form_dialog.dart';
import '../../../transactions/presentation/widgets/transaction_list_tile.dart';

/// Tela inicial (Dashboard) com dados financeiros reais em tempo real.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DatePeriod _activePeriod = DatePeriod.fromType(DatePeriodType.thisMonth);

  Future<void> _selectPeriod(DatePeriodType type) async {
    if (type != DatePeriodType.custom) {
      setState(() => _activePeriod = DatePeriod.fromType(type));
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
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final activeAccounts = ref.watch(activeAccountsProvider);
    final accountsMap = ref.watch(accountsByIdProvider);
    final categoriesMap = ref.watch(categoriesByIdProvider);
    final activeCards = ref.watch(activeCreditCardsProvider);
    final cardsMap = ref.watch(creditCardsByIdProvider);
    final totalOpenInvoicesCents =
        ref.watch(totalOpenInvoicesAmountCentsProvider);
    final totalBalanceCents = ref.watch(totalAvailableBalanceCentsProvider);
    final allTransactions =
        ref.watch(transactionsStreamProvider).valueOrNull ?? const [];

    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final theme = Theme.of(context);

    final periodFilter = TransactionFilter(period: _activePeriod);
    final periodTransactions =
        allTransactions.where(periodFilter.matches).toList(growable: false);
    final summary =
        TransactionPeriodSummary.fromTransactions(periodTransactions);
    final projectedBalanceCents = totalBalanceCents +
        summary.pendingIncomeCents -
        summary.pendingExpenseCents;

    final firebaseColor = switch (bootstrap.firebase.status) {
      FirebaseConnectionStatus.connected => AppColors.income,
      FirebaseConnectionStatus.awaitingConfiguration => AppColors.warning,
      FirebaseConnectionStatus.unsupportedPlatform => AppColors.transfer,
      FirebaseConnectionStatus.error => AppColors.expense,
    };

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
            icon: const Icon(Icons.notifications_outlined),
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EnvironmentBannerCard(
                  bootstrap: bootstrap,
                  statusColor: firebaseColor,
                ),
                const SizedBox(height: 12),
                if (bootstrap.firebase.isReady) ...[
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
                        label: const Text('Nova receita'),
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
                        label: const Text('Nova despesa'),
                      ),
                      if (activeCards.isNotEmpty)
                        FilledButton.tonalIcon(
                          onPressed: () => showCardPurchaseFormDialog(context),
                          icon: const Icon(
                            Icons.credit_card_rounded,
                            color: AppColors.credit,
                          ),
                          label: const Text('Compra no cartão'),
                        ),
                      if (activeAccounts.length >= 2)
                        OutlinedButton.icon(
                          onPressed: () => showTransferFormDialog(context),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Transferir'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final period in DatePeriodType.values)
                      ChoiceChip(
                        label: Text(period.label),
                        selected: _activePeriod.type == period,
                        onSelected: (_) => _selectPeriod(period),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${DateFormatter.shortDate(_activePeriod.start, locale: locale)} - '
                        '${DateFormatter.shortDate(_activePeriod.end, locale: locale)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                            valueText: fmt(totalBalanceCents),
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
                            valueText: fmt(summary.totalIncomeCents),
                            subtitle: summary.totalIncomeCents == 0
                                ? 'Nenhuma receita registrada'
                                : 'A receber: ${fmt(summary.pendingIncomeCents)}',
                            icon: Icons.trending_up_rounded,
                            accentColor: AppColors.income,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Despesas do período',
                            valueText: fmt(summary.totalExpenseCents),
                            subtitle: summary.totalExpenseCents == 0
                                ? 'Nenhuma despesa registrada'
                                : 'A pagar: ${fmt(summary.pendingExpenseCents)}',
                            icon: Icons.trending_down_rounded,
                            accentColor: AppColors.expense,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: SummaryMetricCard(
                            title: 'Saldo projetado',
                            valueText: fmt(projectedBalanceCents),
                            subtitle: totalOpenInvoicesCents > 0
                                ? 'Faturas em aberto: ${fmt(totalOpenInvoicesCents)}'
                                : 'Considera receitas e despesas pendentes do período',
                            icon: Icons.auto_graph_rounded,
                            accentColor: AppColors.credit,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _IncomeExpenseChartCard(
                  period: _activePeriod,
                  transactions: periodTransactions,
                ),
                const SizedBox(height: 16),
                if (bootstrap.firebase.isReady) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Últimas movimentações',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 16),
                ],
                _ModulesDirectoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvironmentBannerCard extends StatelessWidget {
  const _EnvironmentBannerCard({
    required this.bootstrap,
    required this.statusColor,
  });

  final AppBootstrapState bootstrap;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  label: bootstrap.firebase.isReady
                      ? 'Sincronizado'
                      : 'Esqueleto Etapa 0',
                  color: AppColors.primaryLight,
                  icon: Icons.verified_outlined,
                ),
                StatusBadge(
                  label: PlatformInfo.platformLabel,
                  color: AppColors.transfer,
                  icon: Icons.devices_outlined,
                ),
                StatusBadge(
                  label: bootstrap.localStorageInitialized
                      ? 'Cache Hive ativo'
                      : 'Cache Hive em memória',
                  color: AppColors.income,
                  icon: Icons.storage_outlined,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_outlined, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    bootstrap.firebase.errorDetails != null
                        ? '${bootstrap.firebase.message} (${bootstrap.firebase.errorDetails})'
                        : bootstrap.firebase.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                          item.$3 == AppRoutes.transactions) {
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
