import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/date_period.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../../credit_cards/domain/entities/invoice_entity.dart';
import '../../../installments/domain/entities/installment_plan_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_filter.dart';
import '../../../transactions/domain/entities/transaction_summary.dart';

class CategoryBreakdownItem extends Equatable {
  const CategoryBreakdownItem({
    required this.categoryId,
    required this.name,
    required this.colorHex,
    required this.amountCents,
    required this.percentage,
  });

  final String categoryId;
  final String name;
  final String colorHex;
  final int amountCents;
  final double percentage;

  @override
  List<Object?> get props => [categoryId, name, colorHex, amountCents, percentage];
}

class AccountBreakdownItem extends Equatable {
  const AccountBreakdownItem({
    required this.accountId,
    required this.name,
    required this.currentBalanceCents,
    required this.incomeCents,
    required this.expenseCents,
  });

  final String accountId;
  final String name;
  final int currentBalanceCents;
  final int incomeCents;
  final int expenseCents;

  @override
  List<Object?> get props =>
      [accountId, name, currentBalanceCents, incomeCents, expenseCents];
}

class CardBreakdownItem extends Equatable {
  const CardBreakdownItem({
    required this.cardId,
    required this.name,
    required this.totalLimitCents,
    required this.usedLimitCents,
    required this.periodExpenseCents,
    required this.openInvoicesCents,
  });

  final String cardId;
  final String name;
  final int totalLimitCents;
  final int usedLimitCents;
  final int periodExpenseCents;
  final int openInvoicesCents;

  @override
  List<Object?> get props => [
        cardId,
        name,
        totalLimitCents,
        usedLimitCents,
        periodExpenseCents,
        openInvoicesCents,
      ];
}

class MonthlyEvolutionPoint extends Equatable {
  const MonthlyEvolutionPoint({
    required this.year,
    required this.month,
    required this.label,
    required this.incomeCents,
    required this.expenseCents,
    required this.netCents,
    required this.equityBalanceCents,
  });

  final int year;
  final int month;
  final String label;
  final int incomeCents;
  final int expenseCents;
  final int netCents;
  final int equityBalanceCents;

  @override
  List<Object?> get props => [
        year,
        month,
        label,
        incomeCents,
        expenseCents,
        netCents,
        equityBalanceCents,
      ];
}

class ProjectionHorizonPoint extends Equatable {
  const ProjectionHorizonPoint({
    required this.daysAhead,
    required this.label,
    required this.expectedIncomeCents,
    required this.expectedOutflowCents,
    required this.projectedBalanceCents,
  });

  final int daysAhead;
  final String label;
  final int expectedIncomeCents;
  final int expectedOutflowCents;
  final int projectedBalanceCents;

  @override
  List<Object?> get props => [
        daysAhead,
        label,
        expectedIncomeCents,
        expectedOutflowCents,
        projectedBalanceCents,
      ];
}

class CashFlowSummary extends Equatable {
  const CashFlowSummary({
    required this.inflowsCents,
    required this.outflowsCents,
  });

  final int inflowsCents;
  final int outflowsCents;

  int get netCashFlowCents => inflowsCents - outflowsCents;

  @override
  List<Object?> get props => [inflowsCents, outflowsCents];
}

class PayablesStatusSummary extends Equatable {
  const PayablesStatusSummary({
    required this.paidCount,
    required this.paidCents,
    required this.pendingCount,
    required this.pendingCents,
    required this.overdueCount,
    required this.overdueCents,
  });

  final int paidCount;
  final int paidCents;
  final int pendingCount;
  final int pendingCents;
  final int overdueCount;
  final int overdueCents;

  @override
  List<Object?> get props => [
        paidCount,
        paidCents,
        pendingCount,
        pendingCents,
        overdueCount,
        overdueCents,
      ];
}

class InstallmentsPortfolioSummary extends Equatable {
  const InstallmentsPortfolioSummary({
    required this.activePlansCount,
    required this.totalContractedCents,
    required this.paidCents,
    required this.futureCommittedCents,
  });

  final int activePlansCount;
  final int totalContractedCents;
  final int paidCents;
  final int futureCommittedCents;

  @override
  List<Object?> get props => [
        activePlansCount,
        totalContractedCents,
        paidCents,
        futureCommittedCents,
      ];
}

