import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Status operacional de uma fatura de cartão de crédito.
enum InvoiceStatus {
  open('open', 'Aberta'),
  closed('closed', 'Fechada'),
  paid('paid', 'Paga'),
  overdue('overdue', 'Vencida');

  const InvoiceStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  bool get isPaid => this == paid;

  static InvoiceStatus fromStorage(String? value) {
    return switch (value) {
      'closed' => InvoiceStatus.closed,
      'paid' => InvoiceStatus.paid,
      'overdue' => InvoiceStatus.overdue,
      _ => InvoiceStatus.open,
    };
  }
}

/// Fatura mensal de um cartão de crédito (`users/{userId}/invoices/{invoiceId}`).
class InvoiceEntity extends Equatable {
  const InvoiceEntity({
    required this.id,
    required this.cardId,
    required this.referenceYear,
    required this.referenceMonth,
    required this.closingDate,
    required this.dueDate,
    required this.totalAmountCents,
    required this.paidAmountCents,
    required this.status,
    this.paymentTransactionId,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String cardId;
  final int referenceYear;
  final int referenceMonth;
  final DateTime closingDate;
  final DateTime dueDate;
  final int totalAmountCents;
  final int paidAmountCents;
  final InvoiceStatus status;
  final String? paymentTransactionId;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Valor ainda em aberto nesta fatura em centavos.
  int get remainingAmountCents =>
      math.max(0, totalAmountCents - paidAmountCents);

  /// Rótulo `MM/YYYY` da competência da fatura.
  String get referenceLabel =>
      '${referenceMonth.toString().padLeft(2, '0')}/$referenceYear';

  /// Calcula o status efetivo da fatura considerando a data atual [reference].
  InvoiceStatus effectiveStatus([DateTime? reference]) {
    if (status == InvoiceStatus.paid ||
        (totalAmountCents > 0 && paidAmountCents >= totalAmountCents)) {
      return InvoiceStatus.paid;
    }

    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDayDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final closingDayDate =
        DateTime(closingDate.year, closingDate.month, closingDate.day);

    if (remainingAmountCents > 0 && dueDayDate.isBefore(today)) {
      return InvoiceStatus.overdue;
    }

    if (!today.isBefore(closingDayDate)) {
      return InvoiceStatus.closed;
    }

    return InvoiceStatus.open;
  }

  InvoiceEntity copyWith({
    String? id,
    String? cardId,
    int? referenceYear,
    int? referenceMonth,
    DateTime? closingDate,
    DateTime? dueDate,
    int? totalAmountCents,
    int? paidAmountCents,
    InvoiceStatus? status,
    String? paymentTransactionId,
    bool clearPaymentTransactionId = false,
    DateTime? paidAt,
    bool clearPaidAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceEntity(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      referenceYear: referenceYear ?? this.referenceYear,
      referenceMonth: referenceMonth ?? this.referenceMonth,
      closingDate: closingDate ?? this.closingDate,
      dueDate: dueDate ?? this.dueDate,
      totalAmountCents: totalAmountCents ?? this.totalAmountCents,
      paidAmountCents: paidAmountCents ?? this.paidAmountCents,
      status: status ?? this.status,
      paymentTransactionId: clearPaymentTransactionId
          ? null
          : (paymentTransactionId ?? this.paymentTransactionId),
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        cardId,
        referenceYear,
        referenceMonth,
        closingDate,
        dueDate,
        totalAmountCents,
        paidAmountCents,
        status,
        paymentTransactionId,
        paidAt,
        createdAt,
        updatedAt,
      ];
}
