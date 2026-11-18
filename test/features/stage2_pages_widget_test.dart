import 'dart:async';
import 'package:finance_control/core/services/attachment_storage_service.dart';
import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/core/services/local_storage_service.dart';
import 'package:finance_control/core/theme/app_theme.dart';
import 'package:finance_control/features/accounts/application/providers/account_providers.dart';
import 'package:finance_control/features/accounts/domain/entities/account_entity.dart';
import 'package:finance_control/features/accounts/domain/repositories/account_repository.dart';
import 'package:finance_control/features/accounts/presentation/pages/accounts_page.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/categories/application/providers/category_providers.dart';
import 'package:finance_control/features/categories/domain/constants/default_categories.dart';
import 'package:finance_control/features/categories/domain/entities/category_entity.dart';
import 'package:finance_control/features/categories/domain/repositories/category_repository.dart';
import 'package:finance_control/features/categories/presentation/pages/categories_page.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/features/transactions/application/providers/transaction_providers.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_attachment.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finance_control/features/transactions/presentation/pages/transactions_page.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Stage2AuthRepo implements AuthRepository {
  final _user = const AuthUser(
    uid: 'u1',
    email: 'luiz@financecontrol.app',
    displayName: 'Luiz',
  );
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);
  @override
  AuthUser? get currentUser => _user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stage2ProfileRepo implements ProfileRepository {
  final _profile = UserProfile(
    uid: 'u1',
    displayName: 'Luiz',
    email: 'luiz@financecontrol.app',
    createdAt: DateTime(2026, 11, 17),
    updatedAt: DateTime(2026, 11, 17),
  );
  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(_profile);
  @override
  Future<UserProfile> ensureProfile({required AuthUser user}) async => _profile;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryFinanceStore {
  final categoriesController =
      StreamController<List<CategoryEntity>>.broadcast();
  final accountsController = StreamController<List<AccountEntity>>.broadcast();
  final transactionsController =
      StreamController<List<TransactionEntity>>.broadcast();

  final List<CategoryEntity> categories = [];
  final List<AccountEntity> accounts = [];
  final List<TransactionEntity> transactions = [];

  void dispose() {
    categoriesController.close();
    accountsController.close();
    transactionsController.close();
  }

  void emitAll() {
    final sortedCategories = List<CategoryEntity>.of(categories)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    categoriesController.add(List.unmodifiable(sortedCategories));
    accountsController.add(List.unmodifiable(accounts));
    transactionsController.add(List.unmodifiable(transactions));
  }
}

class _FakeCategoryRepo implements CategoryRepository {
  _FakeCategoryRepo(this.store);
  final _InMemoryFinanceStore store;

  @override
  Stream<List<CategoryEntity>> watchCategories(String userId) async* {
    final sorted = List<CategoryEntity>.of(store.categories)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    yield List.unmodifiable(sorted);
    yield* store.categoriesController.stream;
  }

  @override
  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {
    if (store.categories.isEmpty) {
      store.categories.addAll(DefaultCategories.build(DateTime.now()));
      store.emitAll();
    }
  }

  @override
  Future<CategoryEntity> createCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    final created =
        category.copyWith(id: 'cat_custom_${store.categories.length + 1}');
    store.categories.add(created);
    store.emitAll();
    return created;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountRepo implements AccountRepository {
  _FakeAccountRepo(this.store);
  final _InMemoryFinanceStore store;

  @override
  Stream<List<AccountEntity>> watchAccounts(String userId) async* {
    yield List.unmodifiable(store.accounts);
    yield* store.accountsController.stream;
  }

  @override
  Future<AccountEntity> createAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    final created = account.copyWith(
      id: 'acc_${store.accounts.length + 1}',
      currentBalanceCents: account.initialBalanceCents,
    );
    store.accounts.add(created);
    store.emitAll();
    return created;
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
    final srcIdx = store.accounts.indexWhere((a) => a.id == sourceAccountId);
    final dstIdx =
        store.accounts.indexWhere((a) => a.id == destinationAccountId);
    store.accounts[srcIdx] = store.accounts[srcIdx].copyWith(
      currentBalanceCents:
          store.accounts[srcIdx].currentBalanceCents - amountCents,
    );
    store.accounts[dstIdx] = store.accounts[dstIdx].copyWith(
      currentBalanceCents:
          store.accounts[dstIdx].currentBalanceCents + amountCents,
    );
    store.emitAll();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionRepo implements TransactionRepository {
  _FakeTransactionRepo(this.store);
  final _InMemoryFinanceStore store;

  @override
  Stream<List<TransactionEntity>> watchTransactions(String userId) async* {
    yield List.unmodifiable(store.transactions);
    yield* store.transactionsController.stream;
  }

  @override
  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  }) async {
    final created = transaction.copyWith(
      id: 'tx_${store.transactions.length + 1}',
    );
    store.transactions.insert(0, created);
    if (created.accountId != null) {
      final delta = created.signedBalanceDeltaForAccount(created.accountId!);
      final idx = store.accounts.indexWhere((a) => a.id == created.accountId);
      if (idx != -1 && delta != 0) {
        store.accounts[idx] = store.accounts[idx].copyWith(
          currentBalanceCents: store.accounts[idx].currentBalanceCents + delta,
        );
      }
    }
    store.emitAll();
    return created;
  }

  @override
  Future<void> markAsSettled({
    required String userId,
    required String transactionId,
    DateTime? paymentDate,
  }) async {
    final idx = store.transactions.indexWhere((t) => t.id == transactionId);
    final tx = store.transactions[idx];
    final updated = tx.copyWith(
      status: tx.kind == TransactionKind.income
          ? TransactionStatus.received
          : TransactionStatus.paid,
      paymentDate: paymentDate ?? DateTime.now(),
    );
    store.transactions[idx] = updated;
    if (updated.accountId != null) {
      final delta = updated.signedBalanceDeltaForAccount(updated.accountId!);
      final accIdx =
          store.accounts.indexWhere((a) => a.id == updated.accountId);
      if (accIdx != -1 && delta != 0) {
        store.accounts[accIdx] = store.accounts[accIdx].copyWith(
          currentBalanceCents:
              store.accounts[accIdx].currentBalanceCents + delta,
        );
      }
    }
    store.emitAll();
  }

  @override
  Future<TransactionEntity> updateTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
    List<TransactionAttachment> removedAttachments =
        const <TransactionAttachment>[],
  }) async =>
      transaction;

  @override
  Future<void> deleteTransaction({
    required String userId,
    required TransactionEntity transaction,
  }) async {
    store.transactions.removeWhere((t) => t.id == transaction.id);
    store.emitAll();
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  Widget wrapPage(Widget home, _InMemoryFinanceStore store) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(LocalStorageService()),
        appBootstrapStateProvider.overrideWithValue(
          const AppBootstrapState(
            firebase: FirebaseBootstrapState(
              status: FirebaseConnectionStatus.connected,
              message: 'Firebase conectado.',
              projectId: 'finance-test',
            ),
            localStorageInitialized: true,
          ),
        ),
        authRepositoryProvider.overrideWithValue(_Stage2AuthRepo()),
        profileRepositoryProvider.overrideWithValue(_Stage2ProfileRepo()),
        categoryRepositoryProvider.overrideWithValue(_FakeCategoryRepo(store)),
        accountRepositoryProvider.overrideWithValue(_FakeAccountRepo(store)),
        transactionRepositoryProvider
            .overrideWithValue(_FakeTransactionRepo(store)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: home,
      ),
    );
  }

  testWidgets('CategoriesPage seeds defaults and creates custom category',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final store = _InMemoryFinanceStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(wrapPage(const CategoriesPage(), store));
    await tester.pumpAndSettle();

    expect(find.text('Alimentação'), findsOneWidget);

    await tester.tap(find.text('Nova categoria'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da categoria'),
      'Academia',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Academia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AccountsPage creates account and executes transfer',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final store = _InMemoryFinanceStore()
      ..accounts.addAll([
        AccountEntity(
          id: 'acc_1',
          name: 'Nubank',
          institution: 'Nubank',
          type: AccountType.checking,
          initialBalanceCents: 100000,
          currentBalanceCents: 100000,
          colorHex: '#8B5CF6',
          iconName: 'account_balance',
          openedAt: now,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        AccountEntity(
          id: 'acc_2',
          name: 'Reserva',
          institution: 'Itaú',
          type: AccountType.savings,
          initialBalanceCents: 50000,
          currentBalanceCents: 50000,
          colorHex: '#10B981',
          iconName: 'savings',
          openedAt: now,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    addTearDown(store.dispose);

    await tester.pumpWidget(wrapPage(const AccountsPage(), store));
    await tester.pumpAndSettle();

    expect(find.text('Nubank'), findsOneWidget);
    expect(find.text('Reserva'), findsOneWidget);

    await tester.tap(find.text('Transferir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor (R\$)'),
      '200,00',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
    await tester.pumpAndSettle();

    expect(store.accounts[0].currentBalanceCents, 80000);
    expect(store.accounts[1].currentBalanceCents, 70000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TransactionsPage renders and settles pending expense in 1 tap',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final store = _InMemoryFinanceStore()
      ..categories.addAll(DefaultCategories.build(now))
      ..accounts.add(
        AccountEntity(
          id: 'acc_1',
          name: 'Carteira',
          institution: '',
          type: AccountType.cash,
          initialBalanceCents: 50000,
          currentBalanceCents: 50000,
          colorHex: '#0F766E',
          iconName: 'payments',
          openedAt: now,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..transactions.add(
        TransactionEntity(
          id: 'tx_1',
          kind: TransactionKind.expense,
          description: 'Conta de Luz',
          amountCents: 15000,
          categoryId: 'cat_exp_housing',
          accountId: 'acc_1',
          competencyDate: now,
          dueDate: now,
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );
    addTearDown(store.dispose);

    await tester.pumpWidget(wrapPage(const TransactionsPage(), store));
    await tester.pumpAndSettle();

    expect(find.text('Conta de Luz'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);

    await tester.tap(find.byTooltip('Marcar como paga'));
    await tester.pumpAndSettle();

    expect(store.transactions.first.status, TransactionStatus.paid);
    expect(store.accounts.first.currentBalanceCents, 35000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TransactionsPage renders cleanly on compact mobile layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final store = _InMemoryFinanceStore()
      ..categories.addAll(DefaultCategories.build(now))
      ..accounts.addAll([
        AccountEntity(
          id: 'acc_1',
          name: 'Conta Principal',
          institution: 'Nubank',
          type: AccountType.checking,
          initialBalanceCents: 100000,
          currentBalanceCents: 100000,
          colorHex: '#0F766E',
          iconName: 'account_balance',
          openedAt: now,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        AccountEntity(
          id: 'acc_2',
          name: 'Poupança',
          institution: 'Itaú',
          type: AccountType.savings,
          initialBalanceCents: 50000,
          currentBalanceCents: 50000,
          colorHex: '#3B82F6',
          iconName: 'savings',
          openedAt: now,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    addTearDown(store.dispose);

    await tester.pumpWidget(wrapPage(const TransactionsPage(), store));
    await tester.pumpAndSettle();

    expect(find.text('Movimentações'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
