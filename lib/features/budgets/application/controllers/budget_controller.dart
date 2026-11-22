import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../domain/entities/budget_entity.dart';
import '../providers/budget_providers.dart';

class BudgetActionState extends Equatable {
  const BudgetActionState({
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

class BudgetController extends Notifier<BudgetActionState> {
  @override
  BudgetActionState build() => const BudgetActionState();

  String _requireUserId() {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      throw const AuthFailure('Faça login para gerenciar orçamentos.');
    }
    return user.uid;
  }

  Future<bool> saveBudget({
    required String categoryId,
    required int year,
    required int month,
    required int limitCents,
    int alertThresholdPercent = 80,
    String? notes,
  }) async {
    state = const BudgetActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      if (categoryId.isEmpty) {
        state = const BudgetActionState(
          errorMessage: 'Selecione uma categoria de despesa.',
        );
        return false;
      }
      if (limitCents <= 0) {
        state = const BudgetActionState(
          errorMessage: 'Informe um limite mensal maior que zero.',
        );
        return false;
      }

      final now = DateTime.now();
      final budget = BudgetEntity(
        id: BudgetEntity.deterministicId(
          categoryId: categoryId,
          year: year,
          month: month,
        ),
        categoryId: categoryId,
        year: year,
        month: month,
        limitCents: limitCents,
        alertThresholdPercent: alertThresholdPercent.clamp(1, 100),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(budgetRepositoryProvider).upsertBudget(
            userId: uid,
            budget: budget,
          );
      state = const BudgetActionState(
        successMessage: 'Meta de orçamento salva com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = BudgetActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = BudgetActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível salvar o orçamento.',
        ),
      );
      return false;
    }
  }

  Future<bool> copyFromPreviousMonth({
    required int targetYear,
    required int targetMonth,
  }) async {
    state = const BudgetActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      final prev = DateTime(targetYear, targetMonth - 1, 1);
      final copied =
          await ref.read(budgetRepositoryProvider).copyFromPreviousMonth(
                userId: uid,
                sourceYear: prev.year,
                sourceMonth: prev.month,
                targetYear: targetYear,
                targetMonth: targetMonth,
              );
      state = BudgetActionState(
        successMessage: copied > 0
            ? '$copied meta(s) copiada(s) do mês anterior.'
            : 'Nenhuma meta nova disponível no mês anterior para copiar.',
      );
      return true;
    } on Failure catch (failure) {
      state = BudgetActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = BudgetActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Erro ao copiar metas do mês anterior.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteBudget(String budgetId) async {
    state = const BudgetActionState(isLoading: true);
    try {
      final uid = _requireUserId();
      await ref.read(budgetRepositoryProvider).deleteBudget(
            userId: uid,
            budgetId: budgetId,
          );
      state = const BudgetActionState(
        successMessage: 'Orçamento removido.',
      );
      return true;
    } on Failure catch (failure) {
      state = BudgetActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = BudgetActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível excluir o orçamento.',
        ),
      );
      return false;
    }
  }
}

final budgetControllerProvider =
    NotifierProvider<BudgetController, BudgetActionState>(
  BudgetController.new,
);
