import 'dart:async';
import 'dart:convert';
import 'package:finance_control/core/services/attachment_storage_service.dart';
import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/core/services/local_storage_service.dart';
import 'package:finance_control/core/services/notification_service.dart';
import 'package:finance_control/core/theme/app_theme.dart';
import 'package:finance_control/features/accounts/application/providers/account_providers.dart';
import 'package:finance_control/features/accounts/domain/entities/account_entity.dart';
import 'package:finance_control/features/accounts/domain/repositories/account_repository.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/budgets/application/controllers/budget_controller.dart';
import 'package:finance_control/features/budgets/application/providers/budget_providers.dart';
import 'package:finance_control/features/budgets/domain/entities/budget_entity.dart';
import 'package:finance_control/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finance_control/features/budgets/domain/services/budget_calculator.dart';
import 'package:finance_control/features/budgets/presentation/pages/budgets_page.dart';
import 'package:finance_control/features/budgets/presentation/widgets/budget_form_dialog.dart';
import 'package:finance_control/features/categories/application/providers/category_providers.dart';
import 'package:finance_control/features/categories/domain/constants/default_categories.dart';
import 'package:finance_control/features/categories/domain/entities/category_entity.dart';
import 'package:finance_control/features/categories/domain/repositories/category_repository.dart';
import 'package:finance_control/features/credit_cards/application/providers/credit_card_providers.dart';
import 'package:finance_control/features/credit_cards/domain/entities/credit_card_entity.dart';
import 'package:finance_control/features/credit_cards/domain/entities/invoice_entity.dart';
import 'package:finance_control/features/credit_cards/domain/repositories/credit_card_repository.dart';
import 'package:finance_control/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:finance_control/features/installments/domain/entities/installment_plan_entity.dart';
import 'package:finance_control/features/notifications/application/providers/notification_providers.dart';
import 'package:finance_control/features/notifications/domain/entities/app_notification_entity.dart';
import 'package:finance_control/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/features/recurring/application/providers/recurring_providers.dart';
import 'package:finance_control/features/recurring/domain/entities/recurring_rule_entity.dart';
import 'package:finance_control/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finance_control/features/reports/domain/services/financial_analytics_service.dart';
import 'package:finance_control/features/reports/domain/services/report_export_service.dart';
import 'package:finance_control/features/reports/presentation/pages/reports_page.dart';
import 'package:finance_control/features/transactions/application/providers/transaction_providers.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_attachment.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finance_control/shared/models/date_period.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Stage5Store {
  final List<CategoryEntity> categories = [];
  final List<AccountEntity> accounts = [];
  final List<CreditCardEntity> cards = [];
  final List<InvoiceEntity> invoices = [];
  final List<InstallmentPlanEntity> plans = [];
  final List<TransactionEntity> transactions = [];
  final List<BudgetEntity> budgets = [];
  UserProfile profile = UserProfile(
    uid: 'u_stage5',
    displayName: 'Luiz',
    email: 'luiz@financecontrol.app',
    monthStartDay: 1,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );

  final categoriesController =
      StreamController<List<CategoryEntity>>.broadcast();
  final accountsController = StreamController<List<AccountEntity>>.broadcast();
  final cardsController = StreamController<List<CreditCardEntity>>.broadcast();
  final invoicesController = StreamController<List<InvoiceEntity>>.broadcast();
  final plansController =
      StreamController<List<InstallmentPlanEntity>>.broadcast();
  final txController = StreamController<List<TransactionEntity>>.broadcast();
  final budgetsController = StreamController<List<BudgetEntity>>.broadcast();
  final profileController = StreamController<UserProfile?>.broadcast();

  void emitAll() {
    categoriesController.add(List.unmodifiable(categories));
    accountsController.add(List.unmodifiable(accounts));
    cardsController.add(List.unmodifiable(cards));
    invoicesController.add(List.unmodifiable(invoices));
    plansController.add(List.unmodifiable(plans));
    txController.add(List.unmodifiable(transactions));
    budgetsController.add(List.unmodifiable(budgets));
    profileController.add(profile);
  }

  void dispose() {
    categoriesController.close();
    accountsController.close();
    cardsController.close();
    invoicesController.close();
    plansController.close();
    txController.close();
    budgetsController.close();
    profileController.close();
  }
}

