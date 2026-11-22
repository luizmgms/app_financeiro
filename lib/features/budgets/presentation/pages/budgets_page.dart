import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
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
import '../../../../shared/widgets/summary_metric_card.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../application/controllers/budget_controller.dart';
import '../../application/providers/budget_providers.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/services/budget_calculator.dart';
import '../widgets/budget_form_dialog.dart';

/// Tela de Orçamentos Mensais por Categoria com acompanhamento planejado vs
/// utilizado, alertas visuais de aproximação/estouro e comparativo entre meses.
class BudgetsPage extends ConsumerStatefulWidget {
  const BudgetsPage({super.key});

  @override
  ConsumerState<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends ConsumerState<BudgetsPage> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _initialized = false;

  void _ensureMonthInitialized(int monthStartDay) {
    if (_initialized) return;
    final current = DatePeriod.resolveAccountingYearMonth(
      DateTime.now(),
      monthStartDay: monthStartDay,
    );
    _selectedYear = current.year;
    _selectedMonth = current.month;
    _initialized = true;
  }

  void _shiftMonth(int delta) {
    final target = DateTime(_selectedYear, _selectedMonth + delta, 1);
    setState(() {
      _selectedYear = target.year;
      _selectedMonth = target.month;
    });
  }

  Future<void> _confirmDelete(BudgetEntity budget, String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir orçamento'),
        content: Text(
          'Deseja remover o limite mensal de "$categoryName" (${budget.monthLabel})?',
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
          .read(budgetControllerProvider.notifier)
          .deleteBudget(budget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BudgetActionState>(budgetControllerProvider, (prev, next) {
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

    final profile = ref.watch(userProfileProvider).valueOrNull;
    final monthStartDay = profile?.monthStartDay ?? 1;
    _ensureMonthInitialized(monthStartDay);

    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final transactions =
        ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
    final categoriesById = ref.watch(categoriesByIdProvider);
    final actionLoading = ref.watch(budgetControllerProvider).isLoading;
    final isCompact = MediaQuery.of(context).size.width < 680;
    final theme = Theme.of(context);

    String fmt(int cents) => CurrencyFormatter.formatCents(
          cents,
          locale: locale,
          currencyCode: currency,
        );

    final monthDate = DateTime(_selectedYear, _selectedMonth, 1);
    final cycleRange = DatePeriod.accountingMonth(
      _selectedYear,
      _selectedMonth,
      monthStartDay: monthStartDay,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamentos'),
        actions: [
          if (isCompact)
            IconButton(
              tooltip: 'Copiar mês anterior',
              onPressed: actionLoading
                  ? null
                  : () => ref
                      .read(budgetControllerProvider.notifier)
                      .copyFromPreviousMonth(
                        targetYear: _selectedYear,
                        targetMonth: _selectedMonth,
                      ),
              icon: const Icon(Icons.content_copy_rounded),
            )
          else
            OutlinedButton.icon(
              onPressed: actionLoading
                  ? null
                  : () => ref
                      .read(budgetControllerProvider.notifier)
                      .copyFromPreviousMonth(
                        targetYear: _selectedYear,
                        targetMonth: _selectedMonth,
                      ),
              icon: const Icon(Icons.content_copy_rounded, size: 17),
              label: const Text('Copiar mês anterior'),
            ),
          const SizedBox(width: 6),
          if (isCompact)
            IconButton(
              tooltip: 'Novo orçamento',
              onPressed: () => showBudgetFormDialog(
                context,
                year: _selectedYear,
                month: _selectedMonth,
              ),
              icon: const Icon(Icons.add_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showBudgetFormDialog(
                context,
                year: _selectedYear,
                month: _selectedMonth,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova meta'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar orçamentos',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(budgetsStreamProvider),
        ),
        data: (budgets) {
          final usages = BudgetCalculator.evaluateMonth(
            budgets: budgets,
            transactions: transactions,
            year: _selectedYear,
            month: _selectedMonth,
            monthStartDay: monthStartDay,
          );

          final totalPlannedCents =
              usages.fold<int>(0, (s, u) => s + u.limitCents);
          final totalSpentCents =
              usages.fold<int>(0, (s, u) => s + u.spentCents);
          final totalRemainingCents = totalPlannedCents - totalSpentCents;
          final overallPercent = totalPlannedCents <= 0
              ? 0
              : ((totalSpentCents / totalPlannedCents) * 100).round();

          final warningsCount = usages
              .where((u) => u.healthStatus == BudgetHealthStatus.warning)
              .length;
          final exceededCount = usages
              .where((u) => u.healthStatus == BudgetHealthStatus.exceeded)
              .length;

          final comparison = BudgetCalculator.buildMonthlyComparison(
            budgets: budgets,
            transactions: transactions,
            endYear: _selectedYear,
            endMonth: _selectedMonth,
            monthsCount: 6,
            monthStartDay: monthStartDay,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1020),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Mês anterior',
                                onPressed: () => _shiftMonth(-1),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormatter.monthYear(
                                        monthDate,
                                        locale: locale,
                                      ),
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Ciclo ${DateFormatter.shortDate(cycleRange.start, locale: locale)} - ${DateFormatter.shortDate(cycleRange.end, locale: locale)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Próximo mês',
                                onPressed: () => _shiftMonth(1),
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (exceededCount > 0)
                                StatusBadge(
                                  label: '$exceededCount ultrapassado(s)',
                                  color: AppColors.expense,
                                  icon: Icons.error_outline_rounded,
                                ),
                              if (warningsCount > 0)
                                StatusBadge(
                                  label: '$warningsCount no limite',
                                  color: AppColors.warning,
                                  icon: Icons.warning_amber_rounded,
                                ),
                              if (exceededCount == 0 &&
                                  warningsCount == 0 &&
                                  usages.isNotEmpty)
                                const StatusBadge(
                                  label: 'Dentro da meta',
                                  color: AppColors.income,
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 820
                          ? 4
                          : constraints.maxWidth >= 500
                              ? 2
                              : 1;
                      final itemWidth =
                          (constraints.maxWidth - (12 * (columns - 1))) /
                              columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: SummaryMetricCard(
                              title: 'Valor planejado',
                              valueText: fmt(totalPlannedCents),
                              subtitle: '${usages.length} categoria(s)',
                              icon: Icons.flag_outlined,
                              accentColor: AppColors.primaryLight,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: SummaryMetricCard(
                              title: 'Valor utilizado',
                              valueText: fmt(totalSpentCents),
                              subtitle: '$overallPercent% consumido',
                              icon: Icons.shopping_cart_checkout_rounded,
                              accentColor: overallPercent > 100
                                  ? AppColors.expense
                                  : AppColors.warning,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: SummaryMetricCard(
                              title: totalRemainingCents >= 0
                                  ? 'Valor disponível'
                                  : 'Excedente no mês',
                              valueText: fmt(totalRemainingCents.abs()),
                              subtitle: totalRemainingCents >= 0
                                  ? 'Margem livre nas metas'
                                  : 'Acima do orçamento total',
                              icon: Icons.savings_outlined,
                              accentColor: totalRemainingCents >= 0
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: SummaryMetricCard(
                              title: 'Consumo geral',
                              valueText: '$overallPercent%',
                              subtitle: exceededCount > 0
                                  ? '$exceededCount meta(s) estourada(s)'
                                  : 'Acompanhamento em tempo real',
                              icon: Icons.pie_chart_outline_rounded,
                              accentColor: AppColors.transfer,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (usages.isEmpty)
                    SizedBox(
                      height: 300,
                      child: EmptyStateView(
                        icon: Icons.pie_chart_outline_rounded,
                        title: 'Nenhum orçamento definido neste mês',
                        description:
                            'Estabeleça tetos mensais para Alimentação, Transporte, Lazer, Saúde e receba alertas ao se aproximar do limite.',
                        actionLabel: 'Definir primeira meta',
                        onAction: () => showBudgetFormDialog(
                          context,
                          year: _selectedYear,
                          month: _selectedMonth,
                        ),
                      ),
                    )
                  else
                    for (final item in usages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BudgetProgressCard(
                          usage: item,
                          category: categoriesById[item.budget.categoryId],
                          formattedPlanned: fmt(item.limitCents),
                          formattedSpent: fmt(item.spentCents),
                          formattedRemaining: fmt(item.remainingCents.abs()),
                          onEdit: () => showBudgetFormDialog(
                            context,
                            year: _selectedYear,
                            month: _selectedMonth,
                            existing: item.budget,
                          ),
                          onDelete: () => _confirmDelete(
                            item.budget,
                            categoriesById[item.budget.categoryId]?.name ??
                                'Categoria',
                          ),
                        ),
                      ),
                  const SizedBox(height: 16),
                  _MonthlyBudgetComparisonChartCard(
                    points: comparison,
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

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({
    required this.usage,
    required this.category,
    required this.formattedPlanned,
    required this.formattedSpent,
    required this.formattedRemaining,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetUsageItem usage;
  final CategoryEntity? category;
  final String formattedPlanned;
  final String formattedSpent;
  final String formattedRemaining;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = category != null
        ? ColorUtils.fromHex(category!.colorHex, fallback: AppColors.primaryLight)
        : AppColors.primaryLight;

    final statusColor = switch (usage.healthStatus) {
      BudgetHealthStatus.healthy => AppColors.income,
      BudgetHealthStatus.warning => AppColors.warning,
      BudgetHealthStatus.exceeded => AppColors.expense,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: catColor.withOpacity(0.14),
                  foregroundColor: catColor,
                  child: Icon(
                    IconCatalog.resolve(
                      category?.iconName,
                      fallback: Icons.category_outlined,
                    ),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        category?.name ?? 'Categoria removida',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      StatusBadge(
                        label: usage.healthStatus.label,
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar limite')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Excluir',
                        style: TextStyle(color: AppColors.expense),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: usage.consumedRatio.clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor:
                    theme.colorScheme.surfaceVariant.withOpacity(0.5),
                color: statusColor,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  'Utilizado: $formattedSpent / $formattedPlanned (${usage.consumedPercent}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  usage.remainingCents >= 0
                      ? 'Disponível: $formattedRemaining'
                      : 'Ultrapassado em $formattedRemaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: statusColor,
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

class _MonthlyBudgetComparisonChartCard extends StatelessWidget {
  const _MonthlyBudgetComparisonChartCard({required this.points});

  final List<MonthlyBudgetComparisonPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var peak = 100.0;
    var hasAnyValue = false;
    for (final p in points) {
      if (p.plannedCents > 0 || p.spentCents > 0) hasAnyValue = true;
      peak = math.max(
        peak,
        math.max(p.plannedCents / 100.0, p.spentCents / 100.0),
      );
    }
    final maxY = hasAnyValue ? peak * 1.2 : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Comparativo entre meses (Planejado × Utilizado)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Wrap(
                  spacing: 12,
                  children: [
                    _LegendItem(label: 'Planejado', color: AppColors.transfer),
                    _LegendItem(label: 'Utilizado', color: AppColors.expense),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 3,
                  ),
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
                          final idx = value.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              points[idx].label,
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].plannedCents / 100.0,
                            width: 11,
                            color: AppColors.transfer,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          BarChartRodData(
                            toY: points[i].spentCents / 100.0,
                            width: 11,
                            color: AppColors.expense,
                            borderRadius: BorderRadius.circular(5),
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

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
