import 'package:equatable/equatable.dart';
import '../../../../shared/models/date_period.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/budget_entity.dart';

enum BudgetHealthStatus {
  healthy('Dentro do limite'),
  warning('Próximo do limite'),
  exceeded('Ultrapassado');

  const BudgetHealthStatus(this.label);

  final String label;
}

class BudgetUsageItem extends Equatable {
  const BudgetUsageItem({
    required this.budget,
    required this.spentCents,
  });

  final BudgetEntity budget;
  final int spentCents;

  int get limitCents => budget.limitCents;

  int get remainingCents => limitCents - spentCents;

  double get consumedRatio =>
      limitCents <= 0 ? 0.0 : (spentCents / limitCents);

  int get consumedPercent => (consumedRatio * 100).round();

  BudgetHealthStatus get healthStatus {
    if (spentCents > limitCents) return BudgetHealthStatus.exceeded;
    if (consumedPercent >= budget.alertThresholdPercent) {
      return BudgetHealthStatus.warning;
    }
    return BudgetHealthStatus.healthy;
  }

  @override
  List<Object?> get props => [budget, spentCents];
}

class MonthlyBudgetComparisonPoint extends Equatable {
  const MonthlyBudgetComparisonPoint({
    required this.year,
    required this.month,
    required this.label,
    required this.plannedCents,
    required this.spentCents,
  });

  final int year;
  final int month;
  final String label;
  final int plannedCents;
  final int spentCents;

  @override
  List<Object?> get props => [year, month, label, plannedCents, spentCents];
}

/// Serviço puro para cálculo de consumo mensal de orçamentos e comparativo entre meses.
abstract final class BudgetCalculator {
  /// Soma gastos líquidos por `categoryId` dentro do mês contábil `(year, month)`.
  /// Contabiliza `expense` e `cardPurchase`, abate `cardRefund`, e ignora `transfer` e `invoicePayment`.
  static Map<String, int> spentByCategoryForMonth({
    required Iterable<TransactionEntity> transactions,
    required int year,
    required int month,
    int monthStartDay = 1,
  }) {
    final range = DatePeriod.accountingMonth(
      year,
      month,
      monthStartDay: monthStartDay,
    );
    final result = <String, int>{};

    for (final tx in transactions) {
      if (!tx.kind.countsAsIncomeOrExpense || tx.kind == TransactionKind.income) {
        continue;
      }
      if (!range.contains(tx.competencyDate)) continue;
      final catId = tx.categoryId;
      if (catId == null || catId.isEmpty) continue;

      final signed = tx.kind == TransactionKind.cardRefund
          ? -tx.amountCents
          : tx.amountCents;
      result[catId] = (result[catId] ?? 0) + signed;
    }

    result.updateAll((_, value) => value < 0 ? 0 : value);
    return result;
  }

  static List<BudgetUsageItem> evaluateMonth({
    required Iterable<BudgetEntity> budgets,
    required Iterable<TransactionEntity> transactions,
    required int year,
    required int month,
    int monthStartDay = 1,
  }) {
    final spentMap = spentByCategoryForMonth(
      transactions: transactions,
      year: year,
      month: month,
      monthStartDay: monthStartDay,
    );

    final items = budgets
        .where((b) => b.year == year && b.month == month)
        .map(
          (b) => BudgetUsageItem(
            budget: b,
            spentCents: spentMap[b.categoryId] ?? 0,
          ),
        )
        .toList(growable: false);

    items.sort((a, b) => b.consumedRatio.compareTo(a.consumedRatio));
    return items;
  }

  /// Gera série comparativa de Planejado x Utilizado para os últimos [monthsCount] meses
  /// terminando em `(endYear, endMonth)`.
  static List<MonthlyBudgetComparisonPoint> buildMonthlyComparison({
    required Iterable<BudgetEntity> budgets,
    required Iterable<TransactionEntity> transactions,
    required int endYear,
    required int endMonth,
    int monthsCount = 6,
    int monthStartDay = 1,
  }) {
    final points = <MonthlyBudgetComparisonPoint>[];
    for (var offset = monthsCount - 1; offset >= 0; offset--) {
      final anchor = DateTime(endYear, endMonth - offset, 1);
      final usages = evaluateMonth(
        budgets: budgets,
        transactions: transactions,
        year: anchor.year,
        month: anchor.month,
        monthStartDay: monthStartDay,
      );
      final planned = usages.fold<int>(0, (s, u) => s + u.limitCents);
      final spent = usages.fold<int>(0, (s, u) => s + u.spentCents);
      final mm = anchor.month.toString().padLeft(2, '0');
      points.add(
        MonthlyBudgetComparisonPoint(
          year: anchor.year,
          month: anchor.month,
          label: '$mm/${anchor.year % 100}',
          plannedCents: planned,
          spentCents: spent,
        ),
      );
    }
    return points;
  }
}