class _FakeAuthRepo implements AuthRepository {
  static const user = AuthUser(
    uid: 'u_stage5',
    email: 'luiz@financecontrol.app',
    displayName: 'Luiz',
  );
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(user);
  @override
  AuthUser? get currentUser => user;
  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      user;
  @override
  Future<AuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async =>
      user;
  @override
  Future<AuthUser> signInWithGoogle() async => user;
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
  @override
  Future<void> updateDisplayName(String displayName) async {}
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<void> reauthenticateWithPassword(String currentPassword) async {}
  @override
  Future<void> deleteCurrentAuthUser() async {}
  @override
  Future<void> signOut() async {}
}

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo(this.store);
  final _Stage5Store store;
  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield store.profile;
    yield* store.profileController.stream;
  }

  @override
  Future<UserProfile> ensureProfile({required AuthUser user}) async =>
      store.profile;
  @override
  Future<void> updateProfile(UserProfile profile) async {
    store.profile = profile;
    store.emitAll();
  }

  @override
  Future<void> deleteUserData(String uid) async {}
}

class _FakeCategoryRepo implements CategoryRepository {
  _FakeCategoryRepo(this.store);
  final _Stage5Store store;
  @override
  Stream<List<CategoryEntity>> watchCategories(String userId) async* {
    yield List.unmodifiable(store.categories);
    yield* store.categoriesController.stream;
  }

  @override
  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {}
  @override
  Future<CategoryEntity> createCategory({
    required String userId,
    required CategoryEntity category,
  }) async =>
      category;
  @override
  Future<void> updateCategory({
    required String userId,
    required CategoryEntity category,
  }) async {}
  @override
  Future<void> setArchived({
    required String userId,
    required String categoryId,
    required bool archived,
  }) async {}
  @override
  Future<void> deleteCategory({
    required String userId,
    required String categoryId,
  }) async {}
}

class _FakeAccountRepo implements AccountRepository {
  _FakeAccountRepo(this.store);
  final _Stage5Store store;
  @override
  Stream<List<AccountEntity>> watchAccounts(String userId) async* {
    yield List.unmodifiable(store.accounts);
    yield* store.accountsController.stream;
  }

  @override
  Future<AccountEntity> createAccount({
    required String userId,
    required AccountEntity account,
  }) async =>
      account;
  @override
  Future<void> updateAccount({
    required String userId,
    required AccountEntity account,
  }) async {}
  @override
  Future<void> setArchived({
    required String userId,
    required String accountId,
    required bool archived,
  }) async {}
  @override
  Future<void> deleteAccount({
    required String userId,
    required String accountId,
  }) async {}
  @override
  Future<void> transferBetweenAccounts({
    required String userId,
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountCents,
    required DateTime transferDate,
    required String description,
    String? notes,
  }) async {}
}

class _FakeTransactionRepo implements TransactionRepository {
  _FakeTransactionRepo(this.store);
  final _Stage5Store store;
  @override
  Stream<List<TransactionEntity>> watchTransactions(String userId) async* {
    yield List.unmodifiable(store.transactions);
    yield* store.txController.stream;
  }

  @override
  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  }) async =>
      transaction;
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
  Future<void> markAsSettled({
    required String userId,
    required String transactionId,
    DateTime? paymentDate,
  }) async {}
  @override
  Future<void> deleteTransaction({
    required String userId,
    required TransactionEntity transaction,
  }) async {}
}

class _FakeCreditCardRepo implements CreditCardRepository {
  _FakeCreditCardRepo(this.store);
  final _Stage5Store store;
  @override
  Stream<List<CreditCardEntity>> watchCards(String userId) async* {
    yield List.unmodifiable(store.cards);
    yield* store.cardsController.stream;
  }

