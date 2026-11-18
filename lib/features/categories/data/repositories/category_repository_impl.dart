import 'package:firebase_core/firebase_core.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_datasource.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required CategoryRemoteDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final CategoryRemoteDatasource _datasource;

  void _ensureReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure();
    }
  }

  @override
  Stream<List<CategoryEntity>> watchCategories(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <CategoryEntity>[]);
    }
    return _datasource.watchCategories(userId);
  }

  @override
  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {
    if (!_bootstrapState.isReady) return;
    try {
      await _datasource.seedDefaultCategoriesIfNeeded(userId);
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<CategoryEntity> createCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    _ensureReady();
    try {
      return await _datasource.createCategory(
        userId: userId,
        category: category,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> updateCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    _ensureReady();
    try {
      await _datasource.updateCategory(userId: userId, category: category);
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> setArchived({
    required String userId,
    required String categoryId,
    required bool archived,
  }) async {
    _ensureReady();
    try {
      await _datasource.setArchived(
        userId: userId,
        categoryId: categoryId,
        archived: archived,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> deleteCategory({
    required String userId,
    required String categoryId,
  }) async {
    _ensureReady();
    try {
      await _datasource.deleteCategory(
        userId: userId,
        categoryId: categoryId,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  Failure _mapException(FirebaseException error) {
    return mapFirebaseFailure(
      error,
      fallbackMessage: 'Não foi possível processar a categoria.',
    );
  }
}
