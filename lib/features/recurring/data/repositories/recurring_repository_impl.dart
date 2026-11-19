import 'package:firebase_core/firebase_core.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../../domain/repositories/recurring_repository.dart';
import '../datasources/recurring_remote_datasource.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  RecurringRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required RecurringRemoteDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final RecurringRemoteDatasource _datasource;

  void _ensureReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure();
    }
  }

  @override
  Stream<List<RecurringRuleEntity>> watchRules(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <RecurringRuleEntity>[]);
    }
    return _datasource.watchRules(userId);
  }

  @override
  Future<RecurringRuleEntity> createRule({
    required String userId,
    required RecurringRuleEntity rule,
    DateTime? referenceDate,
  }) async {
    _ensureReady();
    try {
      return await _datasource.createRule(
        userId: userId,
        rule: rule,
        referenceDate: referenceDate,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível criar a conta recorrente.',
      );
    }
  }

  @override
  Future<void> updateRule({
    required String userId,
    required RecurringRuleEntity rule,
  }) async {
    _ensureReady();
    try {
      await _datasource.updateRule(userId: userId, rule: rule);
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível atualizar a conta recorrente.',
      );
    }
  }

  @override
  Future<void> setStatus({
    required String userId,
    required String ruleId,
    required RecurringStatus status,
  }) async {
    _ensureReady();
    try {
      await _datasource.setStatus(
        userId: userId,
        ruleId: ruleId,
        status: status,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível alterar o status da recorrência.',
      );
    }
  }

  @override
  Future<void> deleteRule({
    required String userId,
    required String ruleId,
  }) async {
    _ensureReady();
    try {
      await _datasource.deleteRule(userId: userId, ruleId: ruleId);
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível excluir a conta recorrente.',
      );
    }
  }

  @override
  Future<int> syncOccurrences({
    required String userId,
    DateTime? referenceDate,
  }) async {
    _ensureReady();
    try {
      return await _datasource.syncOccurrences(
        userId: userId,
        referenceDate: referenceDate,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível sincronizar recorrências.',
      );
    }
  }

  @override
  Future<void> updateSingleCardOccurrence({
    required String userId,
    required String transactionId,
    required String description,
    required int amountCents,
    String? notes,
  }) async {
    _ensureReady();
    try {
      await _datasource.updateSingleCardOccurrence(
        userId: userId,
        transactionId: transactionId,
        description: description,
        amountCents: amountCents,
        notes: notes,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível atualizar a ocorrência no cartão.',
      );
    }
  }
}
