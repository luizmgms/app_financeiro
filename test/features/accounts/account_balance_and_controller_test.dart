import 'package:finance_control/features/accounts/application/controllers/account_controller.dart';
import 'package:finance_control/features/accounts/application/providers/account_providers.dart';
import 'package:finance_control/features/accounts/domain/entities/account_entity.dart';
import 'package:finance_control/features/accounts/domain/repositories/account_repository.dart';
import 'package:finance_control/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo(this._user);
  final AuthUser? _user;
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);
  @override
  AuthUser? get currentUser => _user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountRepository implements AccountRepository {
  final Map<String, AccountEntity> accounts = <String, AccountEntity>{};
  int transferCalls = 0;

  @override
  Stream<List<AccountEntity>> watchAccounts(String userId) {
    return Stream.value(accounts.values.toList(growable: false));
  }

  @override
  Future<AccountEntity> createAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    final created = account.copyWith(id: 'acc_${accounts.length + 1}');
    accounts[created.id] = created;
    return created;
  }

  @override
  Future<void> updateAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    accounts[account.id] = account;
  }

  @override
  Future<void> setArchived({
    required String userId,
    required String accountId,
    required bool archived,
  }) async {
    final existing = accounts[accountId];
    if (existing != null) {
      accounts[accountId] = existing.copyWith(isActive: !archived);
    }
  }

  @override
  Future<void> deleteAccount({
    required String userId,
    required String accountId,
  }) async {
    accounts.remove(accountId);
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
    transferCalls++;
    final source = accounts[sourceAccountId]!;
    final dest = accounts[destinationAccountId]!;
    accounts[sourceAccountId] = source.copyWith(
      currentBalanceCents: source.currentBalanceCents - amountCents,
    );
    accounts[destinationAccountId] = dest.copyWith(
      currentBalanceCents: dest.currentBalanceCents + amountCents,
    );
  }
}

void main() {
  test(
      'AccountBalanceCalculator sums only settled transactions and transfers for the account',
      () {
    final now = DateTime(2026, 11, 17);
    final transactions = <TransactionEntity>[
      TransactionEntity(
        id: 't1',
        kind: TransactionKind.income,
        description: 'Salário',
        amountCents: 500000,
        accountId: 'acc_1',
        competencyDate: now,
        status: TransactionStatus.received,
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 't2',
        kind: TransactionKind.expense,
        description: 'Aluguel',
        amountCents: 180000,
        accountId: 'acc_1',
        competencyDate: now,
        status: TransactionStatus.paid,
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 't3',
        kind: TransactionKind.expense,
        description: 'Conta futura pendente',
        amountCents: 50000,
        accountId: 'acc_1',
        competencyDate: now,
        status: TransactionStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 't4',
        kind: TransactionKind.transfer,
        description: 'Para poupança',
        amountCents: 100000,
        accountId: 'acc_1',
        destinationAccountId: 'acc_2',
        transferDirection: TransferDirection.outflow,
        competencyDate: now,
        status: TransactionStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 't5',
        kind: TransactionKind.cardPurchase,
        description: 'Compra no cartão não debita conta',
        amountCents: 25000,
        accountId: 'acc_1',
        competencyDate: now,
        status: TransactionStatus.paid,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final balance = AccountBalanceCalculator.calculateBalance(
      accountId: 'acc_1',
      initialBalanceCents: 100000,
      transactions: transactions,
    );

    // 1000 + 5000 - 1800 - 1000 = 3200.00 (320000 cents)
    expect(balance, 320000);
  });

  test('AccountController creates accounts and validates atomic transfers',
      () async {
    final fakeRepo = _FakeAccountRepository();
    const user = AuthUser(
      uid: 'u1',
      email: 'luiz@app.com',
      displayName: 'Luiz',
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo(user)),
        currentAuthUserProvider.overrideWithValue(user),
        accountRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(accountControllerProvider.notifier);

    expect(
      await controller.saveAccount(
        name: 'Conta Corrente',
        institution: 'Nubank',
        type: AccountType.checking,
        initialBalanceCents: 250000,
        colorHex: '#0F766E',
        iconName: 'account_balance',
        openedAt: DateTime(2026, 1, 1),
      ),
      isTrue,
    );
    expect(
      await controller.saveAccount(
        name: 'Poupança',
        institution: 'Itaú',
        type: AccountType.savings,
        initialBalanceCents: 50000,
        colorHex: '#3B82F6',
        iconName: 'savings',
        openedAt: DateTime(2026, 1, 1),
      ),
      isTrue,
    );

    final sameAccountResult = await controller.transferBetweenAccounts(
      sourceAccountId: 'acc_1',
      destinationAccountId: 'acc_1',
      amountCents: 10000,
      transferDate: DateTime(2026, 11, 17),
      description: 'Inválida',
    );
    expect(sameAccountResult, isFalse);
    expect(fakeRepo.transferCalls, 0);

    final zeroAmountResult = await controller.transferBetweenAccounts(
      sourceAccountId: 'acc_1',
      destinationAccountId: 'acc_2',
      amountCents: 0,
      transferDate: DateTime(2026, 11, 17),
      description: 'Inválida',
    );
    expect(zeroAmountResult, isFalse);
    expect(fakeRepo.transferCalls, 0);

    final ok = await controller.transferBetweenAccounts(
      sourceAccountId: 'acc_1',
      destinationAccountId: 'acc_2',
      amountCents: 75000,
      transferDate: DateTime(2026, 11, 17),
      description: 'Reserva',
    );
    expect(ok, isTrue);
    expect(fakeRepo.transferCalls, 1);
    expect(fakeRepo.accounts['acc_1']?.currentBalanceCents, 175000);
    expect(fakeRepo.accounts['acc_2']?.currentBalanceCents, 125000);
  });
}