class UpcomingDueItem extends Equatable {
  const UpcomingDueItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dueDate,
    required this.amountCents,
    required this.isOverdue,
    required this.isInvoice,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime dueDate;
  final int amountCents;
  final bool isOverdue;
  final bool isInvoice;

  @override
  List<Object?> get props =>
      [id, title, subtitle, dueDate, amountCents, isOverdue, isInvoice];
}

class ReportSnapshot extends Equatable {
  const ReportSnapshot({
    required this.period,
    required this.summary,
    required this.totalBalanceCents,
    required this.projectedEndOfMonthCents,
    required this.totalOpenInvoicesCents,
    required this.cashFlow,
    required this.payablesStatus,
    required this.installmentsPortfolio,
    required this.byCategory,
    required this.byAccount,
    required this.byCard,
    required this.monthlyEvolution,
    required this.projections,
    required this.upcomingDueItems,
    required this.periodTransactions,
  });

  final DatePeriod period;
  final TransactionPeriodSummary summary;
  final int totalBalanceCents;
  final int projectedEndOfMonthCents;
  final int totalOpenInvoicesCents;
  final CashFlowSummary cashFlow;
  final PayablesStatusSummary payablesStatus;
  final InstallmentsPortfolioSummary installmentsPortfolio;
  final List<CategoryBreakdownItem> byCategory;
  final List<AccountBreakdownItem> byAccount;
  final List<CardBreakdownItem> byCard;
  final List<MonthlyEvolutionPoint> monthlyEvolution;
  final List<ProjectionHorizonPoint> projections;
  final List<UpcomingDueItem> upcomingDueItems;
  final List<TransactionEntity> periodTransactions;

  @override
  List<Object?> get props => [
        period,
        summary,
        totalBalanceCents,
        projectedEndOfMonthCents,
        totalOpenInvoicesCents,
        cashFlow,
        payablesStatus,
        installmentsPortfolio,
        byCategory,
        byAccount,
        byCard,
        monthlyEvolution,
        projections,
        upcomingDueItems,
        periodTransactions,
      ];
}

/// Motor puro de agregação analítica para Dashboard, Relatórios e Exportação.
/// Reaproveita as regras contábeis do sistema: transferências e pagamentos de fatura
/// não duplicam despesas nos relatórios de competência, enquanto fluxo de caixa e
/// projeções consideram movimentações reais em conta e faturas em aberto sem dupla contagem.
abstract final class FinancialAnalyticsService {
  static ReportSnapshot buildSnapshot({
    required DatePeriod period,
    required List<TransactionEntity> allTransactions,
    required List<AccountEntity> accounts,
    required List<CreditCardEntity> cards,
    required List<InvoiceEntity> invoices,
    required List<InstallmentPlanEntity> installmentPlans,
    required Map<String, CategoryEntity> categoriesById,
    DateTime? referenceDate,
    int monthStartDay = 1,
  }) {
    final now = referenceDate ?? DateTime.now();
    final activeAccounts =
        accounts.where((a) => a.isActive).toList(growable: false);
    final totalBalanceCents = activeAccounts.fold<int>(
      0,
      (sum, acc) => sum + acc.currentBalanceCents,
    );

    final periodFilter = TransactionFilter(period: period);
    final periodTransactions = allTransactions
        .where(periodFilter.matches)
        .toList()
      ..sort(TransactionEntity.compareByRecencyDesc);
    final summary = TransactionPeriodSummary.fromTransactions(
      periodTransactions,
      now: now,
    );

    final openInvoicesCents = invoices
        .where((inv) => inv.status != InvoiceStatus.paid)
        .fold<int>(0, (sum, inv) => sum + inv.remainingAmountCents);

    final projectedEnd = computeProjectedBalanceUntil(
      horizonEnd: period.end,
      totalBalanceCents: totalBalanceCents,
      allTransactions: allTransactions,
      invoices: invoices,
    );

    final cashFlow = computeCashFlow(periodTransactions);
    final payablesStatus = computePayablesStatus(periodTransactions, now: now);
    final installmentsPortfolio = computeInstallmentsPortfolio(
      plans: installmentPlans,
      allTransactions: allTransactions,
    );
    final byCategory = computeCategoryBreakdown(
      transactions: periodTransactions,
      categoriesById: categoriesById,
    );
    final byAccount = computeAccountBreakdown(
      transactions: periodTransactions,
      accounts: accounts,
    );
    final byCard = computeCardBreakdown(
      transactions: periodTransactions,
      cards: cards,
      invoices: invoices,
    );
    final monthlyEvolution = computeMonthlyEvolution(
      allTransactions: allTransactions,
      currentAccountsBalanceCents: totalBalanceCents,
      referenceDate: now,
      monthStartDay: monthStartDay,
      monthsCount: 6,
    );
    final projections = computeFutureProjections(
      totalBalanceCents: totalBalanceCents,
      allTransactions: allTransactions,
      invoices: invoices,
      referenceDate: now,
    );
    final upcomingDueItems = computeUpcomingDueItems(
      allTransactions: allTransactions,
      invoices: invoices,
      cards: cards,
      accounts: accounts,
      referenceDate: now,
    );

    return ReportSnapshot(
      period: period,
      summary: summary,
      totalBalanceCents: totalBalanceCents,
      projectedEndOfMonthCents: projectedEnd,
      totalOpenInvoicesCents: openInvoicesCents,
      cashFlow: cashFlow,
      payablesStatus: payablesStatus,
      installmentsPortfolio: installmentsPortfolio,
      byCategory: byCategory,
      byAccount: byAccount,
      byCard: byCard,
      monthlyEvolution: monthlyEvolution,
      projections: projections,
      upcomingDueItems: upcomingDueItems,
      periodTransactions: periodTransactions,
    );
  }

