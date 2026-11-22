import 'package:firebase_core/firebase_core.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_remote_datasource.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required BudgetRemoteDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final BudgetRemoteDatasource _datasource;

  void _ensureReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure();
    }
  }

  @override
  Stream<List<BudgetEntity>> watchBudgets(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <BudgetEntity>[]);
    }
    return _datasource.watchBudgets(userId);
  }

  @override
  Future<BudgetEntity> upsertBudget({
    required String userId,
    required BudgetEntity budget,
  }) async {
    _ensureReady();
    try {
      return await _datasource.upsertBudget(userId: userId, budget: budget);
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível salvar o orçamento.',
      );
    }
  }

  @override
  Future<int> copyFromPreviousMonth({
    required String userId,
    required int sourceYear,
    required int sourceMonth,
    required int targetYear,
    required int targetMonth,
  }) async {
    _ensureReady();
    try {
      return await _datasource.copyFromPreviousMonth(
        userId: userId,
        sourceYear: sourceYear,
        sourceMonth: sourceMonth,
        targetYear: targetYear,
        targetMonth: targetMonth,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível copiar os orçamentos anteriores.',
      );
    }
  }

  @override
  Future<void> deleteBudget({
    required String userId,
    required String budgetId,
  }) async {
    _ensureReady();
    try {
      await _datasource.deleteBudget(userId: userId, budgetId: budgetId);
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível excluir o orçamento.',
      );
    }
  }
}
