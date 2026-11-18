import '../entities/account_entity.dart';

/// Contrato de persistência de contas e transferências atômicas entre contas.
abstract class AccountRepository {
  Stream<List<AccountEntity>> watchAccounts(String userId);

  Future<AccountEntity> createAccount({
    required String userId,
    required AccountEntity account,
  });

  Future<void> updateAccount({
    required String userId,
    required AccountEntity account,
  });

  Future<void> setArchived({
    required String userId,
    required String accountId,
    required bool archived,
  });

  Future<void> deleteAccount({
    required String userId,
    required String accountId,
  });

  Future<void> transferBetweenAccounts({
    required String userId,
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountCents,
    required DateTime transferDate,
    required String description,
    String? notes,
  });
}
