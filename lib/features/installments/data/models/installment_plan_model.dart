import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/installment_plan_entity.dart';

/// Modelo de serialização Firestore para [InstallmentPlanEntity].
class InstallmentPlanModel {
  const InstallmentPlanModel._();

  static InstallmentPlanEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    final firstCompRaw = data['firstCompetencyDate'];
    final firstDueRaw = data['firstDueDate'];
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];

    return InstallmentPlanEntity(
      id: snapshot.id,
      description: (data['description'] as String?) ?? '',
      totalAmountCents: (data['totalAmountCents'] as num?)?.toInt() ?? 0,
      installmentCount:
          ((data['installmentCount'] as num?)?.toInt() ?? 1).clamp(1, 48),
      firstCompetencyDate:
          firstCompRaw is Timestamp ? firstCompRaw.toDate() : now,
      firstDueDate: firstDueRaw is Timestamp ? firstDueRaw.toDate() : now,
      cardId: data['cardId'] as String?,
      accountId: data['accountId'] as String?,
      categoryId: (data['categoryId'] as String?) ?? '',
      notes: data['notes'] as String?,
      status: InstallmentPlanStatus.fromStorage(data['status'] as String?),
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : now,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : now,
    );
  }

  static Map<String, dynamic> toFirestore(InstallmentPlanEntity plan) {
    final trimmedNotes = plan.notes?.trim();
    return <String, dynamic>{
      'description': plan.description.trim(),
      'totalAmountCents': plan.totalAmountCents,
      'installmentCount': plan.installmentCount,
      'firstCompetencyDate':
          FirestoreUtils.toMillisTimestamp(plan.firstCompetencyDate),
      'firstDueDate': FirestoreUtils.toMillisTimestamp(plan.firstDueDate),
      'cardId': plan.cardId,
      'accountId': plan.accountId,
      'categoryId': plan.categoryId,
      'notes': (trimmedNotes == null || trimmedNotes.isEmpty)
          ? null
          : trimmedNotes,
      'status': plan.status.storageValue,
      'createdAt': FirestoreUtils.toMillisTimestamp(plan.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(plan.updatedAt),
    };
  }
}
