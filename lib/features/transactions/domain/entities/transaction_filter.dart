import 'package:equatable/equatable.dart';
import '../../../../shared/models/date_period.dart';
import 'transaction_entity.dart';

enum TransactionStatusFilter {
  all('Todos os status'),
  settled('Pagas / Recebidas'),
  pending('Pendentes'),
  overdue('Atrasadas');

  const TransactionStatusFilter(this.label);

  final String label;
}

/// Critérios combinados de filtragem para movimentações e extrato de contas.
class TransactionFilter extends Equatable {
  const TransactionFilter({
    required this.period,
    this.searchQuery = '',
    this.kind,
    this.categoryId,
    this.accountId,
    this.statusFilter = TransactionStatusFilter.all,
  });

  factory TransactionFilter.initial({DateTime? reference}) {
    return TransactionFilter(
      period: DatePeriod.fromType(DatePeriodType.thisMonth, reference: reference),
    );
  }

  final DatePeriod period;
  final String searchQuery;
  final TransactionKind? kind;
  final String? categoryId;
  final String? accountId;
  final TransactionStatusFilter statusFilter;

  bool get hasActiveSecondaryFilters =>
      searchQuery.trim().isNotEmpty ||
      kind != null ||
      categoryId != null ||
      accountId != null ||
      statusFilter != TransactionStatusFilter.all;

  bool matches(TransactionEntity tx, {DateTime? now}) {
    final comp = tx.competencyDate;
    final periodStart = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );
    final periodEnd = DateTime(
      period.end.year,
      period.end.month,
      period.end.day,
      23,
      59,
      59,
      999,
    );
    if (comp.isBefore(periodStart) || comp.isAfter(periodEnd)) {
      return false;
    }

    if (kind != null && tx.kind != kind) {
      return false;
    }

    if (categoryId != null && tx.categoryId != categoryId) {
      return false;
    }

    if (accountId != null && tx.accountId != accountId) {
      return false;
    }

    final effStatus = tx.effectiveStatus(now);
    switch (statusFilter) {
      case TransactionStatusFilter.all:
        break;
      case TransactionStatusFilter.settled:
        if (!effStatus.isSettled) return false;
        break;
      case TransactionStatusFilter.pending:
        if (effStatus != TransactionStatus.pending) return false;
        break;
      case TransactionStatusFilter.overdue:
        if (effStatus != TransactionStatus.overdue) return false;
        break;
    }

    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      final descMatch = tx.description.toLowerCase().contains(query);
      final notesMatch = (tx.notes ?? '').toLowerCase().contains(query);
      if (!descMatch && !notesMatch) return false;
    }

    return true;
  }

  TransactionFilter copyWith({
    DatePeriod? period,
    String? searchQuery,
    TransactionKind? kind,
    bool clearKind = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? accountId,
    bool clearAccountId = false,
    TransactionStatusFilter? statusFilter,
  }) {
    return TransactionFilter(
      period: period ?? this.period,
      searchQuery: searchQuery ?? this.searchQuery,
      kind: clearKind ? null : (kind ?? this.kind),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  @override
  List<Object?> get props => [
        period,
        searchQuery,
        kind,
        categoryId,
        accountId,
        statusFilter,
      ];
}
