import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/budget_entity.dart';
import '../models/budget_model.dart';

/// Datasource Cloud Firestore para orçamentos mensais por categoria.
class BudgetRemoteDatasource {
  BudgetRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _budgetsCollection(String userId) {
    return _db
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.budgets);
  }

  Stream<List<BudgetEntity>> watchBudgets(String userId) {
    if (_firestore == null && Firebase.apps.isEmpty) {
      return Stream.value(const <BudgetEntity>[]);
    }
    return _budgetsCollection(userId).snapshots().map((snapshot) {
      final list =
          snapshot.docs.map(BudgetModel.fromFirestore).toList(growable: false);
      final sorted = List<BudgetEntity>.of(list)
        ..sort((a, b) {
          final y = b.year.compareTo(a.year);
          if (y != 0) return y;
          final m = b.month.compareTo(a.month);
          if (m != 0) return m;
          return a.categoryId.compareTo(b.categoryId);
        });
      return sorted;
    });
  }

  Future<BudgetEntity> upsertBudget({
    required String userId,
    required BudgetEntity budget,
  }) async {
    final docId = BudgetEntity.deterministicId(
      categoryId: budget.categoryId,
      year: budget.year,
      month: budget.month,
    );
    final docRef = _budgetsCollection(userId).doc(docId);
    final now = DateTime.now();

    return _db.runTransaction<BudgetEntity>((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) {
        final existing = BudgetModel.fromFirestore(snap);
        final updated = budget.copyWith(
          id: docId,
          createdAt: existing.createdAt,
          updatedAt: now,
        );
        tx.update(
          docRef,
          FirestoreUtils.withoutCreatedAt(BudgetModel.toFirestore(updated)),
        );
        return updated;
      }

      final created = budget.copyWith(
        id: docId,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(docRef, BudgetModel.toFirestore(created));
      return created;
    });
  }

  Future<int> copyFromPreviousMonth({
    required String userId,
    required int sourceYear,
    required int sourceMonth,
    required int targetYear,
    required int targetMonth,
  }) async {
    final sourceSnap = await _budgetsCollection(userId)
        .where('year', isEqualTo: sourceYear)
        .get();
    if (sourceSnap.docs.isEmpty) return 0;

    final sourceBudgets = sourceSnap.docs
        .map(BudgetModel.fromFirestore)
        .where((b) => b.month == sourceMonth)
        .toList(growable: false);
    if (sourceBudgets.isEmpty) return 0;
    final now = DateTime.now();

    return _db.runTransaction<int>((tx) async {
      final toCreate = <(DocumentReference<Map<String, dynamic>>, BudgetEntity)>[];
      for (final src in sourceBudgets) {
        final targetId = BudgetEntity.deterministicId(
          categoryId: src.categoryId,
          year: targetYear,
          month: targetMonth,
        );
        final ref = _budgetsCollection(userId).doc(targetId);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          toCreate.add((
            ref,
            BudgetEntity(
              id: targetId,
              categoryId: src.categoryId,
              year: targetYear,
              month: targetMonth,
              limitCents: src.limitCents,
              alertThresholdPercent: src.alertThresholdPercent,
              notes: src.notes,
              createdAt: now,
              updatedAt: now,
            ),
          ));
        }
      }

      for (final item in toCreate) {
        tx.set(item.$1, BudgetModel.toFirestore(item.$2));
      }
      return toCreate.length;
    });
  }

  Future<void> deleteBudget({
    required String userId,
    required String budgetId,
  }) async {
    await _budgetsCollection(userId).doc(budgetId).delete();
  }
}