  @override
  Stream<List<InvoiceEntity>> watchInvoices(String userId) async* {
    yield List.unmodifiable(store.invoices);
    yield* store.invoicesController.stream;
  }

  @override
  Stream<List<InstallmentPlanEntity>> watchInstallmentPlans(
    String userId,
  ) async* {
    yield List.unmodifiable(store.plans);
    yield* store.plansController.stream;
  }

  @override
  Future<CreditCardEntity> createCard({
    required String userId,
    required CreditCardEntity card,
  }) async =>
      card;
  @override
  Future<void> updateCard({
    required String userId,
    required CreditCardEntity card,
  }) async {}
  @override
  Future<void> setArchived({
    required String userId,
    required String cardId,
    required bool archived,
  }) async {}
  @override
  Future<void> deleteCard({
    required String userId,
    required String cardId,
  }) async {}
  @override
  Future<void> recordCardPurchase({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int totalAmountCents,
    required int installmentCount,
    required DateTime purchaseDate,
    String? notes,
  }) async {}
  @override
  Future<void> recordCardStandaloneRefund({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime refundDate,
    String? notes,
  }) async {}
  @override
  Future<void> recordAccountInstallmentPurchase({
    required String userId,
    required String accountId,
    required String categoryId,
    required String description,
    required int totalAmountCents,
    required int installmentCount,
    required DateTime purchaseDate,
    required DateTime firstDueDate,
    String? notes,
  }) async {}
  @override
  Future<void> payInvoice({
    required String userId,
    required String invoiceId,
    required String paymentAccountId,
    required DateTime paymentDate,
  }) async {}
  @override
  Future<void> refundOrCancelCardPurchase({
    required String userId,
    required String transactionId,
    bool cancelAllPlanInstallments = true,
  }) async {}
}

class _FakeBudgetRepo implements BudgetRepository {
  _FakeBudgetRepo(this.store);
  final _Stage5Store store;

  @override
  Stream<List<BudgetEntity>> watchBudgets(String userId) async* {
    yield List.unmodifiable(store.budgets);
    yield* store.budgetsController.stream;
  }

  @override
  Future<BudgetEntity> upsertBudget({
    required String userId,
    required BudgetEntity budget,
  }) async {
    final idx = store.budgets.indexWhere((b) => b.id == budget.id);
    if (idx != -1) {
      store.budgets[idx] = budget;
    } else {
      store.budgets.add(budget);
    }
    store.emitAll();
    return budget;
  }

  @override
  Future<int> copyFromPreviousMonth({
    required String userId,
    required int sourceYear,
    required int sourceMonth,
    required int targetYear,
    required int targetMonth,
  }) async {
    final src = store.budgets
        .where((b) => b.year == sourceYear && b.month == sourceMonth)
        .toList();
    var copied = 0;
    for (final item in src) {
      final targetId = BudgetEntity.deterministicId(
        categoryId: item.categoryId,
        year: targetYear,
        month: targetMonth,
      );
      if (store.budgets.any((b) => b.id == targetId)) continue;
      store.budgets.add(
        item.copyWith(id: targetId, year: targetYear, month: targetMonth),
      );
      copied++;
    }
    store.emitAll();
    return copied;
  }

  @override
  Future<void> deleteBudget({
    required String userId,
    required String budgetId,
  }) async {
    store.budgets.removeWhere((b) => b.id == budgetId);
    store.emitAll();
  }
}

class _FakeRecurringRepo implements RecurringRepository {
  @override
  Stream<List<RecurringRuleEntity>> watchRules(String userId) =>
      Stream.value(const <RecurringRuleEntity>[]);
  @override
  Future<RecurringRuleEntity> createRule({
    required String userId,
    required RecurringRuleEntity rule,
    DateTime? referenceDate,
  }) async =>
      rule;
  @override
  Future<void> updateRule({
    required String userId,
    required RecurringRuleEntity rule,
  }) async {}
  @override
  Future<void> setStatus({
    required String userId,
    required String ruleId,
    required RecurringStatus status,
  }) async {}
  @override
  Future<void> deleteRule({
    required String userId,
    required String ruleId,
  }) async {}
  @override
  Future<int> syncOccurrences({
    required String userId,
    DateTime? referenceDate,
  }) async =>
      0;
  @override
  Future<void> updateSingleCardOccurrence({
    required String userId,
    required String transactionId,
    required String description,
    required int amountCents,
    String? notes,
  }) async {}
}

