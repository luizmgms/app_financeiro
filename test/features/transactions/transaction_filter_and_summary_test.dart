import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_summary.dart';
import 'package:finance_control/shared/models/date_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 17, 12, 0);

  TransactionEntity makeTx({
    required String id,
    required TransactionKind kind,
    required String description,
    required int amountCents,
    required TransactionStatus status,
    DateTime? competencyDate,
    DateTime? dueDate,
    String? categoryId,
    String? accountId,
    String? notes,
  }) {
    final comp = competencyDate ?? today;
    return TransactionEntity(
      id: id,
      kind: kind,
      description: description,
      amountCents: amountCents,
      categoryId: categoryId,
      accountId: accountId,
      competencyDate: comp,
      dueDate: dueDate,
      status: status,
      notes: notes,
      createdAt: comp,
      updatedAt: comp,
    );
  }

  test('TransactionEntity.effectiveStatus marks past-due pending expenses overdue',
      () {
    final overdueTx = makeTx(
      id: '1',
      kind: TransactionKind.expense,
      description: 'Internet',
      amountCents: 12000,
      status: TransactionStatus.pending,
      dueDate: DateTime(2026, 11, 16),
    );
    final dueTodayTx = makeTx(
      id: '2',
      kind: TransactionKind.expense,
      description: 'Energia',
      amountCents: 20000,
      status: TransactionStatus.pending,
      dueDate: DateTime(2026, 11, 17),
    );
    final paidPastDueTx = makeTx(
      id: '3',
      kind: TransactionKind.expense,
      description: 'Água',
      amountCents: 9000,
      status: TransactionStatus.paid,
      dueDate: DateTime(2026, 11, 10),
    );

    expect(overdueTx.effectiveStatus(today), TransactionStatus.overdue);
    expect(dueTodayTx.effectiveStatus(today), TransactionStatus.pending);
    expect(paidPastDueTx.effectiveStatus(today), TransactionStatus.paid);
  });

  test('TransactionPeriodSummary strictly excludes transfers and invoice payments',
      () {
    final list = <TransactionEntity>[
      makeTx(
        id: 'inc1',
        kind: TransactionKind.income,
        description: 'Salário',
        amountCents: 600000,
        status: TransactionStatus.received,
      ),
      makeTx(
        id: 'inc2',
        kind: TransactionKind.income,
        description: 'Freelance pendente',
        amountCents: 150000,
        status: TransactionStatus.pending,
      ),
      makeTx(
        id: 'exp1',
        kind: TransactionKind.expense,
        description: 'Supermercado',
        amountCents: 85000,
        status: TransactionStatus.paid,
      ),
      makeTx(
        id: 'exp2',
        kind: TransactionKind.expense,
        description: 'Aluguel atrasado',
        amountCents: 200000,
        status: TransactionStatus.pending,
        dueDate: DateTime(2026, 11, 10),
      ),
      makeTx(
        id: 'tr1',
        kind: TransactionKind.transfer,
        description: 'Transferência saída',
        amountCents: 300000,
        status: TransactionStatus.completed,
      ),
      makeTx(
        id: 'inv1',
        kind: TransactionKind.invoicePayment,
        description: 'Pagamento fatura',
        amountCents: 120000,
        status: TransactionStatus.completed,
      ),
    ];

    final summary =
        TransactionPeriodSummary.fromTransactions(list, now: today);

    expect(summary.totalIncomeCents, 750000);
    expect(summary.receivedIncomeCents, 600000);
    expect(summary.pendingIncomeCents, 150000);
    expect(summary.totalExpenseCents, 285000);
    expect(summary.paidExpenseCents, 85000);
    expect(summary.pendingExpenseCents, 200000);
    expect(summary.netResultCents, 465000);
  });

  test('TransactionFilter applies combined search, period, category, account and status',
      () {
    final txMatching = makeTx(
      id: '1',
      kind: TransactionKind.expense,
      description: 'Compra Supermercado Extra',
      amountCents: 25000,
      status: TransactionStatus.pending,
      dueDate: DateTime(2026, 11, 12),
      categoryId: 'cat_exp_food',
      accountId: 'acc_1',
      notes: 'Compras do mês',
    );
    final txOtherMonth = makeTx(
      id: '2',
      kind: TransactionKind.expense,
      description: 'Supermercado mês anterior',
      amountCents: 15000,
      status: TransactionStatus.paid,
      competencyDate: DateTime(2026, 10, 15),
      categoryId: 'cat_exp_food',
      accountId: 'acc_1',
    );

    final filter = TransactionFilter(
      period: DatePeriod.fromType(DatePeriodType.thisMonth, reference: today),
      searchQuery: 'extra',
      kind: TransactionKind.expense,
      categoryId: 'cat_exp_food',
      accountId: 'acc_1',
      statusFilter: TransactionStatusFilter.overdue,
    );

    expect(filter.matches(txMatching, now: today), isTrue);
    expect(filter.matches(txOtherMonth, now: today), isFalse);
  });
}
