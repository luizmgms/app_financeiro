import 'package:firebase_core/firebase_core.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_remote_datasource.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required AccountRemoteDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final AccountRemoteDatasource _datasource;

  void _ensureReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure();
    }
  }

  @override
  Stream<List<AccountEntity>> watchAccounts(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <AccountEntity>[]);
    }
    return _datasource.watchAccounts(userId);
  }

  @override
  Future<AccountEntity> createAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    _ensureReady();
    try {
      return await _datasource.createAccount(userId: userId, account: account);
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> updateAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    _ensureReady();
    try {
      await _datasource.updateAccount(userId: userId, account: account);
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> setArchived({
    required String userId,
    required String accountId,
    required bool archived,
  }) async {
    _ensureReady();
    try {
      await _datasource.setArchived(
        userId: userId,
        accountId: accountId,
        archived: archived,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> deleteAccount({
    required String userId,
    required String accountId,
  }) async {
    _ensureReady();
    try {
      await _datasource.deleteAccount(userId: userId, accountId: accountId);
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> transferBetweenAccounts({
    required String userId,
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountCents,
    required DateTime transferDate,
    required String description,
    String? notes,
  }) async {
    _ensureReady();
    try {
      await _datasource.transferBetweenAccounts(
        userId: userId,
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        amountCents: amountCents,
        transferDate: transferDate,
        description: description,
        notes: notes,
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
      fallbackMessage: 'Não foi possível processar a conta financeira.',
    );
  }
}