class _FakeNotificationRepo implements NotificationRepository {
  @override
  Stream<List<AppNotificationEntity>> watchNotifications(String userId) =>
      Stream.value(const <AppNotificationEntity>[]);
  @override
  Future<int> syncSystemAlerts({
    required String userId,
    required List<AppNotificationEntity> candidates,
  }) async =>
      0;
  @override
  Future<AppNotificationEntity> createCustomReminder({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? referenceId,
  }) async =>
      AppNotificationEntity(
        id: 'n1',
        title: title,
        body: body,
        type: NotificationType.customReminder,
        scheduledFor: scheduledFor,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
  @override
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
    required bool isRead,
  }) async {}
  @override
  Future<void> markAllAsRead(String userId) async {}
  @override
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {}
  @override
  Future<void> registerDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {}
}

List<Override> _stage5Overrides(_Stage5Store store) => [
      localStorageServiceProvider.overrideWithValue(LocalStorageService()),
      appBootstrapStateProvider.overrideWithValue(
        const AppBootstrapState(
          firebase: FirebaseBootstrapState(
            status: FirebaseConnectionStatus.connected,
            message: 'Conectado',
            projectId: 'finance-test',
          ),
          localStorageInitialized: true,
        ),
      ),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
      currentAuthUserProvider.overrideWithValue(_FakeAuthRepo.user),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepo(store)),
      categoryRepositoryProvider.overrideWithValue(_FakeCategoryRepo(store)),
      accountRepositoryProvider.overrideWithValue(_FakeAccountRepo(store)),
      transactionRepositoryProvider
          .overrideWithValue(_FakeTransactionRepo(store)),
      creditCardRepositoryProvider
          .overrideWithValue(_FakeCreditCardRepo(store)),
      budgetRepositoryProvider.overrideWithValue(_FakeBudgetRepo(store)),
      recurringRepositoryProvider.overrideWithValue(_FakeRecurringRepo()),
      notificationRepositoryProvider.overrideWithValue(_FakeNotificationRepo()),
      notificationServiceProvider.overrideWithValue(
        NotificationService(const FirebaseBootstrapState.awaitingConfiguration()),
      ),
    ];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  group('DatePeriod & BudgetCalculator', () {
    test('respects monthStartDay accounting cycles cleanly', () {
      final beforeStart = DatePeriod.resolveAccountingYearMonth(
        DateTime(2026, 11, 3),
        monthStartDay: 5,
      );
      expect(beforeStart, (year: 2026, month: 10));

      final onStart = DatePeriod.resolveAccountingYearMonth(
        DateTime(2026, 11, 5),
        monthStartDay: 5,
      );
      expect(onStart, (year: 2026, month: 11));

      final cycle = DatePeriod.accountingMonth(2026, 11, monthStartDay: 5);
      expect(cycle.start, DateTime(2026, 11, 5));
      expect(cycle.end.year, 2026);
      expect(cycle.end.month, 12);
      expect(cycle.end.day, 4);
    });

    test('calculates category spend, health thresholds and excludes transfers/invoice payments', () {
      final now = DateTime(2026, 11, 18);
      final budgets = [
        BudgetEntity(
          id: 'cat_food_2026_11',
          categoryId: 'cat_food',
          year: 2026,
          month: 11,
          limitCents: 100000,
          alertThresholdPercent: 80,
          createdAt: now,
          updatedAt: now,
        ),
        BudgetEntity(
          id: 'cat_trans_2026_11',
          categoryId: 'cat_trans',
          year: 2026,
          month: 11,
          limitCents: 30000,
          alertThresholdPercent: 80,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final txs = [
        TransactionEntity(
          id: 'tx1',
          kind: TransactionKind.expense,
          description: 'Mercado',
          amountCents: 60000,
          categoryId: 'cat_food',
          accountId: 'acc_1',
          competencyDate: DateTime(2026, 11, 10),
          status: TransactionStatus.paid,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx2',
          kind: TransactionKind.cardPurchase,
          description: 'Restaurante',
          amountCents: 30000,
          categoryId: 'cat_food',
          cardId: 'card_1',
          invoiceId: 'card_1_2026_11',
          competencyDate: DateTime(2026, 11, 12),
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx3',
          kind: TransactionKind.cardRefund,
          description: 'Estorno restaurante',
          amountCents: 5000,
          categoryId: 'cat_food',
          cardId: 'card_1',
          invoiceId: 'card_1_2026_11',
          competencyDate: DateTime(2026, 11, 14),
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx4',
          kind: TransactionKind.expense,
          description: 'Uber',
          amountCents: 35000,
          categoryId: 'cat_trans',
          accountId: 'acc_1',
          competencyDate: DateTime(2026, 11, 15),
          status: TransactionStatus.paid,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx5',
          kind: TransactionKind.invoicePayment,
          description: 'Pagamento fatura',
          amountCents: 25000,
          categoryId: 'cat_food',
          accountId: 'acc_1',
          competencyDate: DateTime(2026, 11, 16),
          status: TransactionStatus.completed,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final usages = BudgetCalculator.evaluateMonth(
        budgets: budgets,
        transactions: txs,
        year: 2026,
        month: 11,
      );

      expect(usages.length, 2);
      // cat_trans (117%) vem antes de cat_food (85%)
      expect(usages[0].budget.categoryId, 'cat_trans');
      expect(usages[0].spentCents, 35000);
      expect(usages[0].healthStatus, BudgetHealthStatus.exceeded);

      expect(usages[1].budget.categoryId, 'cat_food');
      expect(usages[1].spentCents, 85000); // 60000 + 30000 - 5000 (ignorou tx5)
      expect(usages[1].remainingCents, 15000);
      expect(usages[1].healthStatus, BudgetHealthStatus.warning);
    });
  });

  group('FinancialAnalyticsService & ReportExportService', () {
    test('builds consistent projections without double counting cards and exports valid CSV/PDF', () async {
      final now = DateTime(2026, 11, 18);
      final categories = {
        for (final c in DefaultCategories.build(now)) c.id: c,
      };
      final accounts = [
        AccountEntity(
          id: 'acc_1',
          name: 'Nubank Conta',
          institution: 'Nubank',
          type: AccountType.checking,
          initialBalanceCents: 300000,
          currentBalanceCents: 300000,
          colorHex: '#0F766E',
          iconName: 'account_balance',
          openedAt: now,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final cards = [
        CreditCardEntity(
          id: 'card_1',
          name: 'Nubank Crédito',
          institution: 'Nubank',
          brand: CardBrand.mastercard,
          totalLimitCents: 500000,
          usedLimitCents: 80000,
          closingDay: 10,
          dueDay: 25,
          paymentAccountId: 'acc_1',
          colorHex: '#7C3AED',
          defaultInstallments: 1,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final invoices = [
        InvoiceEntity(
          id: 'card_1_2026_11',
          cardId: 'card_1',
          referenceYear: 2026,
          referenceMonth: 11,
          closingDate: DateTime(2026, 11, 10),
          dueDate: DateTime(2026, 11, 25),
          totalAmountCents: 80000,
          paidAmountCents: 0,
          status: InvoiceStatus.closed,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final plans = [
        InstallmentPlanEntity(
          id: 'plan_1',
          description: 'Notebook',
          totalAmountCents: 160000,
          installmentCount: 2,
          firstCompetencyDate: now,
          firstDueDate: DateTime(2026, 11, 25),
          categoryId: 'cat_exp_food',
          cardId: 'card_1',
          status: InstallmentPlanStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final transactions = [
        TransactionEntity(
          id: 'tx_in',
          kind: TransactionKind.income,
          description: 'Freela a receber',
          amountCents: 100000,
          categoryId: 'cat_inc_salary',
          accountId: 'acc_1',
          competencyDate: DateTime(2026, 11, 22),
          dueDate: DateTime(2026, 11, 22),
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx_exp',
          kind: TransactionKind.expense,
          description: 'Aluguel pendente',
          amountCents: 50000,
          categoryId: 'cat_exp_housing',
          accountId: 'acc_1',
          competencyDate: DateTime(2026, 11, 24),
          dueDate: DateTime(2026, 11, 24),
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx_card_1',
          kind: TransactionKind.cardPurchase,
          description: 'Notebook (1/2)',
          amountCents: 80000,
          categoryId: 'cat_exp_housing',
          cardId: 'card_1',
          invoiceId: 'card_1_2026_11',
          installmentPlanId: 'plan_1',
          installmentNumber: 1,
          totalInstallments: 2,
          competencyDate: DateTime(2026, 11, 5),
          dueDate: DateTime(2026, 11, 25),
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx_paid_out',
          kind: TransactionKind.expense,
          description: 'Mercado pago',
          amountCents: 20000,
          categoryId: 'cat_exp_food',
          accountId: 'acc_1',
          competencyDate: DateTime(2026, 11, 10),
          status: TransactionStatus.paid,
          paymentDate: DateTime(2026, 11, 10),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final period = DatePeriod.fromType(DatePeriodType.thisMonth, reference: now);
      final snapshot = FinancialAnalyticsService.buildSnapshot(
        period: period,
        allTransactions: transactions,
        accounts: accounts,
        cards: cards,
        invoices: invoices,
        installmentPlans: plans,
        categoriesById: categories,
        referenceDate: now,
      );

      // Saldo 300000 + 100000 (receita pend.) - 50000 (despesa conta pend.) - 80000 (fatura) = 270000
      // Sem duplicar tx_card_1 com a fatura card_1_2026_11!
      expect(snapshot.projectedEndOfMonthCents, 270000);
      expect(snapshot.cashFlow.outflowsCents, 20000);
      expect(snapshot.installmentsPortfolio.futureCommittedCents, 80000);
      expect(snapshot.projections.length, 3);
      expect(snapshot.byCategory.isNotEmpty, isTrue);

      final csv = ReportExportService.buildCsv(snapshot);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('RESUMO EXECUTIVO'), isTrue);
      expect(csv.contains('DESPESAS POR CATEGORIA'), isTrue);
      expect(csv.contains('PROJECAO FINANCEIRA'), isTrue);

      final pdfBytes = await ReportExportService.buildPdfBytes(snapshot);
      expect(pdfBytes.length, greaterThan(500));
      // Assinatura binária %PDF-
      expect(ascii.decode(pdfBytes.take(5).toList()), '%PDF-');
    });
  });

  group('BudgetController & Stage 5 Widgets (Mobile 360x780 + Desktop)', () {
    test('BudgetController upserts idempotently and copies previous month without overwriting', () async {
      final now = DateTime(2026, 11, 18);
      final store = _Stage5Store()..categories.addAll(DefaultCategories.build(now));
      store.budgets.add(
        BudgetEntity(
          id: 'cat_exp_food_2026_10',
          categoryId: 'cat_exp_food',
          year: 2026,
          month: 10,
          limitCents: 90000,
          createdAt: now,
          updatedAt: now,
        ),
      );
      addTearDown(store.dispose);

      final container = ProviderContainer(overrides: _stage5Overrides(store));
      addTearDown(container.dispose);

      final ctrl = container.read(budgetControllerProvider.notifier);
      final saved = await ctrl.saveBudget(
        categoryId: 'cat_exp_food',
        year: 2026,
        month: 11,
        limitCents: 120000,
      );
      expect(saved, isTrue);
      expect(store.budgets.length, 2);

      // Atualização na mesma categoria/mês não duplica documento.
      await ctrl.saveBudget(
        categoryId: 'cat_exp_food',
        year: 2026,
        month: 11,
        limitCents: 130000,
      );
      expect(store.budgets.length, 2);
      expect(
        store.budgets
            .firstWhere((b) => b.id == 'cat_exp_food_2026_11')
            .limitCents,
        130000,
      );

      // Copiar do mês 10 para mês 11 preserva a meta editada (130000) sem duplicar.
      await ctrl.copyFromPreviousMonth(targetYear: 2026, targetMonth: 11);
      expect(
        store.budgets
            .firstWhere((b) => b.id == 'cat_exp_food_2026_11')
            .limitCents,
        130000,
      );
    });

    testWidgets(
        'BudgetsPage, BudgetFormDialog, ReportsPage and DashboardPage render without overflow at 360x780',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final ym = DatePeriod.resolveAccountingYearMonth(now);
      final store = _Stage5Store()
        ..categories.addAll(DefaultCategories.build(now))
        ..accounts.add(
          AccountEntity(
            id: 'acc_1',
            name: 'Conta Corrente Nubank',
            institution: 'Nubank',
            type: AccountType.checking,
            initialBalanceCents: 400000,
            currentBalanceCents: 400000,
            colorHex: '#0F766E',
            iconName: 'account_balance',
            openedAt: now,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        )
        ..cards.add(
          CreditCardEntity(
            id: 'card_1',
            name: 'Cartão Nubank',
            institution: 'Nubank',
            brand: CardBrand.mastercard,
            totalLimitCents: 500000,
            usedLimitCents: 50000,
            closingDay: 10,
            dueDay: 20,
            paymentAccountId: 'acc_1',
            colorHex: '#7C3AED',
            defaultInstallments: 1,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        )
        ..invoices.add(
          InvoiceEntity(
            id: 'card_1_${ym.year}_${ym.month.toString().padLeft(2, '0')}',
            cardId: 'card_1',
            referenceYear: ym.year,
            referenceMonth: ym.month,
            closingDate: now,
            dueDate: now.add(const Duration(days: 5)),
            totalAmountCents: 50000,
            paidAmountCents: 0,
            status: InvoiceStatus.open,
            createdAt: now,
            updatedAt: now,
          ),
        )
        ..budgets.add(
          BudgetEntity(
            id: BudgetEntity.deterministicId(
              categoryId: 'cat_exp_food',
              year: ym.year,
              month: ym.month,
            ),
            categoryId: 'cat_exp_food',
            year: ym.year,
            month: ym.month,
            limitCents: 100000,
            createdAt: now,
            updatedAt: now,
          ),
        )
        ..transactions.addAll([
          TransactionEntity(
            id: 'tx_food_1',
            kind: TransactionKind.expense,
            description: 'Supermercado Central',
            amountCents: 85000,
            categoryId: 'cat_exp_food',
            accountId: 'acc_1',
            competencyDate: now,
            status: TransactionStatus.paid,
            createdAt: now,
            updatedAt: now,
          ),
          TransactionEntity(
            id: 'tx_bill_1',
            kind: TransactionKind.expense,
            description: 'Energia Elétrica',
            amountCents: 22000,
            categoryId: 'cat_exp_housing',
            accountId: 'acc_1',
            competencyDate: now,
            dueDate: now.add(const Duration(days: 2)),
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        ]);
      addTearDown(store.dispose);

      Widget wrap(Widget child) {
        return ProviderScope(
          overrides: _stage5Overrides(store),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: child),
          ),
        );
      }

      await tester.pumpWidget(
        wrap(BudgetFormDialog(year: ym.year, month: ym.month)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Novo orçamento'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap(const BudgetsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Orçamentos'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Alimentação'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap(const ReportsPage()));
      await tester.pumpAndSettle();
      expect(find.text('Relatórios'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap(const DashboardPage()));
      await tester.pumpAndSettle();
      expect(find.text('Finance Control'), findsOneWidget);
      await tester.ensureVisible(find.text('Contas com vencimento próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Contas com vencimento próximo'), findsOneWidget);
      await tester.ensureVisible(find.text('Orçamentos do mês'));
      await tester.pumpAndSettle();
      expect(find.text('Orçamentos do mês'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
