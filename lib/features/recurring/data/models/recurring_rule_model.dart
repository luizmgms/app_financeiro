import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/recurring_rule_entity.dart';

/// Serializador Cloud Firestore para [RecurringRuleEntity].
class RecurringRuleModel {
  const RecurringRuleModel._();

  static RecurringRuleEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    final rawSkipped = data['skippedOccurrenceKeys'] as List<dynamic>?;
    final skipped = rawSkipped == null
        ? const <String>[]
        : rawSkipped.whereType<String>().toList(growable: false);

    return RecurringRuleEntity(
      id: snapshot.id,
      description: (data['description'] as String?) ?? '',
      kind: RecurringKind.fromStorage(data['kind'] as String?),
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      isVariableAmount: (data['isVariableAmount'] as bool?) ?? false,
      categoryId: (data['categoryId'] as String?) ?? '',
      accountId: data['accountId'] as String?,
      cardId: data['cardId'] as String?,
      frequency: RecurringFrequency.fromStorage(data['frequency'] as String?),
      customIntervalDays: (data['customIntervalDays'] as num?)?.toInt(),
      startDate: _parseDate(data['startDate']) ?? now,
      endDate: _parseDate(data['endDate']),
      status: RecurringStatus.fromStorage(data['status'] as String?),
      lastGeneratedKey: data['lastGeneratedKey'] as String?,
      skippedOccurrenceKeys: skipped,
      notes: data['notes'] as String?,
      createdAt: _parseDate(data['createdAt']) ?? now,
      updatedAt: _parseDate(data['updatedAt']) ?? now,
    );
  }

  static Map<String, dynamic> toFirestore(RecurringRuleEntity rule) {
    return <String, dynamic>{
      'description': rule.description.trim(),
      'kind': rule.kind.storageValue,
      'amountCents': rule.amountCents,
      'isVariableAmount': rule.isVariableAmount,
      'categoryId': rule.categoryId,
      'accountId': rule.accountId,
      'cardId': rule.cardId,
      'frequency': rule.frequency.storageValue,
      'customIntervalDays': rule.customIntervalDays,
      'startDate': FirestoreUtils.toMillisTimestamp(rule.startDate),
      'endDate': FirestoreUtils.toNullableMillisTimestamp(rule.endDate),
      'status': rule.status.storageValue,
      'lastGeneratedKey': rule.lastGeneratedKey,
      'skippedOccurrenceKeys': rule.skippedOccurrenceKeys,
      'notes': rule.notes?.trim().isEmpty == true ? null : rule.notes?.trim(),
      'createdAt': FirestoreUtils.toMillisTimestamp(rule.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(rule.updatedAt),
    };
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
