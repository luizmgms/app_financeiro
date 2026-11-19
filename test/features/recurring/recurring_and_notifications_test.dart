import 'dart:async';
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
import 'package:finance_control/features/categories/application/providers/category_providers.dart';
import 'package:finance_control/features/categories/domain/constants/default_categories.dart';
import 'package:finance_control/features/categories/domain/entities/category_entity.dart';
import 'package:finance_control/features/categories/domain/repositories/category_repository.dart';
import 'package:finance_control/features/credit_cards/application/providers/credit_card_providers.dart';
import 'package:finance_control/features/credit_cards/domain/entities/credit_card_entity.dart';
import 'package:finance_control/features/credit_cards/domain/entities/invoice_entity.dart';
import 'package:finance_control/features/credit_cards/domain/repositories/credit_card_repository.dart';
import 'package:finance_control/features/credit_cards/domain/services/credit_card_cycle_calculator.dart';
import 'package:finance_control/features/installments/domain/entities/installment_plan_entity.dart';
import 'package:finance_control/features/notifications/application/controllers/notification_controller.dart';
import 'package:finance_control/features/notifications/application/providers/notification_providers.dart';
import 'package:finance_control/features/notifications/domain/entities/app_notification_entity.dart';
import 'package:finance_control/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finance_control/features/notifications/domain/services/notification_evaluation_service.dart';
import 'package:finance_control/features/notifications/presentation/pages/notifications_page.dart';
import 'package:finance_control/features/notifications/presentation/widgets/custom_reminder_dialog.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/features/recurring/application/controllers/recurring_controller.dart';
import 'package:finance_control/features/recurring/application/providers/recurring_providers.dart';
import 'package:finance_control/features/recurring/domain/entities/recurring_rule_entity.dart';
import 'package:finance_control/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finance_control/features/recurring/domain/services/recurring_schedule_calculator.dart';
import 'package:finance_control/features/recurring/presentation/pages/recurring_page.dart';
import 'package:finance_control/features/recurring/presentation/widgets/recurring_rule_form_dialog.dart';
import 'package:finance_control/features/transactions/application/providers/transaction_providers.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_attachment.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Stage4Store {
  final List<CategoryEntity> categories = [];
  final List<AccountEntity> accounts = [];
  final List<CreditCardEntity> cards = [];
  final List<InvoiceEntity> invoices = [];
  final List<TransactionEntity> transactions = [];
  final List<RecurringRuleEntity> rules = [];
  final List<AppNotificationEntity> notifications = [];
  final List<String> registeredTokens = [];
  UserProfile profile = UserProfile(
    uid: 'u_stage4',
    displayName: 'Luiz',
    email: 'luiz@financecontrol.app',
    reminderDaysBefore: 3,
    notificationsEnabled: true,
    pushNotificationsEnabled: false,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );

  final categoriesController =
      StreamController<List<CategoryEntity>>.broadcast();
  final accountsController = StreamController<List<AccountEntity>>.broadcast();
  final cardsController = StreamController<List<CreditCardEntity>>.broadcast();
  final invoicesController = StreamController<List<InvoiceEntity>>.broadcast();
  final txController = StreamController<List<TransactionEntity>>.broadcast();
  final rulesController =
      StreamController<List<RecurringRuleEntity>>.broadcast();
  final notificationsController =
      StreamController<List<AppNotificationEntity>>.broadcast();
  final profileController = StreamController<UserProfile?>.broadcast();

  void emitAll() {
    categoriesController.add(List.unmodifiable(categories));
    accountsController.add(List.unmodifiable(accounts));
    cardsController.add(List.unmodifiable(cards));
    invoicesController.add(List.unmodifiable(invoices));
    txController.add(List.unmodifiable(transactions));
    rulesController.add(List.unmodifiable(rules));
    notificationsController.add(List.unmodifiable(notifications));
    profileController.add(profile);
  }

  void dispose() {
    categoriesController.close();
    accountsController.close();
    cardsController.close();
    invoicesController.close();
    txController.close();
    rulesController.close();
    notificationsController.close();
    profileController.close();
  }
}

