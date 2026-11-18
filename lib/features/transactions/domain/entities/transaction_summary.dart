import 'package:equatable/equatable.dart';
import 'transaction_entity.dart';

/// Consolidação financeira de um conjunto de movimentações, excluindo
/// transferências e pagamentos de fatura da contagem de receitas/despesas.
class TransactionPeriodSummary extends Equatable {
  const TransactionPeriodSummary({
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.receivedIncomeCents,
    required this.paidExpenseCents,
    required this.pendingIncomeCents,
    required this.pendingExpenseCents,
  });

  const TransactionPeriodSummary.empty()
      : totalIncomeCents = 0,
        totalExpenseCents = 0,
        receivedIncomeCents = 0,
        paidExpenseCents = 0,
        pendingIncomeCents = 0,
        pendingExpenseCents = 0;

  factory TransactionPeriodSummary.fromTransactions(
    Iterable<TransactionEntity> transactions, {
    DateTime? now,
  }) {
    var totalIncome = 0;
    var totalExpense = 0;
    var receivedIncome = 0;
    var paidExpense = 0;
    var pendingIncome = 0;
    var pendingExpense = 0;

    for (final tx in transactions) {
      if (!tx.kind.countsAsIncomeOrExpense) continue;
      final effStatus = tx.effectiveStatus(now);

      if (tx.kind == TransactionKind.income) {
        totalIncome += tx.amountCents;
        if (effStatus == TransactionStatus.received || effStatus.isSettled) {
          receivedIncome += tx.amountCents;
        } else {
          pendingIncome += tx.amountCents;
        }
      } else {
        totalExpense += tx.amountCents;
        if (effStatus == TransactionStatus.paid || effStatus.isSettled) {
          paidExpense += tx.amountCents;
        } else {
          pendingExpense += tx.amountCents;
        }
      }
    }

    return TransactionPeriodSummary(
      totalIncomeCents: totalIncome,
      totalExpenseCents: totalExpense,
      receivedIncomeCents: receivedIncome,
      paidExpenseCents: paidExpense,
      pendingIncomeCents: pendingIncome,
      pendingExpenseCents: pendingExpense,
    );
  }

  final int totalIncomeCents;
  final int totalExpenseCents;
  final int receivedIncomeCents;
  final int paidExpenseCents;
  final int pendingIncomeCents;
  final int pendingExpenseCents;

  int get netResultCents => totalIncomeCents - totalExpenseCents;

  @override
  List<Object?> get props => [
        totalIncomeCents,
        totalExpenseCents,
        receivedIncomeCents,
        paidExpenseCents,
        pendingIncomeCents,
        pendingExpenseCents,
      ];
}
