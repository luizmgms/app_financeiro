import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../shared/models/date_period.dart';
import '../../../../shared/widgets/summary_metric_card.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../data/services/report_file_saver.dart';
import '../../domain/services/financial_analytics_service.dart';
import '../../domain/services/report_export_service.dart';
import '../widgets/financial_charts.dart';

/// Tela completa de Relatórios Analíticos, Fluxo de Caixa, Projeções e
/// Exportação para PDF e CSV (Etapa 5).
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DatePeriod _period = DatePeriod.fromType(DatePeriodType.thisMonth);
  bool _syncedMonthStart = false;
  bool _isExporting = false;

  Future<void> _selectPeriod(DatePeriodType type, int monthStartDay) async {
    if (type != DatePeriodType.custom) {
      setState(
        () => _period = DatePeriod.fromType(
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

  Future<void> _exportCsv(
    ReportSnapshot snapshot, {
    required String locale,
    required String currencyCode,
  }) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final csvContent = ReportExportService.buildCsv(
        snapshot,
        locale: locale,
        currencyCode: currencyCode,
      );
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final stamp = DateFormatter.isoDateKey(DateTime.now());
      final statusMsg = await saveAndShareReportFile(
        bytes: bytes,
        filename: 'finance_control_relatorio_$stamp.csv',
        mimeType: 'text/csv;charset=utf-8',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(statusMsg)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar CSV: $error'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf(
    ReportSnapshot snapshot, {
    required String locale,
    required String currencyCode,
  }) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await ReportExportService.buildPdfBytes(
        snapshot,
        locale: locale,
        currencyCode: currencyCode,
      );
      final stamp = DateFormatter.isoDateKey(DateTime.now());
      final statusMsg = await saveAndShareReportFile(
        bytes: bytes,
        filename: 'finance_control_relatorio_$stamp.pdf',
        mimeType: 'application/pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(statusMsg)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar PDF: $error'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final monthStartDay = profile?.monthStartDay ?? 1;
    if (!_syncedMonthStart) {
      _syncedMonthStart = true;
      _period = DatePeriod.fromType(
        DatePeriodType.thisMonth,
        monthStartDay: monthStartDay,
      );
    }

    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final allTransactions =
        ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final cards = ref.watch(creditCardsStreamProvider).valueOrNull ?? const [];
    final invoices = ref.watch(invoicesStreamProvider).valueOrNull ?? const [];
    final plans =
        ref.watch(installmentPlansStreamProvider).valueOrNull ?? const [];
    final categoriesById = ref.watch(categoriesByIdProvider);
    final isCompact = MediaQuery.of(context).size.width < 680;
    final theme = Theme.of(context);

    final snapshot = FinancialAnalyticsService.buildSnapshot(
      period: _period,
      allTransactions: allTransactions,
      accounts: accounts,
      cards: cards,
      invoices: invoices,
      installmentPlans: plans,
      categoriesById: categoriesById,
      monthStartDay: monthStartDay,
    );

    String fmt(int cents) => CurrencyFormatter.formatCents(
          cents,
          locale: locale,
          currencyCode: currency,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          if (isCompact)
            IconButton(
              tooltip: 'Exportar CSV',
              onPressed: _isExporting
                  ? null
                  : () => _exportCsv(
                        snapshot,
                        locale: locale,
                        currencyCode: currency,
                      ),
              icon: const Icon(Icons.table_chart_outlined),
            )
          else
            OutlinedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () => _exportCsv(
                        snapshot,
                        locale: locale,
                        currencyCode: currency,
                      ),
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('Exportar CSV'),
            ),
          const SizedBox(width: 6),
          if (isCompact)
            IconButton(
              tooltip: 'Exportar PDF',
              onPressed: _isExporting
                  ? null
                  : () => _exportPdf(
                        snapshot,
                        locale: locale,
                        currencyCode: currency,
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            )
          else
            FilledButton.icon(
              onPressed: _isExporting
                  ? null
                  : () => _exportPdf(
                        snapshot,
                        locale: locale,
                        currencyCode: currency,
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Exportar PDF'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final type in DatePeriodType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _period.type == type,
                      onSelected: (_) => _selectPeriod(type, monthStartDay),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${DateFormatter.shortDate(_period.start, locale: locale)} - '
                      '${DateFormatter.shortDate(_period.end, locale: locale)}',
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
                          title: 'Receitas do período',
                          valueText: fmt(snapshot.summary.totalIncomeCents),
                          subtitle:
                              'Recebido: ${fmt(snapshot.summary.receivedIncomeCents)}',
                          icon: Icons.trending_up_rounded,
                          accentColor: AppColors.income,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: SummaryMetricCard(
                          title: 'Despesas do período',
                          valueText: fmt(snapshot.summary.totalExpenseCents),
                          subtitle:
                              'Pago: ${fmt(snapshot.summary.paidExpenseCents)}',
                          icon: Icons.trending_down_rounded,
                          accentColor: AppColors.expense,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: SummaryMetricCard(
                          title: 'Fluxo de caixa real',
                          valueText: fmt(snapshot.cashFlow.netCashFlowCents),
                          subtitle:
                              'Entradas ${fmt(snapshot.cashFlow.inflowsCents)} • Saídas ${fmt(snapshot.cashFlow.outflowsCents)}',
                          icon: Icons.swap_vert_rounded,
                          accentColor: snapshot.cashFlow.netCashFlowCents >= 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: SummaryMetricCard(
                          title: 'Saldo projetado (período)',
                          valueText: fmt(snapshot.projectedEndOfMonthCents),
                          subtitle:
                              'Saldo atual: ${fmt(snapshot.totalBalanceCents)}',
                          icon: Icons.auto_graph_rounded,
                          accentColor: AppColors.transfer,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 760;
                  final cardWidth = twoCols
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _PayablesOverviewCard(
                          payables: snapshot.payablesStatus,
                          formatMoney: fmt,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _InstallmentsOverviewCard(
                          portfolio: snapshot.installmentsPortfolio,
                          formatMoney: fmt,
                          onOpenInstallments: () =>
                              context.push(AppRoutes.installments),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              MonthlyComparisonBarChartCard(points: snapshot.monthlyEvolution),
              const SizedBox(height: 16),
              MonthlyEvolutionLineChartCard(
                points: snapshot.monthlyEvolution,
                title: 'Evolução do patrimônio e resultados (6 meses)',
                showEquityLine: true,
              ),
              const SizedBox(height: 16),
              CategoryExpensesPieChartCard(
                items: snapshot.byCategory,
                locale: locale,
                currencyCode: currency,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 760;
                  final cardWidth = twoCols
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _AccountsBreakdownCard(
                          items: snapshot.byAccount,
                          formatMoney: fmt,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _CardsBreakdownCard(
                          items: snapshot.byCard,
                          formatMoney: fmt,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _FutureProjectionCard(
                projections: snapshot.projections,
                currentBalanceCents: snapshot.totalBalanceCents,
                formatMoney: fmt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayablesOverviewCard extends StatelessWidget {
  const _PayablesOverviewCard({
    required this.payables,
    required this.formatMoney,
  });

  final PayablesStatusSummary payables;
  final String Function(int) formatMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contas pagas, pendentes e vencidas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _StatusRow(
              label: 'Pagas (${payables.paidCount})',
              value: formatMoney(payables.paidCents),
              color: AppColors.income,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Pendentes (${payables.pendingCount})',
              value: formatMoney(payables.pendingCents),
              color: AppColors.warning,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Vencidas (${payables.overdueCount})',
              value: formatMoney(payables.overdueCents),
              color: AppColors.expense,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallmentsOverviewCard extends StatelessWidget {
  const _InstallmentsOverviewCard({
    required this.portfolio,
    required this.formatMoney,
    required this.onOpenInstallments,
  });

  final InstallmentsPortfolioSummary portfolio;
  final String Function(int) formatMoney;
  final VoidCallback onOpenInstallments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    'Compras parceladas (${portfolio.activePlansCount})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenInstallments,
                  child: const Text('Detalhes'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Total contratado',
              value: formatMoney(portfolio.totalContractedCents),
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Parcelas já quitadas',
              value: formatMoney(portfolio.paidCents),
              color: AppColors.income,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Comprometido futuro',
              value: formatMoney(portfolio.futureCommittedCents),
              color: AppColors.expense,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsBreakdownCard extends StatelessWidget {
  const _AccountsBreakdownCard({
    required this.items,
    required this.formatMoney,
  });

  final List<AccountBreakdownItem> items;
  final String Function(int) formatMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Despesas e saldos por conta',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'Nenhuma movimentação em conta neste período.',
                style: theme.textTheme.bodySmall,
              )
            else
              for (final acc in items) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      acc.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Desp.: ${formatMoney(acc.expenseCents)} • Saldo: ${formatMoney(acc.currentBalanceCents)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _CardsBreakdownCard extends StatelessWidget {
  const _CardsBreakdownCard({
    required this.items,
    required this.formatMoney,
  });

  final List<CardBreakdownItem> items;
  final String Function(int) formatMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Despesas por cartão de crédito',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(
                'Nenhum cartão ativo ou movimentação no período.',
                style: theme.textTheme.bodySmall,
              )
            else
              for (final card in items) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Período: ${formatMoney(card.periodExpenseCents)} • Faturas: ${formatMoney(card.openInvoicesCents)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _FutureProjectionCard extends StatelessWidget {
  const _FutureProjectionCard({
    required this.projections,
    required this.currentBalanceCents,
    required this.formatMoney,
  });

  final List<ProjectionHorizonPoint> projections;
  final int currentBalanceCents;
  final String Function(int) formatMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Projeção financeira futura',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                StatusBadge(
                  label: 'Base atual: ${formatMoney(currentBalanceCents)}',
                  color: AppColors.primaryLight,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 680 ? 3 : 1;
                final width =
                    (constraints.maxWidth - (12 * (cols - 1))) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in projections)
                      Container(
                        width: width,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant
                              .withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatMoney(item.projectedBalanceCents),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: item.projectedBalanceCents >= 0
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Entradas: ${formatMoney(item.expectedIncomeCents)}\nSaídas e faturas: ${formatMoney(item.expectedOutflowCents)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