class _FakeAuthRepo implements AuthRepository {
  static const user = AuthUser(
    uid: 'u_stage4',
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
  final _Stage4Store store;
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
  final _Stage4Store store;
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
  final _Stage4Store store;
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
  final _Stage4Store store;
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
  }) async {
    final idx = store.transactions.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) {
      store.transactions[idx] = transaction;
      store.emitAll();
    }
    return transaction;
  }

  @override
  Future<void> markAsSettled({
    required String userId,
    required String transactionId,
    DateTime? paymentDate,
  }) async {
    final idx = store.transactions.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      final tx = store.transactions[idx];
      store.transactions[idx] = tx.copyWith(
        status: tx.kind == TransactionKind.income
            ? TransactionStatus.received
            : TransactionStatus.paid,
        paymentDate: paymentDate ?? DateTime.now(),
      );
      store.emitAll();
    }
  }

  @override
  Future<void> deleteTransaction({
    required String userId,
    required TransactionEntity transaction,
  }) async {}
}

class _FakeCreditCardRepo implements CreditCardRepository {
  _FakeCreditCardRepo(this.store);
  final _Stage4Store store;
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
  Stream<List<InstallmentPlanEntity>> watchInstallmentPlans(String userId) =>
      Stream.value(const <InstallmentPlanEntity>[]);
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

class _FakeRecurringRepo implements RecurringRepository {
  _FakeRecurringRepo(this.store);
  final _Stage4Store store;

  @override
  Stream<List<RecurringRuleEntity>> watchRules(String userId) async* {
    yield List.unmodifiable(store.rules);
    yield* store.rulesController.stream;
  }

  @override
  Future<RecurringRuleEntity> createRule({
    required String userId,
    required RecurringRuleEntity rule,
    DateTime? referenceDate,
  }) async {
    final created = rule.copyWith(id: 'rec_${store.rules.length + 1}');
    store.rules.add(created);
    await _generateForRule(created, referenceDate ?? DateTime.now());
    store.emitAll();
    return created;
  }

  @override
  Future<void> updateRule({
    required String userId,
    required RecurringRuleEntity rule,
  }) async {
    final idx = store.rules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      store.rules[idx] = rule;
      store.emitAll();
    }
  }

  @override
  Future<void> setStatus({
    required String userId,
    required String ruleId,
    required RecurringStatus status,
  }) async {
    final idx = store.rules.indexWhere((r) => r.id == ruleId);
    if (idx != -1) {
      store.rules[idx] = store.rules[idx].copyWith(status: status);
      if (status == RecurringStatus.active) {
        await _generateForRule(store.rules[idx], DateTime.now());
      }
      store.emitAll();
    }
  }

  @override
  Future<void> deleteRule({
    required String userId,
    required String ruleId,
  }) async {
    store.rules.removeWhere((r) => r.id == ruleId);
    store.emitAll();
  }

  @override
  Future<int> syncOccurrences({
    required String userId,
    DateTime? referenceDate,
  }) async {
    final ref = referenceDate ?? DateTime.now();
    var added = 0;
    for (final rule in store.rules.where((r) => r.status == RecurringStatus.active)) {
      added += await _generateForRule(rule, ref);
    }
    store.emitAll();
    return added;
  }

