import 'package:firebase_core/firebase_core.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/attachment_storage_service.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../domain/entities/transaction_attachment.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required TransactionRemoteDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final TransactionRemoteDatasource _datasource;

  void _ensureReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure();
    }
  }

  @override
  Stream<List<TransactionEntity>> watchTransactions(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <TransactionEntity>[]);
    }
    return _datasource.watchTransactions(userId);
  }

  @override
  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  }) async {
    _ensureReady();
    try {
      return await _datasource.createTransaction(
        userId: userId,
        transaction: transaction,
        newAttachments: newAttachments,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<TransactionEntity> updateTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
    List<TransactionAttachment> removedAttachments =
        const <TransactionAttachment>[],
  }) async {
    _ensureReady();
    try {
      return await _datasource.updateTransaction(
        userId: userId,
        transaction: transaction,
        newAttachments: newAttachments,
        removedAttachments: removedAttachments,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> markAsSettled({
    required String userId,
    required String transactionId,
    DateTime? paymentDate,
  }) async {
    _ensureReady();
    try {
      await _datasource.markAsSettled(
        userId: userId,
        transactionId: transactionId,
        paymentDate: paymentDate,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> deleteTransaction({
    required String userId,
    required TransactionEntity transaction,
  }) async {
    _ensureReady();
    try {
      await _datasource.deleteTransaction(
        userId: userId,
        transaction: transaction,
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
      fallbackMessage: 'Não foi possível processar a movimentação.',
    );
  }
}
