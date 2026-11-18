import '../../../transactions/domain/entities/transaction_entity.dart';

/// Regras puras de cálculo e reconciliação de saldo para contas financeiras.
abstract final class AccountBalanceCalculator {
  /// Calcula o saldo atual de uma conta a partir do [initialBalanceCents]
  /// somado apenas às movimentações liquidadas pertencentes à conta.
  static int calculateBalance({
    required String accountId,
    required int initialBalanceCents,
    required Iterable<TransactionEntity> transactions,
  }) {
    var balance = initialBalanceCents;
    for (final tx in transactions) {
      balance += tx.signedBalanceDeltaForAccount(accountId);
    }
    return balance;
  }

  /// Soma o saldo consolidado de contas ativas.
  static int totalActiveBalance(Iterable<int> activeBalancesCents) {
    var total = 0;
    for (final value in activeBalancesCents) {
      total += value;
    }
    return total;
  }
}
