import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/budget_entity.dart';

/// Serializador Cloud Firestore para [BudgetEntity].
class BudgetModel {
  const BudgetModel._();

  static BudgetEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return BudgetEntity(
      id: snapshot.id,
      categoryId: (data['categoryId'] as String?) ?? '',
      year: (data['year'] as num?)?.toInt() ?? now.year,
      month: (data['month'] as num?)?.toInt() ?? now.month,
      limitCents: (data['limitCents'] as num?)?.toInt() ?? 0,
      alertThresholdPercent:
          ((data['alertThresholdPercent'] as num?)?.toInt() ?? 80)
              .clamp(1, 100),
      notes: data['notes'] as String?,
      createdAt: _parseDate(data['createdAt']) ?? now,
      updatedAt: _parseDate(data['updatedAt']) ?? now,
    );
  }

  static Map<String, dynamic> toFirestore(BudgetEntity budget) {
    return <String, dynamic>{
      'categoryId': budget.categoryId,
      'year': budget.year,
      'month': budget.month,
      'limitCents': budget.limitCents,
      'alertThresholdPercent': budget.alertThresholdPercent.clamp(1, 100),
      'notes':
          budget.notes?.trim().isEmpty == true ? null : budget.notes?.trim(),
      'createdAt': FirestoreUtils.toMillisTimestamp(budget.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(budget.updatedAt),
    };
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