  /// Calcula saldo projetado futuro até [horizonEnd], considerando apenas
  /// receitas/despesas pendentes em conta e faturas não quitadas com vencimento até [horizonEnd],
  /// evitando dupla contagem entre compras no cartão e faturas.
  static int computeProjectedBalanceUntil({
    required DateTime horizonEnd,
    required int totalBalanceCents,
    required Iterable<TransactionEntity> allTransactions,
    required Iterable<InvoiceEntity> invoices,
  }) {
    var pendingAccountIncome = 0;
    var pendingAccountExpense = 0;

    for (final tx in allTransactions) {
      if (tx.status.isSettled) continue;
      if (tx.kind == TransactionKind.income) {
        final target = tx.dueDate ?? tx.competencyDate;
        if (!target.isAfter(horizonEnd)) {
          pendingAccountIncome += tx.amountCents;
        }
      } else if (tx.kind == TransactionKind.expense) {
        final target = tx.dueDate ?? tx.competencyDate;
        if (!target.isAfter(horizonEnd)) {
          pendingAccountExpense += tx.amountCents;
        }
      }
    }

    var unpaidInvoicesDue = 0;
    for (final inv in invoices) {
      if (inv.status == InvoiceStatus.paid || inv.remainingAmountCents <= 0) {
        continue;
      }
      if (!inv.dueDate.isAfter(horizonEnd)) {
        unpaidInvoicesDue += inv.remainingAmountCents;
      }
    }

    return totalBalanceCents +
        pendingAccountIncome -
        pendingAccountExpense -
        unpaidInvoicesDue;
  }

  /// Fluxo de caixa real (entradas e saídas efetivamente liquidadas em conta no período).
  static CashFlowSummary computeCashFlow(
    Iterable<TransactionEntity> periodTransactions,
  ) {
    var inflows = 0;
    var outflows = 0;

    for (final tx in periodTransactions) {
      if (!tx.status.isSettled) continue;
      switch (tx.kind) {
        case TransactionKind.income:
          inflows += tx.amountCents;
          break;
        case TransactionKind.expense:
        case TransactionKind.invoicePayment:
          outflows += tx.amountCents;
          break;
        case TransactionKind.transfer:
        case TransactionKind.cardPurchase:
        case TransactionKind.cardRefund:
          break;
      }
    }

    return CashFlowSummary(inflowsCents: inflows, outflowsCents: outflows);
  }

