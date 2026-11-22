import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/services/financial_analytics_service.dart';

/// Gráfico de pizza/rosca com detalhamento de despesas por categoria usando `fl_chart`.
class CategoryExpensesPieChartCard extends StatelessWidget {
  const CategoryExpensesPieChartCard({
    super.key,
    required this.items,
    required this.locale,
    required this.currencyCode,
    this.title = 'Despesas por categoria',
    this.onActionTap,
    this.actionLabel,
  });

  final List<CategoryBreakdownItem> items;
  final String locale;
  final String currencyCode;
  final String title;
  final VoidCallback? onActionTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topItems = items.take(6).toList(growable: false);

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
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onActionTap != null && actionLabel != null)
                  TextButton(
                    onPressed: onActionTap,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (topItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Sem despesas por categoria neste período.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 460;
                  final chart = SizedBox(
                    height: 180,
                    width: isWide ? 180 : double.infinity,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 36,
                        sectionsSpace: 2,
                        sections: [
                          for (final item in topItems)
                            PieChartSectionData(
                              value: item.amountCents / 100.0,
                              color: ColorUtils.fromHex(
                                item.colorHex,
                                fallback: AppColors.primaryLight,
                              ),
                              radius: 44,
                              title: item.percentage >= 8
                                  ? '${item.percentage.toStringAsFixed(0)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );

                  final legend = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in topItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: ColorUtils.fromHex(
                                    item.colorHex,
                                    fallback: AppColors.primaryLight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${CurrencyFormatter.formatCents(item.amountCents, locale: locale, currencyCode: currencyCode)} (${item.percentage.toStringAsFixed(0)}%)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        chart,
                        const SizedBox(width: 18),
                        Expanded(child: legend),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: 14),
                      legend,
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

/// Gráfico de linha para evolução financeira e patrimonial nos últimos meses.
class MonthlyEvolutionLineChartCard extends StatelessWidget {
  const MonthlyEvolutionLineChartCard({
    super.key,
    required this.points,
    this.title = 'Evolução financeira mensal',
    this.showEquityLine = true,
  });

  final List<MonthlyEvolutionPoint> points;
  final String title;
  final bool showEquityLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var minY = 0.0;
    var maxY = 100.0;
    var hasData = false;

    for (final p in points) {
      final inc = p.incomeCents / 100.0;
      final exp = p.expenseCents / 100.0;
      final eq = p.equityBalanceCents / 100.0;
      if (inc > 0 || exp > 0 || eq != 0) hasData = true;
      maxY = math.max(maxY, math.max(inc, math.max(exp, showEquityLine ? eq : 0)));
      if (showEquityLine) minY = math.min(minY, eq);
    }

    final span = math.max(100.0, maxY - minY);
    final paddedMax = hasData ? maxY + span * 0.15 : 100.0;
    final paddedMin = minY < 0 ? minY - span * 0.1 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    const _ChartLegendDot(
                      label: 'Receitas',
                      color: AppColors.income,
                    ),
                    const _ChartLegendDot(
                      label: 'Despesas',
                      color: AppColors.expense,
                    ),
                    if (showEquityLine)
                      const _ChartLegendDot(
                        label: 'Patrimônio',
                        color: AppColors.transfer,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 200,
              child: points.isEmpty
                  ? Center(
                      child: Text(
                        'Sem histórico mensal suficiente.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: paddedMin,
                        maxY: paddedMax,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: math.max(1, (paddedMax - paddedMin) / 4),
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
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 ||
                                    idx >= points.length ||
                                    value != idx.toDouble()) {
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
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < points.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  points[i].incomeCents / 100.0,
                                ),
                            ],
                            isCurved: true,
                            color: AppColors.income,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: true),
                          ),
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < points.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  points[i].expenseCents / 100.0,
                                ),
                            ],
                            isCurved: true,
                            color: AppColors.expense,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: true),
                          ),
                          if (showEquityLine)
                            LineChartBarData(
                              spots: [
                                for (var i = 0; i < points.length; i++)
                                  FlSpot(
                                    i.toDouble(),
                                    points[i].equityBalanceCents / 100.0,
                                  ),
                              ],
                              isCurved: true,
                              color: AppColors.transfer,
                              barWidth: 2.5,
                              dashArray: [6, 4],
                              dotData: const FlDotData(show: true),
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

/// Gráfico de barras comparativo mês a mês (Receitas × Despesas).
class MonthlyComparisonBarChartCard extends StatelessWidget {
  const MonthlyComparisonBarChartCard({
    super.key,
    required this.points,
    this.title = 'Comparativo mensal (Receitas × Despesas)',
  });

  final List<MonthlyEvolutionPoint> points;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var peak = 100.0;
    var hasAny = false;
    for (final p in points) {
      if (p.incomeCents > 0 || p.expenseCents > 0) hasAny = true;
      peak = math.max(
        peak,
        math.max(p.incomeCents / 100.0, p.expenseCents / 100.0),
      );
    }
    final maxY = hasAny ? peak * 1.2 : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Wrap(
                  spacing: 12,
                  children: [
                    _ChartLegendDot(label: 'Receitas', color: AppColors.income),
                    _ChartLegendDot(
                      label: 'Despesas',
                      color: AppColors.expense,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
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
                            toY: points[i].incomeCents / 100.0,
                            width: 11,
                            color: AppColors.income,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          BarChartRodData(
                            toY: points[i].expenseCents / 100.0,
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

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.label, required this.color});

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
