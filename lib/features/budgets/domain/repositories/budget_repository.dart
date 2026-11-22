import '../entities/budget_entity.dart';

/// Contrato de persistência para orçamentos mensais por categoria.
abstract interface class BudgetRepository {
  Stream<List<BudgetEntity>> watchBudgets(String userId);

  /// Cria ou atualiza de forma determinística o orçamento da categoria no mês.
  Future<BudgetEntity> upsertBudget({
    required String userId,
    required BudgetEntity budget,
  });

  /// Copia metas de um mês de origem para o mês destino sem sobrescrever metas já cadastradas.
  Future<int> copyFromPreviousMonth({
    required String userId,
    required int sourceYear,
    required int sourceMonth,
    required int targetYear,
    required int targetMonth,
  });

  Future<void> deleteBudget({
    required String userId,
    required String budgetId,
  });
}
