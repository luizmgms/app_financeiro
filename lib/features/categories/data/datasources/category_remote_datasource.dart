import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/constants/default_categories.dart';
import '../../domain/entities/category_entity.dart';
import '../models/category_model.dart';

/// Fonte de dados Firestore para categorias financeiras isoladas por usuário.
class CategoryRemoteDatasource {
  CategoryRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _categoriesCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.categories);
  }

  Stream<List<CategoryEntity>> watchCategories(String userId) {
    return _categoriesCollection(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map(CategoryModel.fromFirestore)
          .toList(growable: false);
      final sorted = List<CategoryEntity>.of(list)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    });
  }

  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {
    final userRef = _userDoc(userId);
    final userSnapshot = await userRef.get();
    final alreadySeeded =
        (userSnapshot.data()?['defaultCategoriesSeeded'] as bool?) ?? false;
    if (alreadySeeded) return;

    final existing = await _categoriesCollection(userId).limit(1).get();
    if (existing.docs.isNotEmpty) {
      await userRef.set(
        <String, dynamic>{'defaultCategoriesSeeded': true},
        SetOptions(merge: true),
      );
      return;
    }

    final defaults = DefaultCategories.build(DateTime.now());
    final batch = _db.batch();
    for (final category in defaults) {
      final docRef = _categoriesCollection(userId).doc(category.id);
      batch.set(docRef, CategoryModel.toFirestore(category));
    }
    batch.set(
      userRef,
      <String, dynamic>{
        'uid': userId,
        'defaultCategoriesSeeded': true,
        'updatedAt': FirestoreUtils.toMillisTimestamp(DateTime.now()),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<CategoryEntity> createCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    final docRef = category.id.trim().isEmpty
        ? _categoriesCollection(userId).doc()
        : _categoriesCollection(userId).doc(category.id);
    final now = DateTime.now();
    final toSave = category.copyWith(
      id: docRef.id,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(CategoryModel.toFirestore(toSave));
    return toSave;
  }

  Future<void> updateCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    final updated = category.copyWith(updatedAt: DateTime.now());
    await _categoriesCollection(userId).doc(category.id).update(
          FirestoreUtils.withoutCreatedAt(CategoryModel.toFirestore(updated)),
        );
  }

  Future<void> setArchived({
    required String userId,
    required String categoryId,
    required bool archived,
  }) async {
    await _categoriesCollection(userId).doc(categoryId).update(<String, dynamic>{
      'isActive': !archived,
      'updatedAt': FirestoreUtils.toMillisTimestamp(DateTime.now()),
    });
  }

  Future<void> deleteCategory({
    required String userId,
    required String categoryId,
  }) async {
    final linkedTransactions = await _userDoc(userId)
        .collection(FirestoreCollections.transactions)
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();

    if (linkedTransactions.docs.isNotEmpty) {
      throw const ValidationFailure(
        'Esta categoria possui movimentações vinculadas. Arquive-a em vez de excluir.',
      );
    }

    await _categoriesCollection(userId).doc(categoryId).delete();
  }
}
