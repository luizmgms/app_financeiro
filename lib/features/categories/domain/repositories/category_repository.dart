import '../entities/category_entity.dart';

/// Contrato de persistência de categorias financeiras por usuário.
abstract class CategoryRepository {
  Stream<List<CategoryEntity>> watchCategories(String userId);

  Future<void> seedDefaultCategoriesIfNeeded(String userId);

  Future<CategoryEntity> createCategory({
    required String userId,
    required CategoryEntity category,
  });

  Future<void> updateCategory({
    required String userId,
    required CategoryEntity category,
  });

  Future<void> setArchived({
    required String userId,
    required String categoryId,
    required bool archived,
  });

  Future<void> deleteCategory({
    required String userId,
    required String categoryId,
  });
}