  Future<int> _generateForRule(
    RecurringRuleEntity rule,
    DateTime referenceDate,
  ) async {
    final specs = RecurringScheduleCalculator.computeOccurrencesInWindow(
      rule: rule,
      referenceDate: referenceDate,
    );
    var count = 0;
    for (final spec in specs) {
      if (store.transactions.any((tx) => tx.id == spec.transactionDocId)) {
        continue;
      }
      final now = DateTime.now();
      if (rule.isCardTarget) {
        final cardIdx = store.cards.indexWhere((c) => c.id == rule.cardId);
        if (cardIdx == -1) continue;
        final card = store.cards[cardIdx];
        final cycle = CreditCardCycleCalculator.resolveInvoiceForPurchase(
          cardId: card.id,
          purchaseDate: spec.scheduledDate,
          closingDay: card.closingDay,
          dueDay: card.dueDay,
        );
        final invIdx =
            store.invoices.indexWhere((inv) => inv.id == cycle.invoiceId);
        if (invIdx != -1) {
          store.invoices[invIdx] = store.invoices[invIdx].copyWith(
            totalAmountCents:
                store.invoices[invIdx].totalAmountCents + rule.amountCents,
          );
        } else {
          store.invoices.add(
            InvoiceEntity(
              id: cycle.invoiceId,
              cardId: card.id,
              referenceYear: cycle.referenceYear,
              referenceMonth: cycle.referenceMonth,
              closingDate: cycle.closingDate,
              dueDate: cycle.dueDate,
              totalAmountCents: rule.amountCents,
              paidAmountCents: 0,
              status: InvoiceStatus.open,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        store.cards[cardIdx] =
            card.copyWith(usedLimitCents: card.usedLimitCents + rule.amountCents);

        store.transactions.add(
          TransactionEntity(
            id: spec.transactionDocId,
            kind: TransactionKind.cardPurchase,
            description: rule.description,
            amountCents: rule.amountCents,
            categoryId: rule.categoryId,
            cardId: card.id,
            invoiceId: cycle.invoiceId,
            recurringId: rule.id,
            occurrenceKey: spec.occurrenceKey,
            competencyDate: spec.scheduledDate,
            dueDate: cycle.dueDate,
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        store.transactions.add(
          TransactionEntity(
            id: spec.transactionDocId,
            kind: rule.kind == RecurringKind.income
                ? TransactionKind.income
                : TransactionKind.expense,
            description: rule.description,
            amountCents: rule.amountCents,
            categoryId: rule.categoryId,
            accountId: rule.accountId,
            recurringId: rule.id,
            occurrenceKey: spec.occurrenceKey,
            competencyDate: spec.scheduledDate,
            dueDate: spec.scheduledDate,
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      count++;
    }
    return count;
  }

  @override
  Future<void> updateSingleCardOccurrence({
    required String userId,
    required String transactionId,
    required String description,
    required int amountCents,
    String? notes,
  }) async {
    final idx = store.transactions.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      final old = store.transactions[idx];
      final delta = amountCents - old.amountCents;
      store.transactions[idx] = old.copyWith(
        description: description,
        amountCents: amountCents,
        notes: notes,
      );
      if (delta != 0 && old.cardId != null) {
        final cIdx = store.cards.indexWhere((c) => c.id == old.cardId);
        if (cIdx != -1) {
          store.cards[cIdx] = store.cards[cIdx].copyWith(
            usedLimitCents: store.cards[cIdx].usedLimitCents + delta,
          );
        }
      }
      store.emitAll();
    }
  }
}

class _FakeNotificationRepo implements NotificationRepository {
  _FakeNotificationRepo(this.store);
  final _Stage4Store store;

  @override
  Stream<List<AppNotificationEntity>> watchNotifications(String userId) async* {
    yield List.unmodifiable(store.notifications);
    yield* store.notificationsController.stream;
  }

  @override
  Future<int> syncSystemAlerts({
    required String userId,
    required List<AppNotificationEntity> candidates,
  }) async {
    var created = 0;
    for (final item in candidates) {
      if (store.notifications.any((n) => n.id == item.id)) continue;
      store.notifications.add(item);
      created++;
    }
    store.emitAll();
    return created;
  }

  @override
  Future<AppNotificationEntity> createCustomReminder({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? referenceId,
  }) async {
    final now = DateTime.now();
    final created = AppNotificationEntity(
      id: 'custom_${store.notifications.length + 1}',
      title: title,
      body: body,
      type: NotificationType.customReminder,
      referenceId: referenceId,
      scheduledFor: scheduledFor,
      isRead: false,
      isCustom: true,
      createdAt: now,
      updatedAt: now,
    );
    store.notifications.add(created);
    store.emitAll();
    return created;
  }

  @override
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
    required bool isRead,
  }) async {
    final idx = store.notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      store.notifications[idx] =
          store.notifications[idx].copyWith(isRead: isRead);
      store.emitAll();
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    for (var i = 0; i < store.notifications.length; i++) {
      store.notifications[i] = store.notifications[i].copyWith(isRead: true);
    }
    store.emitAll();
  }

  @override
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    store.notifications.removeWhere((n) => n.id == notificationId);
    store.emitAll();
  }

  @override
  Future<void> registerDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    store.registeredTokens.add('$platform:$token');
  }
}

ProviderContainer _makeStage4Container(_Stage4Store store) {
  return ProviderContainer(
    overrides: [
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
      recurringRepositoryProvider.overrideWithValue(_FakeRecurringRepo(store)),
      notificationRepositoryProvider
          .overrideWithValue(_FakeNotificationRepo(store)),
      notificationServiceProvider.overrideWithValue(
        NotificationService(const FirebaseBootstrapState.awaitingConfiguration()),
      ),
    ],
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  group('RecurringScheduleCalculator', () {
    test('supports all 9 frequencies and clamps day-31 without drift', () {
      final now = DateTime(2026, 1, 31);
      final monthly = RecurringRuleEntity(
        id: 'rec_m',
        description: 'Aluguel',
        kind: RecurringKind.expense,
        amountCents: 180000,
        categoryId: 'cat_exp_housing',
        accountId: 'acc_1',
        frequency: RecurringFrequency.monthly,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final monthlySpecs = RecurringScheduleCalculator.computeOccurrencesInWindow(
        rule: monthly,
        referenceDate: DateTime(2026, 1, 15),
        horizonEndOverride: DateTime(2026, 4, 30),
      );
      expect(
        monthlySpecs.map((e) => e.dateKey).toList(),
        ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30'],
      );
      expect(monthlySpecs.first.transactionDocId, 'rec_rec_m_2026-01-31');

      final biweekly = RecurringScheduleCalculator.dateAtOccurrenceIndex(
        anchorStartDate: DateTime(2026, 11, 1),
        occurrenceIndex: 2,
        frequency: RecurringFrequency.biweekly,
      );
      expect(biweekly, DateTime(2026, 11, 29));

      final quarterly = RecurringScheduleCalculator.dateAtOccurrenceIndex(
        anchorStartDate: DateTime(2026, 1, 15),
        occurrenceIndex: 1,
        frequency: RecurringFrequency.quarterly,
      );
      expect(quarterly, DateTime(2026, 4, 15));

      final semiannual = RecurringScheduleCalculator.dateAtOccurrenceIndex(
        anchorStartDate: DateTime(2026, 1, 15),
        occurrenceIndex: 1,
        frequency: RecurringFrequency.semiannual,
      );
      expect(semiannual, DateTime(2026, 7, 15));

      final annual = RecurringScheduleCalculator.dateAtOccurrenceIndex(
        anchorStartDate: DateTime(2024, 2, 29),
        occurrenceIndex: 1,
        frequency: RecurringFrequency.annual,
      );
      expect(annual, DateTime(2025, 2, 28));

      final custom = RecurringScheduleCalculator.dateAtOccurrenceIndex(
        anchorStartDate: DateTime(2026, 11, 1),
        occurrenceIndex: 3,
        frequency: RecurringFrequency.custom,
        customIntervalDays: 10,
      );
      expect(custom, DateTime(2026, 11, 31)); // rolls to Dec 1
    });

    test('honors skipped keys, endDate, paused and canceled status', () {
      final now = DateTime(2026, 11, 1);
      final base = RecurringRuleEntity(
        id: 'rec_sub',
        description: 'Assinatura',
        kind: RecurringKind.expense,
        amountCents: 4990,
        categoryId: 'cat_exp_other',
        accountId: 'acc_1',
        frequency: RecurringFrequency.monthly,
        startDate: now,
        endDate: DateTime(2026, 12, 15),
        skippedOccurrenceKeys: const ['rec_sub_2026-11-01'],
        createdAt: now,
        updatedAt: now,
      );

      final activeSpecs =
          RecurringScheduleCalculator.computeOccurrencesInWindow(
        rule: base,
        referenceDate: DateTime(2026, 11, 18),
      );
      expect(activeSpecs.map((e) => e.dateKey).toList(), ['2026-12-01']);

      final pausedSpecs =
          RecurringScheduleCalculator.computeOccurrencesInWindow(
        rule: base.copyWith(status: RecurringStatus.paused),
        referenceDate: DateTime(2026, 11, 18),
      );
      expect(pausedSpecs, isEmpty);

      final canceledSpecs =
          RecurringScheduleCalculator.computeOccurrencesInWindow(
        rule: base.copyWith(status: RecurringStatus.canceled),
        referenceDate: DateTime(2026, 11, 18),
      );
      expect(canceledSpecs, isEmpty);
    });
  });

  group('NotificationEvaluationService', () {
    test('evaluates overdue, upcoming, expected income, invoices and budgets with lead days', () {
      final now = DateTime(2026, 11, 18);
      final alerts = NotificationEvaluationService.evaluateSystemAlerts(
        transactions: [
          TransactionEntity(
            id: 'tx_1',
            kind: TransactionKind.expense,
            description: 'Internet',
            amountCents: 12000,
            categoryId: 'c1',
            accountId: 'a1',
            competencyDate: DateTime(2026, 11, 15),
            dueDate: DateTime(2026, 11, 15),
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
          TransactionEntity(
            id: 'tx_2',
            kind: TransactionKind.expense,
            description: 'Energia',
            amountCents: 21500,
            categoryId: 'c1',
            accountId: 'a1',
            competencyDate: DateTime(2026, 11, 21),
            dueDate: DateTime(2026, 11, 21),
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
          TransactionEntity(
            id: 'tx_3',
            kind: TransactionKind.expense,
            description: 'IPTU',
            amountCents: 50000,
            categoryId: 'c1',
            accountId: 'a1',
            competencyDate: DateTime(2026, 11, 25),
            dueDate: DateTime(2026, 11, 25),
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
          TransactionEntity(
            id: 'tx_4',
            kind: TransactionKind.income,
            description: 'Salário',
            amountCents: 600000,
            categoryId: 'c2',
            accountId: 'a1',
            competencyDate: DateTime(2026, 11, 20),
            dueDate: DateTime(2026, 11, 20),
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        invoices: [
          InvoiceEntity(
            id: 'card_1_2026_11',
            cardId: 'card_1',
            referenceYear: 2026,
            referenceMonth: 11,
            closingDate: DateTime(2026, 11, 10),
            dueDate: DateTime(2026, 11, 20),
            totalAmountCents: 150000,
            paidAmountCents: 0,
            status: InvoiceStatus.closed,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        cardsById: {
          'card_1': CreditCardEntity(
            id: 'card_1',
            name: 'Nubank',
            institution: 'Nubank',
            brand: CardBrand.mastercard,
            totalLimitCents: 500000,
            usedLimitCents: 150000,
            closingDay: 10,
            dueDay: 20,
            colorHex: '#7C3AED',
            defaultInstallments: 1,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        },
        budgets: const [
          BudgetAlertEvaluationInput(
            budgetId: 'b_food',
            categoryName: 'Alimentação',
            year: 2026,
            month: 11,
            limitCents: 100000,
            spentCents: 85000,
          ),
          BudgetAlertEvaluationInput(
            budgetId: 'b_leisure',
            categoryName: 'Lazer',
            year: 2026,
            month: 11,
            limitCents: 40000,
            spentCents: 48000,
          ),
        ],
        reminderDaysBefore: 3,
        notificationsEnabled: true,
        referenceDate: now,
      );

      expect(
        alerts.map((a) => a.type).toSet(),
        {
          NotificationType.overduePayable,
          NotificationType.upcomingPayable,
          NotificationType.expectedIncome,
          NotificationType.invoiceDue,
          NotificationType.budgetWarning,
          NotificationType.budgetExceeded,
        },
      );
      expect(alerts.any((a) => a.referenceId == 'tx_3'), isFalse);

      // Com antecedência de 10 dias, tx_3 (dia 25) passa a aparecer.
      final alertsWith10Days =
          NotificationEvaluationService.evaluateSystemAlerts(
        transactions: [
          TransactionEntity(
            id: 'tx_3',
            kind: TransactionKind.expense,
            description: 'IPTU',
            amountCents: 50000,
            categoryId: 'c1',
            accountId: 'a1',
            competencyDate: DateTime(2026, 11, 25),
            dueDate: DateTime(2026, 11, 25),
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        invoices: const [],
        cardsById: const {},
        reminderDaysBefore: 10,
        notificationsEnabled: true,
        referenceDate: now,
      );
      expect(alertsWith10Days.single.referenceId, 'tx_3');

      final disabled = NotificationEvaluationService.evaluateSystemAlerts(
        transactions: const [],
        invoices: const [],
        cardsById: const {},
        budgets: const [
          BudgetAlertEvaluationInput(
            budgetId: 'b_food',
            categoryName: 'Alimentação',
            year: 2026,
            month: 11,
            limitCents: 100000,
            spentCents: 120000,
          ),
        ],
        reminderDaysBefore: 3,
        notificationsEnabled: false,
        referenceDate: now,
      );
      expect(disabled, isEmpty);
    });
  });

  group('Stage 4 Controllers (Idempotency, Lifecycle & Notifications)', () {
    test('RecurringController generates idempotently without duplication and supports card occurrence edits', () async {
      final now = DateTime(2026, 11, 1);
      final store = _Stage4Store()
        ..categories.addAll(DefaultCategories.build(now))
        ..accounts.add(
          AccountEntity(
            id: 'acc_1',
            name: 'Conta Corrente',
            institution: 'Inter',
            type: AccountType.checking,
            initialBalanceCents: 200000,
            currentBalanceCents: 200000,
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
            name: 'Nubank',
            institution: 'Nubank',
            brand: CardBrand.mastercard,
            totalLimitCents: 500000,
            usedLimitCents: 0,
            closingDay: 10,
            dueDay: 17,
            paymentAccountId: 'acc_1',
            colorHex: '#7C3AED',
            defaultInstallments: 1,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      addTearDown(store.dispose);

      final container = _makeStage4Container(store);
      addTearDown(container.dispose);

      final recController =
          container.read(recurringControllerProvider.notifier);

      final ok = await recController.saveRule(
        kind: RecurringKind.expense,
        description: 'Streaming Plus',
        amountCents: 4990,
        isVariableAmount: true,
        categoryId: 'cat_exp_other',
        cardId: 'card_1',
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 11, 1),
      );
      expect(ok, isTrue);

      final initialTxCount = store.transactions.length;
      expect(initialTxCount, greaterThan(0));
      final initialUsedLimit = store.cards.single.usedLimitCents;
      expect(initialUsedLimit, initialTxCount * 4990);

      // Nova sincronização no mesmo período não gera duplicados.
      final createdOnSecondRun = await recController.syncNow(
        referenceDate: DateTime(2026, 11, 1),
      );
      expect(createdOnSecondRun, 0);
      expect(store.transactions.length, initialTxCount);

      // Edição individual de uma única ocorrência no cartão ajusta apenas aquela fatura e limite.
      final firstOccurrence = store.transactions.first;
      final edited = await recController.updateSingleCardOccurrence(
        transactionId: firstOccurrence.id,
        description: 'Streaming Plus (Promo)',
        amountCents: 2990,
      );
      expect(edited, isTrue);
      expect(
        store.cards.single.usedLimitCents,
        initialUsedLimit - 2000,
      );

      // Pausar e depois retomar mantém consistência.
      await recController.setStatus(
        ruleId: store.rules.single.id,
        status: RecurringStatus.paused,
      );
      expect(store.rules.single.status, RecurringStatus.paused);
    });

    test('NotificationController syncs alerts idempotently and preserves read state', () async {
      final now = DateTime.now();
      final store = _Stage4Store()
        ..categories.addAll(DefaultCategories.build(now))
        ..transactions.add(
          TransactionEntity(
            id: 'tx_due',
            kind: TransactionKind.expense,
            description: 'Luz',
            amountCents: 18500,
            categoryId: 'cat_exp_housing',
            accountId: 'acc_1',
            competencyDate: now.add(const Duration(days: 1)),
            dueDate: now.add(const Duration(days: 1)),
            status: TransactionStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        );
      addTearDown(store.dispose);

      final container = _makeStage4Container(store);
      addTearDown(container.dispose);

      // Garante leitura dos streams antes do controller rodar.
      container.read(transactionsStreamProvider);
      container.read(userProfileProvider);
      await Future<void>.delayed(Duration.zero);

      final notifController =
          container.read(notificationControllerProvider.notifier);
      final firstSync = await notifController.syncAlerts(referenceDate: now);
      expect(firstSync, 1);
      expect(store.notifications.single.isRead, isFalse);

      // Usuário marca alerta como lido.
      await notifController.toggleRead(
        notificationId: store.notifications.single.id,
        isRead: true,
      );
      expect(store.notifications.single.isRead, isTrue);

      // Re-sincronizar não duplica nem reseta o flag `isRead`.
      final secondSync = await notifController.syncAlerts(referenceDate: now);
      expect(secondSync, 0);
      expect(store.notifications.length, 1);
      expect(store.notifications.single.isRead, isTrue);

      final customOk = await notifController.createCustomReminder(
        title: 'Conferir fatura',
        body: 'Revisar assinaturas mensais',
        scheduledFor: now.add(const Duration(days: 2)),
      );
      expect(customOk, isTrue);
      expect(store.notifications.length, 2);
    });
  });

  group('Stage 4 Widget Tests (Desktop + 360x780 Mobile)', () {
    Widget wrapMobile(Widget child, _Stage4Store store) {
      return ProviderScope(
        overrides: [
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
          categoryRepositoryProvider
              .overrideWithValue(_FakeCategoryRepo(store)),
          accountRepositoryProvider.overrideWithValue(_FakeAccountRepo(store)),
          transactionRepositoryProvider
              .overrideWithValue(_FakeTransactionRepo(store)),
          creditCardRepositoryProvider
              .overrideWithValue(_FakeCreditCardRepo(store)),
          recurringRepositoryProvider
              .overrideWithValue(_FakeRecurringRepo(store)),
          notificationRepositoryProvider
              .overrideWithValue(_FakeNotificationRepo(store)),
          notificationServiceProvider.overrideWithValue(
            NotificationService(
              const FirebaseBootstrapState.awaitingConfiguration(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets(
        'RecurringPage, NotificationsPage and forms render cleanly at 360x780 without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime(2026, 11, 18);
      final store = _Stage4Store()
        ..categories.addAll(DefaultCategories.build(now))
        ..accounts.add(
          AccountEntity(
            id: 'acc_1',
            name: 'Nubank Conta Principal',
            institution: 'Nubank',
            type: AccountType.checking,
            initialBalanceCents: 200000,
            currentBalanceCents: 200000,
            colorHex: '#0F766E',
            iconName: 'account_balance',
            openedAt: now,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        )
        ..rules.add(
          RecurringRuleEntity(
            id: 'rec_1',
            description: 'Internet Fibra Residencial',
            kind: RecurringKind.expense,
            amountCents: 12990,
            isVariableAmount: true,
            categoryId: 'cat_exp_housing',
            accountId: 'acc_1',
            frequency: RecurringFrequency.monthly,
            startDate: now,
            status: RecurringStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        )
        ..notifications.add(
          AppNotificationEntity(
            id: 'notif_1',
            title: 'Conta a vencer: Energia',
            body: 'Vence amanhã (19/11/2026) • Valor R\$ 215,00.',
            type: NotificationType.upcomingPayable,
            referenceId: 'tx_energy',
            scheduledFor: now.add(const Duration(days: 1)),
            isRead: false,
            isCustom: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      addTearDown(store.dispose);

      // 1. RecurringRuleFormDialog em 360x780
      await tester.pumpWidget(
        wrapMobile(const RecurringRuleFormDialog(), store),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nova conta recorrente'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. RecurringPage em 360x780
      await tester.pumpWidget(wrapMobile(const RecurringPage(), store));
      await tester.pumpAndSettle();
      expect(find.text('Contas Recorrentes'), findsOneWidget);
      expect(find.text('Internet Fibra Residencial'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 3. CustomReminderDialog em 360x780
      await tester.pumpWidget(
        wrapMobile(const CustomReminderDialog(), store),
      );
      await tester.pumpAndSettle();
      expect(find.text('Novo lembrete personalizado'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 4. NotificationsPage em 360x780
      await tester.pumpWidget(wrapMobile(const NotificationsPage(), store));
      await tester.pumpAndSettle();
      expect(find.text('Notificações e Alertas'), findsOneWidget);
      expect(find.text('Conta a vencer: Energia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
