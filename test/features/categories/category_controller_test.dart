import 'package:finance_control/features/categories/application/controllers/category_controller.dart';
import 'package:finance_control/features/categories/application/providers/category_providers.dart';
import 'package:finance_control/features/categories/domain/constants/default_categories.dart';
import 'package:finance_control/features/categories/domain/entities/category_entity.dart';
import 'package:finance_control/features/categories/domain/repositories/category_repository.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo(this._user);
  final AuthUser? _user;
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);
  @override
  AuthUser? get currentUser => _user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCategoryRepository implements CategoryRepository {
  final Map<String, CategoryEntity> store = <String, CategoryEntity>{};

  @override
  Stream<List<CategoryEntity>> watchCategories(String userId) {
    return Stream.value(store.values.toList(growable: false));
  }

  @override
  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {
    if (store.isNotEmpty) return;
    for (final cat in DefaultCategories.build(DateTime(2026, 11, 17))) {
      store[cat.id] = cat;
    }
  }

  @override
  Future<CategoryEntity> createCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    final created = category.copyWith(id: 'cat_${store.length + 1}');
    store[created.id] = created;
    return created;
  }

  @override
  Future<void> updateCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    store[category.id] = category;
  }

  @override
  Future<void> setArchived({
    required String userId,
    required String categoryId,
    required bool archived,
  }) async {
    final current = store[categoryId];
    if (current != null) {
      store[categoryId] = current.copyWith(isActive: !archived);
    }
  }

  @override
  Future<void> deleteCategory({
    required String userId,
    required String categoryId,
  }) async {
    store.remove(categoryId);
  }
}

void main() {
  test('DefaultCategories provides separated income and expense catalogs', () {
    final list = DefaultCategories.build(DateTime(2026, 11, 17));
    final ids = list.map((c) => c.id).toSet();

    expect(ids.length, list.length);
    expect(
      list.where((c) => c.type == CategoryType.income).length,
      greaterThanOrEqualTo(6),
    );
    expect(
      list.where((c) => c.type == CategoryType.expense).length,
      greaterThanOrEqualTo(10),
    );
  });

  test('CategoryController creates, updates, archives and validates names',
      () async {
    final fakeRepo = _FakeCategoryRepository();
    const user = AuthUser(
      uid: 'u1',
      email: 'luiz@app.com',
      displayName: 'Luiz',
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo(user)),
        currentAuthUserProvider.overrideWithValue(user),
        categoryRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(categoryControllerProvider.notifier);

    final invalidOk = await controller.saveCategory(
      name: '   ',
      description: '',
      type: CategoryType.expense,
      iconName: 'restaurant',
      colorHex: '#F97316',
    );
    expect(invalidOk, isFalse);
    expect(
      container.read(categoryControllerProvider).errorMessage,
      'Informe o nome da categoria.',
    );

    final createdOk = await controller.saveCategory(
      name: 'Mercado',
      description: 'Compras semanais',
      type: CategoryType.expense,
      iconName: 'restaurant',
      colorHex: '#F97316',
    );
    expect(createdOk, isTrue);
    expect(fakeRepo.store.values.single.name, 'Mercado');

    final saved = fakeRepo.store.values.single;
    await controller.setArchived(categoryId: saved.id, archived: true);
    expect(fakeRepo.store[saved.id]?.isActive, isFalse);

    await controller.deleteCategory(saved.id);
    expect(fakeRepo.store, isEmpty);
  });
}