  static PayablesStatusSummary computePayablesStatus(
    Iterable<TransactionEntity> periodTransactions, {
    DateTime? now,
  }) {
    var paidCount = 0;
    var paidCents = 0;
    var pendingCount = 0;
    var pendingCents = 0;
    var overdueCount = 0;
    var overdueCents = 0;

    for (final tx in periodTransactions) {
      if (tx.kind != TransactionKind.expense &&
          tx.kind != TransactionKind.cardPurchase) {
        continue;
      }
      final eff = tx.effectiveStatus(now);
      if (eff.isSettled) {
        paidCount++;
        paidCents += tx.amountCents;
      } else if (eff == TransactionStatus.overdue) {
        overdueCount++;
        overdueCents += tx.amountCents;
      } else {
        pendingCount++;
        pendingCents += tx.amountCents;
      }
    }

    return PayablesStatusSummary(
      paidCount: paidCount,
      paidCents: paidCents,
      pendingCount: pendingCount,
      pendingCents: pendingCents,
      overdueCount: overdueCount,
      overdueCents: overdueCents,
    );
  }

  static InstallmentsPortfolioSummary computeInstallmentsPortfolio({
    required Iterable<InstallmentPlanEntity> plans,
    required Iterable<TransactionEntity> allTransactions,
  }) {
    final activePlans = plans
        .where((p) => p.status != InstallmentPlanStatus.canceled)
        .toList(growable: false);
    final activePlanIds = activePlans.map((p) => p.id).toSet();

    var totalContracted = 0;
    for (final p in activePlans) {
      totalContracted += p.totalAmountCents;
    }

    var paid = 0;
    var futureCommitted = 0;
    var activeCount = 0;

    final pendingByPlan = <String, int>{};
    for (final tx in allTransactions) {
      final planId = tx.installmentPlanId;
      if (planId == null || !activePlanIds.contains(planId)) continue;
      if (tx.status.isSettled) {
        paid += tx.amountCents;
      } else {
        futureCommitted += tx.amountCents;
        pendingByPlan[planId] = (pendingByPlan[planId] ?? 0) + 1;
      }
    }

    for (final p in activePlans) {
      if ((pendingByPlan[p.id] ?? 0) > 0 ||
          p.status == InstallmentPlanStatus.active) {
        activeCount++;
      }
    }

    return InstallmentsPortfolioSummary(
      activePlansCount: activeCount,
      totalContractedCents: totalContracted,
      paidCents: paid,
      futureCommittedCents: futureCommitted,
    );
  }

  static List<CategoryBreakdownItem> computeCategoryBreakdown({
    required Iterable<TransactionEntity> transactions,
    required Map<String, CategoryEntity> categoriesById,
  }) {
    final byCat = <String, int>{};
    for (final tx in transactions) {
      if (!tx.kind.countsAsIncomeOrExpense || tx.kind == TransactionKind.income) {
        continue;
      }
      final catId = tx.categoryId ?? 'sem_categoria';
      final delta =
          tx.kind == TransactionKind.cardRefund ? -tx.amountCents : tx.amountCents;
      byCat[catId] = (byCat[catId] ?? 0) + delta;
    }

    byCat.removeWhere((_, value) => value <= 0);
    final total = byCat.values.fold<int>(0, (s, v) => s + v);
    if (total <= 0) return const <CategoryBreakdownItem>[];

    final list = byCat.entries.map((entry) {
      final cat = categoriesById[entry.key];
      return CategoryBreakdownItem(
        categoryId: entry.key,
        name: cat?.name ?? 'Outras despesas',
        colorHex: cat?.colorHex ?? '#64748B',
        amountCents: entry.value,
        percentage: (entry.value / total) * 100.0,
      );
    }).toList(growable: false);

    list.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return list;
  }

