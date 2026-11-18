import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../domain/entities/account_entity.dart';
import '../providers/account_providers.dart';

class AccountActionState extends Equatable {
  const AccountActionState({
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

/// Controller para cadastro, edição, arquivamento, exclusão e transferências entre contas.
class AccountController extends Notifier<AccountActionState> {
  @override
  AccountActionState build() => const AccountActionState();

  Future<bool> saveAccount({
    AccountEntity? existing,
    required String name,
    required String institution,
    required AccountType type,
    required int initialBalanceCents,
    required String colorHex,
    required String iconName,
    required DateTime openedAt,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const AccountActionState(
        errorMessage: 'Faça login para gerenciar contas.',
      );
      return false;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = const AccountActionState(
        errorMessage: 'Informe o nome da conta.',
      );
      return false;
    }

    state = const AccountActionState(isLoading: true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      final now = DateTime.now();

      if (existing == null) {
        final created = AccountEntity(
          id: '',
          name: trimmedName,
          institution: institution.trim(),
          type: type,
          initialBalanceCents: initialBalanceCents,
          currentBalanceCents: initialBalanceCents,
          colorHex: colorHex,
          iconName: iconName,
          openedAt: openedAt,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createAccount(userId: user.uid, account: created);
        state = const AccountActionState(
          successMessage: 'Conta criada com sucesso.',
        );
      } else {
        final updated = existing.copyWith(
          name: trimmedName,
          institution: institution.trim(),
          type: type,
          initialBalanceCents: initialBalanceCents,
          colorHex: colorHex,
          iconName: iconName,
          openedAt: openedAt,
          updatedAt: now,
        );
        await repo.updateAccount(userId: user.uid, account: updated);
        state = const AccountActionState(
          successMessage: 'Conta atualizada com sucesso.',
        );
      }
      return true;
    } on Failure catch (failure) {
      state = AccountActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = AccountActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível salvar a conta.',
        ),
      );
      return false;
    }
  }

  Future<bool> setArchived({
    required String accountId,
    required bool archived,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const AccountActionState(isLoading: true);
    try {
      await ref.read(accountRepositoryProvider).setArchived(
            userId: user.uid,
            accountId: accountId,
            archived: archived,
          );
      state = AccountActionState(
        successMessage: archived
            ? 'Conta arquivada com sucesso.'
            : 'Conta reativada com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = AccountActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = AccountActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível atualizar o status da conta.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteAccount(String accountId) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const AccountActionState(isLoading: true);
    try {
      await ref.read(accountRepositoryProvider).deleteAccount(
            userId: user.uid,
            accountId: accountId,
          );
      state = const AccountActionState(
        successMessage: 'Conta excluída com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = AccountActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = AccountActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível excluir a conta.',
        ),
      );
      return false;
    }
  }

  Future<bool> transferBetweenAccounts({
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountCents,
    required DateTime transferDate,
    required String description,
    String? notes,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const AccountActionState(
        errorMessage: 'Faça login para realizar transferências.',
      );
      return false;
    }

    if (sourceAccountId == destinationAccountId) {
      state = const AccountActionState(
        errorMessage: 'Selecione contas diferentes de origem e destino.',
      );
      return false;
    }
    if (amountCents <= 0) {
      state = const AccountActionState(
        errorMessage: 'Informe um valor maior que zero.',
      );
      return false;
    }

    state = const AccountActionState(isLoading: true);
    try {
      await ref.read(accountRepositoryProvider).transferBetweenAccounts(
            userId: user.uid,
            sourceAccountId: sourceAccountId,
            destinationAccountId: destinationAccountId,
            amountCents: amountCents,
            transferDate: transferDate,
            description: description,
            notes: notes,
          );
      state = const AccountActionState(
        successMessage: 'Transferência registrada com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = AccountActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = AccountActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível concluir a transferência.',
        ),
      );
      return false;
    }
  }
}

final accountControllerProvider =
    NotifierProvider<AccountController, AccountActionState>(
  AccountController.new,
);
