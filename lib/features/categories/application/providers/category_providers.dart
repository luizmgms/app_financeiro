import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../data/datasources/category_remote_datasource.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';

final categoryRemoteDatasourceProvider =
    Provider<CategoryRemoteDatasource>((ref) {
  return CategoryRemoteDatasource();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(categoryRemoteDatasourceProvider);
  return CategoryRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
  );
});

/// Observa em tempo real as categorias do usuário autenticado, realizando o
/// seed idempotente das categorias padrão no primeiro acesso.
final categoriesStreamProvider = StreamProvider<List<CategoryEntity>>((ref) async* {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    yield const <CategoryEntity>[];
    return;
  }

  final repository = ref.watch(categoryRepositoryProvider);
  await repository.seedDefaultCategoriesIfNeeded(authUser.uid);
  yield* repository.watchCategories(authUser.uid);
});

final activeCategoriesProvider = Provider<List<CategoryEntity>>((ref) {
  final all = ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
  return all.where((category) => category.isActive).toList(growable: false);
});

final categoriesByIdProvider = Provider<Map<String, CategoryEntity>>((ref) {
  final all = ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
  return <String, CategoryEntity>{
    for (final category in all) category.id: category,
  };
});