  static List<AccountBreakdownItem> computeAccountBreakdown({
    required Iterable<TransactionEntity> transactions,
    required Iterable<AccountEntity> accounts,
  }) {
    final incomeMap = <String, int>{};
    final expenseMap = <String, int>{};

    for (final tx in transactions) {
      final accId = tx.accountId;
      if (accId == null || accId.isEmpty) continue;
      if (tx.kind == TransactionKind.income) {
        incomeMap[accId] = (incomeMap[accId] ?? 0) + tx.amountCents;
      } else if (tx.kind == TransactionKind.expense ||
          tx.kind == TransactionKind.invoicePayment) {
        expenseMap[accId] = (expenseMap[accId] ?? 0) + tx.amountCents;
      }
    }

    final result = accounts
        .where(
          (acc) =>
              acc.isActive ||
              incomeMap.containsKey(acc.id) ||
              expenseMap.containsKey(acc.id),
        )
        .map(
          (acc) => AccountBreakdownItem(
            accountId: acc.id,
            name: acc.name,
            currentBalanceCents: acc.currentBalanceCents,
            incomeCents: incomeMap[acc.id] ?? 0,
            expenseCents: expenseMap[acc.id] ?? 0,
          ),
        )
        .toList(growable: false);

    result.sort((a, b) => b.expenseCents.compareTo(a.expenseCents));
    return result;
  }

  static List<CardBreakdownItem> computeCardBreakdown({
    required Iterable<TransactionEntity> transactions,
    required Iterable<CreditCardEntity> cards,
    required Iterable<InvoiceEntity> invoices,
  }) {
    final expenseByCard = <String, int>{};
    for (final tx in transactions) {
      final cardId = tx.cardId;
      if (cardId == null || cardId.isEmpty) continue;
      if (tx.kind == TransactionKind.cardPurchase) {
        expenseByCard[cardId] = (expenseByCard[cardId] ?? 0) + tx.amountCents;
      } else if (tx.kind == TransactionKind.cardRefund) {
        expenseByCard[cardId] = (expenseByCard[cardId] ?? 0) - tx.amountCents;
      }
    }

    final openInvoicesByCard = <String, int>{};
    for (final inv in invoices) {
      if (inv.status == InvoiceStatus.paid) continue;
      openInvoicesByCard[inv.cardId] =
          (openInvoicesByCard[inv.cardId] ?? 0) + inv.remainingAmountCents;
    }

    final result = cards
        .where(
          (card) =>
              card.isActive ||
              expenseByCard.containsKey(card.id) ||
              (openInvoicesByCard[card.id] ?? 0) > 0,
        )
        .map(
          (card) => CardBreakdownItem(
            cardId: card.id,
            name: card.name,
            totalLimitCents: card.totalLimitCents,
            usedLimitCents: card.usedLimitCents,
            periodExpenseCents: math.max(0, expenseByCard[card.id] ?? 0),
            openInvoicesCents: openInvoicesByCard[card.id] ?? 0,
          ),
        )
        .toList(growable: false);

    result.sort((a, b) => b.periodExpenseCents.compareTo(a.periodExpenseCents));
    return result;
  }

  static List<MonthlyEvolutionPoint> computeMonthlyEvolution({
    required Iterable<TransactionEntity> allTransactions,
    required int currentAccountsBalanceCents,
    required DateTime referenceDate,
    int monthStartDay = 1,
    int monthsCount = 6,
  }) {
    final currentYm = DatePeriod.resolveAccountingYearMonth(
      referenceDate,
      monthStartDay: monthStartDay,
    );

    final ranges = <({int year, int month, DatePeriod range})>[];
    for (var offset = monthsCount - 1; offset >= 0; offset--) {
      final anchor = DateTime(currentYm.year, currentYm.month - offset, 1);
      ranges.add((
        year: anchor.year,
        month: anchor.month,
        range: DatePeriod.accountingMonth(
          anchor.year,
          anchor.month,
          monthStartDay: monthStartDay,
        ),
      ));
    }

    // Calcula fluxos de caixa líquidos realizados por mês para reconstruir a curva
    // de evolução patrimonial ancorada no saldo real atual das contas.
    final realizedNetPerMonth = List<int>.filled(ranges.length, 0);
    final summaries = <TransactionPeriodSummary>[];

    for (var i = 0; i < ranges.length; i++) {
      final r = ranges[i].range;
      final txs = allTransactions
          .where((tx) => r.contains(tx.competencyDate))
          .toList(growable: false);
      summaries.add(
        TransactionPeriodSummary.fromTransactions(txs, now: referenceDate),
      );

      final flow = computeCashFlow(txs);
      realizedNetPerMonth[i] = flow.netCashFlowCents;
    }

    final equities = List<int>.filled(ranges.length, currentAccountsBalanceCents);
    for (var i = ranges.length - 2; i >= 0; i--) {
      equities[i] = equities[i + 1] - realizedNetPerMonth[i + 1];
    }

    return List<MonthlyEvolutionPoint>.generate(ranges.length, (i) {
      final info = ranges[i];
      final summary = summaries[i];
      final mm = info.month.toString().padLeft(2, '0');
      final yy = (info.year % 100).toString().padLeft(2, '0');
      return MonthlyEvolutionPoint(
        year: info.year,
        month: info.month,
        label: '$mm/$yy',
        incomeCents: summary.totalIncomeCents,
        expenseCents: summary.totalExpenseCents,
        netCents: summary.netResultCents,
        equityBalanceCents: equities[i],
      );
    });
  }

