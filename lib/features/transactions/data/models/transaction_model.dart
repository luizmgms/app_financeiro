import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/transaction_attachment.dart';
import '../../domain/entities/transaction_entity.dart';

/// Modelo de serialização Firestore para [TransactionEntity].
class TransactionModel {
  const TransactionModel._();

  static TransactionEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    final rawAttachments = data['attachments'] as List<dynamic>?;
    final attachments = rawAttachments == null
        ? const <TransactionAttachment>[]
        : rawAttachments
            .whereType<Map<String, dynamic>>()
            .map(TransactionAttachment.fromMap)
            .toList(growable: false);

    return TransactionEntity(
      id: snapshot.id,
      kind: TransactionKind.fromStorage(data['kind'] as String?),
      description: (data['description'] as String?) ?? '',
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      categoryId: data['categoryId'] as String?,
      accountId: data['accountId'] as String?,
      destinationAccountId: data['destinationAccountId'] as String?,
      transferGroupId: data['transferGroupId'] as String?,
      transferDirection:
          TransferDirection.fromStorage(data['transferDirection'] as String?),
      competencyDate: _parseDate(data['competencyDate']) ?? now,
      dueDate: _parseDate(data['dueDate']),
      paymentDate: _parseDate(data['paymentDate']),
      status: TransactionStatus.fromStorage(data['status'] as String?),
      notes: data['notes'] as String?,
      attachments: attachments,
      cardId: data['cardId'] as String?,
      invoiceId: data['invoiceId'] as String?,
      installmentPlanId: data['installmentPlanId'] as String?,
      installmentNumber: (data['installmentNumber'] as num?)?.toInt(),
      totalInstallments: (data['totalInstallments'] as num?)?.toInt(),
      recurringId: data['recurringId'] as String?,
      occurrenceKey: data['occurrenceKey'] as String?,
      createdAt: _parseDate(data['createdAt']) ?? now,
      updatedAt: _parseDate(data['updatedAt']) ?? now,
    );
  }

  static Map<String, dynamic> toFirestore(TransactionEntity transaction) {
    return <String, dynamic>{
      'kind': transaction.kind.storageValue,
      'description': transaction.description.trim(),
      'amountCents': transaction.amountCents,
      'categoryId': transaction.categoryId,
      'accountId': transaction.accountId,
      'destinationAccountId': transaction.destinationAccountId,
      'transferGroupId': transaction.transferGroupId,
      'transferDirection': transaction.transferDirection?.storageValue,
      'competencyDate': FirestoreUtils.toMillisTimestamp(transaction.competencyDate),
      'dueDate': FirestoreUtils.toNullableMillisTimestamp(transaction.dueDate),
      'paymentDate':
          FirestoreUtils.toNullableMillisTimestamp(transaction.paymentDate),
      'status': transaction.status.storageValue,
      'notes': transaction.notes?.trim().isEmpty == true
          ? null
          : transaction.notes?.trim(),
      'attachments':
          transaction.attachments.map((item) => item.toMap()).toList(),
      'attachmentUrls':
          transaction.attachments.map((item) => item.url).toList(),
      'cardId': transaction.cardId,
      'invoiceId': transaction.invoiceId,
      'installmentPlanId': transaction.installmentPlanId,
      'installmentNumber': transaction.installmentNumber,
      'totalInstallments': transaction.totalInstallments,
      'recurringId': transaction.recurringId,
      'occurrenceKey': transaction.occurrenceKey,
      'createdAt': FirestoreUtils.toMillisTimestamp(transaction.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(transaction.updatedAt),
    };
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
