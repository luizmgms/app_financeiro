import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../domain/entities/category_entity.dart';
import '../providers/category_providers.dart';

class CategoryActionState extends Equatable {
  const CategoryActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  @override
  List<Object?> get props => [isLoading, errorMessage, successMessage];
}

/// Controller responsável pela criação, edição, arquivamento e exclusão de categorias.
class CategoryController extends Notifier<CategoryActionState> {
  @override
  CategoryActionState build() => const CategoryActionState();

  void clearMessages() {
    state = CategoryActionState(isLoading: state.isLoading);
  }

  Future<bool> saveCategory({
    CategoryEntity? existing,
    required String name,
    required String description,
    required CategoryType type,
    required String iconName,
    required String colorHex,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const CategoryActionState(
        errorMessage: 'Faça login para gerenciar categorias.',
      );
      return false;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = const CategoryActionState(
        errorMessage: 'Informe o nome da categoria.',
      );
      return false;
    }
    if (trimmedName.length > 60) {
      state = const CategoryActionState(
        errorMessage: 'O nome da categoria deve ter no máximo 60 caracteres.',
      );
      return false;
    }

    state = const CategoryActionState(isLoading: true);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final now = DateTime.now();

      if (existing == null) {
        final created = CategoryEntity(
          id: '',
          name: trimmedName,
          description: description.trim(),
          type: type,
          iconName: iconName,
          colorHex: colorHex,
          isDefault: false,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createCategory(userId: user.uid, category: created);
        state = const CategoryActionState(
          successMessage: 'Categoria criada com sucesso.',
        );
      } else {
        final updated = existing.copyWith(
          name: trimmedName,
          description: description.trim(),
          type: type,
          iconName: iconName,
          colorHex: colorHex,
          updatedAt: now,
        );
        await repo.updateCategory(userId: user.uid, category: updated);
        state = const CategoryActionState(
          successMessage: 'Categoria atualizada com sucesso.',
        );
      }
      return true;
    } on Failure catch (failure) {
      state = CategoryActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CategoryActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível salvar a categoria.',
        ),
      );
      return false;
    }
  }

  Future<bool> setArchived({
    required String categoryId,
    required bool archived,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const CategoryActionState(isLoading: true);
    try {
      await ref.read(categoryRepositoryProvider).setArchived(
            userId: user.uid,
            categoryId: categoryId,
            archived: archived,
          );
      state = CategoryActionState(
        successMessage: archived
            ? 'Categoria arquivada com sucesso.'
            : 'Categoria reativada com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = CategoryActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CategoryActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível atualizar o status da categoria.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const CategoryActionState(isLoading: true);
    try {
      await ref.read(categoryRepositoryProvider).deleteCategory(
            userId: user.uid,
            categoryId: categoryId,
          );
      state = const CategoryActionState(
        successMessage: 'Categoria excluída com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = CategoryActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CategoryActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível excluir a categoria.',
        ),
      );
      return false;
    }
  }
}

final categoryControllerProvider =
    NotifierProvider<CategoryController, CategoryActionState>(
  CategoryController.new,
);