  static List<ProjectionHorizonPoint> computeFutureProjections({
    required int totalBalanceCents,
    required Iterable<TransactionEntity> allTransactions,
    required Iterable<InvoiceEntity> invoices,
    required DateTime referenceDate,
  }) {
    final todayEnd = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      23,
      59,
      59,
      999,
    );

    const horizons = [30, 60, 90];
    final points = <ProjectionHorizonPoint>[];

    for (final days in horizons) {
      final horizonEnd = todayEnd.add(Duration(days: days));
      var inc = 0;
      var out = 0;

      for (final tx in allTransactions) {
        if (tx.status.isSettled) continue;
        final due = tx.dueDate ?? tx.competencyDate;
        if (due.isAfter(horizonEnd)) continue;
        if (tx.kind == TransactionKind.income) {
          inc += tx.amountCents;
        } else if (tx.kind == TransactionKind.expense) {
          out += tx.amountCents;
        }
      }

      for (final inv in invoices) {
        if (inv.status == InvoiceStatus.paid || inv.remainingAmountCents <= 0) {
          continue;
        }
        if (!inv.dueDate.isAfter(horizonEnd)) {
          out += inv.remainingAmountCents;
        }
      }

      points.add(
        ProjectionHorizonPoint(
          daysAhead: days,
          label: '+$days dias',
          expectedIncomeCents: inc,
          expectedOutflowCents: out,
          projectedBalanceCents: totalBalanceCents + inc - out,
        ),
      );
    }

    return points;
  }

  static List<UpcomingDueItem> computeUpcomingDueItems({
    required Iterable<TransactionEntity> allTransactions,
    required Iterable<InvoiceEntity> invoices,
    required Iterable<CreditCardEntity> cards,
    required Iterable<AccountEntity> accounts,
    required DateTime referenceDate,
    int daysAhead = 15,
  }) {
    final todayStart = DateFormatter.dateOnly(referenceDate);
    final limitDay = todayStart.add(Duration(days: daysAhead));
    final cardsMap = {for (final c in cards) c.id: c.name};
    final accountsMap = {for (final a in accounts) a.id: a.name};
    final items = <UpcomingDueItem>[];

    for (final tx in allTransactions) {
      if (tx.status.isSettled || tx.kind != TransactionKind.expense) continue;
      final dueDay = DateFormatter.dateOnly(tx.dueDate ?? tx.competencyDate);
      if (dueDay.isAfter(limitDay)) continue;
      items.add(
        UpcomingDueItem(
          id: tx.id,
          title: tx.description,
          subtitle: tx.accountId != null
              ? (accountsMap[tx.accountId!] ?? 'Conta')
              : 'Conta a pagar',
          dueDate: dueDay,
          amountCents: tx.amountCents,
          isOverdue: dueDay.isBefore(todayStart),
          isInvoice: false,
        ),
      );
    }

    for (final inv in invoices) {
      if (inv.status == InvoiceStatus.paid || inv.remainingAmountCents <= 0) {
        continue;
      }
      final dueDay = DateFormatter.dateOnly(inv.dueDate);
      if (dueDay.isAfter(limitDay)) continue;
      items.add(
        UpcomingDueItem(
          id: inv.id,
          title: 'Fatura ${cardsMap[inv.cardId] ?? 'Cartão'} (${inv.referenceLabel})',
          subtitle: 'Cartão de crédito',
          dueDate: dueDay,
          amountCents: inv.remainingAmountCents,
          isOverdue: dueDay.isBefore(todayStart),
          isInvoice: true,
        ),
      );
    }

    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }
}
