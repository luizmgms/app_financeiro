import 'package:equatable/equatable.dart';
import 'transaction_attachment.dart';

/// Tipo de movimentação financeira.
enum TransactionKind {
  income('income', 'Receita'),
  expense('expense', 'Despesa'),
  transfer('transfer', 'Transferência'),
  cardPurchase('card_purchase', 'Compra no cartão'),
  invoicePayment('invoice_payment', 'Pagamento de fatura');

  const TransactionKind(this.storageValue, this.label);

  final String storageValue;
  final String label;

  /// Transferências e pagamentos de fatura nunca entram como receita ou despesa
  /// nos relatórios, evitando dupla contagem.
  bool get countsAsIncomeOrExpense =>
      this == income || this == expense || this == cardPurchase;

  static TransactionKind fromStorage(String? value) {
    return switch (value) {
      'income' => TransactionKind.income,
      'transfer' => TransactionKind.transfer,
      'card_purchase' => TransactionKind.cardPurchase,
      'invoice_payment' => TransactionKind.invoicePayment,
      _ => TransactionKind.expense,
    };
  }
}

/// Status operacional do lançamento.
enum TransactionStatus {
  paid('paid', 'Paga'),
  received('received', 'Recebida'),
  pending('pending', 'Pendente'),
  overdue('overdue', 'Atrasada'),
  completed('completed', 'Concluída');

  const TransactionStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  /// Indica se o lançamento já foi efetivamente liquidado em conta.
  bool get isSettled =>
      this == paid || this == received || this == completed;

  static TransactionStatus fromStorage(String? value) {
    return switch (value) {
      'paid' => TransactionStatus.paid,
      'received' => TransactionStatus.received,
      'overdue' => TransactionStatus.overdue,
      'completed' => TransactionStatus.completed,
      _ => TransactionStatus.pending,
    };
  }
}

/// Direção da perna de uma transferência vinculada entre duas contas.
enum TransferDirection {
  outflow('out'),
  inflow('in');

  const TransferDirection(this.storageValue);

  final String storageValue;

  static TransferDirection? fromStorage(String? value) {
    return switch (value) {
      'out' => TransferDirection.outflow,
      'in' => TransferDirection.inflow,
      _ => null,
    };
  }
}

/// Entidade de movimentação financeira com separação temporal e precisão em centavos.
class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    required this.kind,
    required this.description,
    required this.amountCents,
    this.categoryId,
    this.accountId,
    this.destinationAccountId,
    this.transferGroupId,
    this.transferDirection,
    required this.competencyDate,
    this.dueDate,
    this.paymentDate,
    required this.status,
    this.notes,
    this.attachments = const <TransactionAttachment>[],
    this.cardId,
    this.invoiceId,
    this.installmentPlanId,
    this.installmentNumber,
    this.totalInstallments,
    this.recurringId,
    this.occurrenceKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final TransactionKind kind;
  final String description;
  final int amountCents;
  final String? categoryId;
  final String? accountId;
  final String? destinationAccountId;
  final String? transferGroupId;
  final TransferDirection? transferDirection;
  final DateTime competencyDate;
  final DateTime? dueDate;
  final DateTime? paymentDate;
  final TransactionStatus status;
  final String? notes;
  final List<TransactionAttachment> attachments;
  final String? cardId;
  final String? invoiceId;
  final String? installmentPlanId;
  final int? installmentNumber;
  final int? totalInstallments;
  final String? recurringId;
  final String? occurrenceKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get affectsAccountBalance {
    if (!status.isSettled) return false;
    return switch (kind) {
      TransactionKind.income ||
      TransactionKind.expense ||
      TransactionKind.transfer ||
      TransactionKind.invoicePayment =>
        true,
      TransactionKind.cardPurchase => false,
    };
  }

  /// Calcula o status efetivo considerando o vencimento de despesas pendentes.
  TransactionStatus effectiveStatus([DateTime? reference]) {
    if (kind == TransactionKind.expense &&
        status == TransactionStatus.pending &&
        dueDate != null) {
      final now = reference ?? DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
      if (dueDay.isBefore(todayStart)) {
        return TransactionStatus.overdue;
      }
    }
    return status;
  }

  /// Impacto em centavos desta movimentação no saldo da conta [targetAccountId].
  int signedBalanceDeltaForAccount(String targetAccountId) {
    if (accountId != targetAccountId || !affectsAccountBalance) {
      return 0;
    }

    return switch (kind) {
      TransactionKind.income => amountCents,
      TransactionKind.expense || TransactionKind.invoicePayment => -amountCents,
      TransactionKind.transfer =>
        transferDirection == TransferDirection.inflow
            ? amountCents
            : -amountCents,
      TransactionKind.cardPurchase => 0,
    };
  }

  TransactionEntity copyWith({
    String? id,
    TransactionKind? kind,
    String? description,
    int? amountCents,
    String? categoryId,
    bool clearCategoryId = false,
    String? accountId,
    bool clearAccountId = false,
    String? destinationAccountId,
    bool clearDestinationAccountId = false,
    String? transferGroupId,
    TransferDirection? transferDirection,
    DateTime? competencyDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? paymentDate,
    bool clearPaymentDate = false,
    TransactionStatus? status,
    String? notes,
    bool clearNotes = false,
    List<TransactionAttachment>? attachments,
    String? cardId,
    String? invoiceId,
    String? installmentPlanId,
    int? installmentNumber,
    int? totalInstallments,
    String? recurringId,
    String? occurrenceKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      destinationAccountId: clearDestinationAccountId
          ? null
          : (destinationAccountId ?? this.destinationAccountId),
      transferGroupId: transferGroupId ?? this.transferGroupId,
      transferDirection: transferDirection ?? this.transferDirection,
      competencyDate: competencyDate ?? this.competencyDate,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      paymentDate: clearPaymentDate ? null : (paymentDate ?? this.paymentDate),
      status: status ?? this.status,
      notes: clearNotes ? null : (notes ?? this.notes),
      attachments: attachments ?? this.attachments,
      cardId: cardId ?? this.cardId,
      invoiceId: invoiceId ?? this.invoiceId,
      installmentPlanId: installmentPlanId ?? this.installmentPlanId,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      recurringId: recurringId ?? this.recurringId,
      occurrenceKey: occurrenceKey ?? this.occurrenceKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        kind,
        description,
        amountCents,
        categoryId,
        accountId,
        destinationAccountId,
        transferGroupId,
        transferDirection,
        competencyDate,
        dueDate,
        paymentDate,
        status,
        notes,
        attachments,
        cardId,
        invoiceId,
        installmentPlanId,
        installmentNumber,
        totalInstallments,
        recurringId,
        occurrenceKey,
        createdAt,
        updatedAt,
      ];
}
