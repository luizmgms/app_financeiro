import '../../../../core/services/attachment_storage_service.dart';
import '../entities/transaction_attachment.dart';
import '../entities/transaction_entity.dart';

/// Contrato de persistência de movimentações financeiras e seus anexos.
abstract class TransactionRepository {
  Stream<List<TransactionEntity>> watchTransactions(String userId);

  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  });

  Future<TransactionEntity> updateTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
    List<TransactionAttachment> removedAttachments =
        const <TransactionAttachment>[],
  });

  Future<void> markAsSettled({
    required String userId,
    required String transactionId,
    DateTime? paymentDate,
  });

  Future<void> deleteTransaction({
    required String userId,
    required TransactionEntity transaction,
  });
}
