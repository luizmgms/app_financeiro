import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/invoice_entity.dart';

/// Modelo de serialização Firestore para [InvoiceEntity].
class InvoiceModel {
  const InvoiceModel._();

  static InvoiceEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    final closingRaw = data['closingDate'];
    final dueRaw = data['dueDate'];
    final paidAtRaw = data['paidAt'];
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];

    return InvoiceEntity(
      id: snapshot.id,
      cardId: (data['cardId'] as String?) ?? '',
      referenceYear: (data['referenceYear'] as num?)?.toInt() ?? now.year,
      referenceMonth:
          ((data['referenceMonth'] as num?)?.toInt() ?? now.month).clamp(1, 12),
      closingDate: closingRaw is Timestamp ? closingRaw.toDate() : now,
      dueDate: dueRaw is Timestamp ? dueRaw.toDate() : now,
      totalAmountCents: (data['totalAmountCents'] as num?)?.toInt() ?? 0,
      paidAmountCents: (data['paidAmountCents'] as num?)?.toInt() ?? 0,
      status: InvoiceStatus.fromStorage(data['status'] as String?),
      paymentTransactionId: data['paymentTransactionId'] as String?,
      paidAt: paidAtRaw is Timestamp ? paidAtRaw.toDate() : null,
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : now,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : now,
    );
  }

  static Map<String, dynamic> toFirestore(InvoiceEntity invoice) {
    return <String, dynamic>{
      'cardId': invoice.cardId,
      'referenceYear': invoice.referenceYear,
      'referenceMonth': invoice.referenceMonth.clamp(1, 12),
      'closingDate': FirestoreUtils.toMillisTimestamp(invoice.closingDate),
      'dueDate': FirestoreUtils.toMillisTimestamp(invoice.dueDate),
      'totalAmountCents': invoice.totalAmountCents,
      'paidAmountCents': invoice.paidAmountCents,
      'status': invoice.status.storageValue,
      'paymentTransactionId': invoice.paymentTransactionId,
      'paidAt': FirestoreUtils.toNullableMillisTimestamp(invoice.paidAt),
      'createdAt': FirestoreUtils.toMillisTimestamp(invoice.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(invoice.updatedAt),
    };
  }
}
