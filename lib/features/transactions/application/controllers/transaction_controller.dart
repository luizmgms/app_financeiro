import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/attachment_storage_service.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../domain/entities/transaction_attachment.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';

class TransactionActionState extends Equatable {
  const TransactionActionState({
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

/// Controller para cadastro, edição, baixa rápida e exclusão de movimentações.
class TransactionController extends Notifier<TransactionActionState> {
  @override
  TransactionActionState build() => const TransactionActionState();

  Future<bool> saveTransaction({
    TransactionEntity? existing,
    required TransactionKind kind,
    required String description,
    required int amountCents,
    required String? categoryId,
    required String? accountId,
    required DateTime competencyDate,
    DateTime? dueDate,
    DateTime? paymentDate,
    required TransactionStatus status,
    String? notes,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
    List<TransactionAttachment> removedAttachments =
        const <TransactionAttachment>[],
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const TransactionActionState(
        errorMessage: 'Faça login para registrar movimentações.',
      );
      return false;
    }

    final trimmedDesc = description.trim();
    if (trimmedDesc.isEmpty) {
      state = const TransactionActionState(
        errorMessage: 'Informe a descrição do lançamento.',
      );
      return false;
    }
    if (amountCents <= 0) {
      state = const TransactionActionState(
        errorMessage: 'Informe um valor maior que zero.',
      );
      return false;
    }
    if (categoryId == null || categoryId.isEmpty) {
      state = const TransactionActionState(
        errorMessage: 'Selecione uma categoria.',
      );
      return false;
    }
    if (accountId == null || accountId.isEmpty) {
      state = const TransactionActionState(
        errorMessage: 'Selecione a conta financeira.',
      );
      return false;
    }

    state = const TransactionActionState(isLoading: true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final now = DateTime.now();
      final effectivePaymentDate =
          status.isSettled ? (paymentDate ?? competencyDate) : null;

      if (existing == null) {
        final created = TransactionEntity(
          id: '',
          kind: kind,
          description: trimmedDesc,
          amountCents: amountCents,
          categoryId: categoryId,
          accountId: accountId,
          competencyDate: competencyDate,
          dueDate: dueDate,
          paymentDate: effectivePaymentDate,
          status: status,
          notes: notes?.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await repo.createTransaction(
          userId: user.uid,
          transaction: created,
          newAttachments: newAttachments,
        );
        state = TransactionActionState(
          successMessage: kind == TransactionKind.income
              ? 'Receita registrada com sucesso.'
              : 'Despesa registrada com sucesso.',
        );
      } else {
        final updated = existing.copyWith(
          kind: kind,
          description: trimmedDesc,
          amountCents: amountCents,
          categoryId: categoryId,
          accountId: accountId,
          competencyDate: competencyDate,
          dueDate: dueDate,
          clearDueDate: dueDate == null,
          paymentDate: effectivePaymentDate,
          clearPaymentDate: effectivePaymentDate == null,
          status: status,
          notes: notes?.trim(),
          clearNotes: notes == null || notes.trim().isEmpty,
          updatedAt: now,
        );
        await repo.updateTransaction(
          userId: user.uid,
          transaction: updated,
          newAttachments: newAttachments,
          removedAttachments: removedAttachments,
        );
        state = const TransactionActionState(
          successMessage: 'Movimentação atualizada com sucesso.',
        );
      }
      return true;
    } on Failure catch (failure) {
      state = TransactionActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = TransactionActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível salvar a movimentação.',
        ),
      );
      return false;
    }
  }

  Future<bool> markAsSettled(String transactionId) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const TransactionActionState(isLoading: true);
    try {
      await ref.read(transactionRepositoryProvider).markAsSettled(
            userId: user.uid,
            transactionId: transactionId,
          );
      state = const TransactionActionState(
        successMessage: 'Status atualizado e saldo recalculado.',
      );
      return true;
    } on Failure catch (failure) {
      state = TransactionActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = TransactionActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível confirmar a liquidação.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteTransaction(TransactionEntity transaction) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const TransactionActionState(isLoading: true);
    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(
            userId: user.uid,
            transaction: transaction,
          );
      state = const TransactionActionState(
        successMessage: 'Movimentação excluída com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = TransactionActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = TransactionActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível excluir a movimentação.',
        ),
      );
      return false;
    }
  }
}

final transactionControllerProvider =
    NotifierProvider<TransactionController, TransactionActionState>(
  TransactionController.new,
);
