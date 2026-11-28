import 'dart:async';
import 'dart:convert';
import 'package:finance_control/core/services/attachment_storage_service.dart';
import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/core/services/local_storage_service.dart';
import 'package:finance_control/core/services/notification_service.dart';
import 'package:finance_control/core/theme/app_theme.dart';
import 'package:finance_control/features/accounts/application/controllers/account_controller.dart';
import 'package:finance_control/features/accounts/application/providers/account_providers.dart';
import 'package:finance_control/features/accounts/domain/entities/account_entity.dart';
import 'package:finance_control/features/accounts/domain/repositories/account_repository.dart';
import 'package:finance_control/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:finance_control/features/accounts/presentation/pages/account_statement_page.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/budgets/application/controllers/budget_controller.dart';
import 'package:finance_control/features/budgets/application/providers/budget_providers.dart';
import 'package:finance_control/features/budgets/domain/entities/budget_entity.dart';
import 'package:finance_control/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finance_control/features/categories/application/providers/category_providers.dart';
import 'package:finance_control/features/categories/domain/constants/default_categories.dart';
import 'package:finance_control/features/categories/domain/entities/category_entity.dart';
import 'package:finance_control/features/categories/domain/repositories/category_repository.dart';
import 'package:finance_control/features/credit_cards/application/controllers/credit_card_controller.dart';
import 'package:finance_control/features/credit_cards/application/providers/credit_card_providers.dart';
import 'package:finance_control/features/credit_cards/domain/entities/credit_card_entity.dart';
import 'package:finance_control/features/credit_cards/domain/entities/invoice_entity.dart';
import 'package:finance_control/features/credit_cards/domain/repositories/credit_card_repository.dart';
import 'package:finance_control/features/credit_cards/domain/services/credit_card_cycle_calculator.dart';
import 'package:finance_control/features/credit_cards/presentation/widgets/card_purchase_form_dialog.dart';
import 'package:finance_control/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:finance_control/features/installments/domain/entities/installment_plan_entity.dart';
import 'package:finance_control/features/notifications/application/providers/notification_providers.dart';
import 'package:finance_control/features/notifications/domain/entities/app_notification_entity.dart';
import 'package:finance_control/features/notifications/domain/repositories/notification_repository.dart';
import 'package:finance_control/features/profile/application/controllers/profile_controller.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/features/recurring/application/controllers/recurring_controller.dart';
import 'package:finance_control/features/recurring/application/providers/recurring_providers.dart';
import 'package:finance_control/features/recurring/domain/entities/recurring_rule_entity.dart';
import 'package:finance_control/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finance_control/features/recurring/domain/services/recurring_schedule_calculator.dart';
import 'package:finance_control/features/reports/domain/services/financial_analytics_service.dart';
import 'package:finance_control/features/reports/domain/services/report_export_service.dart';
import 'package:finance_control/features/settings/presentation/pages/settings_page.dart';
import 'package:finance_control/features/transactions/application/controllers/transaction_controller.dart';
import 'package:finance_control/features/transactions/application/providers/transaction_providers.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finance_control/shared/models/date_period.dart';
import 'package:finance_control/shared/models/money.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:finance_control/shared/widgets/app_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _EndToEndStore {
  final List<CategoryEntity> categories = [];
  final List<AccountEntity> accounts = [];
  final List<CreditCardEntity> cards = [];
  final List<InvoiceEntity> invoices = [];
  final List<InstallmentPlanEntity> plans = [];
  final List<TransactionEntity> transactions = [];
  final List<RecurringRuleEntity> rules = [];
  final List<BudgetEntity> budgets = [];
  final List<AppNotificationEntity> notifications = [];
  final List<String> auditLog = [];

  UserProfile profile = UserProfile(
    uid: 'uid_e2e',
    displayName: 'Luiz Magno',
    email: 'luiz@financecontrol.app',
    monthStartDay: 1,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );

  final categoriesCtrl = StreamController<List<CategoryEntity>>.broadcast();
  final accountsCtrl = StreamController<List<AccountEntity>>.broadcast();
  final cardsCtrl = StreamController<List<CreditCardEntity>>.broadcast();
  final invoicesCtrl = StreamController<List<InvoiceEntity>>.broadcast();
  final plansCtrl = StreamController<List<InstallmentPlanEntity>>.broadcast();
  final txCtrl = StreamController<List<TransactionEntity>>.broadcast();
  final rulesCtrl = StreamController<List<RecurringRuleEntity>>.broadcast();
  final budgetsCtrl = StreamController<List<BudgetEntity>>.broadcast();
  final notificationsCtrl =
      StreamController<List<AppNotificationEntity>>.broadcast();
  final profileCtrl = StreamController<UserProfile?>.broadcast();

  void emitAll() {
    categoriesCtrl.add(List.unmodifiable(categories));
    accountsCtrl.add(List.unmodifiable(accounts));
    cardsCtrl.add(List.unmodifiable(cards));
    invoicesCtrl.add(List.unmodifiable(invoices));
    plansCtrl.add(List.unmodifiable(plans));
    txCtrl.add(List.unmodifiable(transactions));
    rulesCtrl.add(List.unmodifiable(rules));
    budgetsCtrl.add(List.unmodifiable(budgets));
    notificationsCtrl.add(List.unmodifiable(notifications));
    profileCtrl.add(profile);
  }

  void dispose() {
    categoriesCtrl.close();
    accountsCtrl.close();
    cardsCtrl.close();
    invoicesCtrl.close();
    plansCtrl.close();
    txCtrl.close();
    rulesCtrl.close();
    budgetsCtrl.close();
    notificationsCtrl.close();
    profileCtrl.close();
  }
}

class _E2eAuthRepo implements AuthRepository {
  _E2eAuthRepo(this.store);
  final _EndToEndStore store;
  AuthUser? _current = const AuthUser(
    uid: 'uid_e2e',
    email: 'luiz@financecontrol.app',
    displayName: 'Luiz Magno',
    providerIds: ['password'],
  );

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_current);

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<void> deleteCurrentAuthUser() async {
    store.auditLog.add('deleteCurrentAuthUser');
    _current = null;
  }

  @override
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    store.auditLog.add('reauthenticateWithPassword');
  }

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _E2eProfileRepo implements ProfileRepository {
  _E2eProfileRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield store.profile;
    yield* store.profileCtrl.stream;
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
  Future<void> deleteUserData(String uid) async {
    store.auditLog.add('deleteUserData:$uid');
    store.accounts.clear();
    store.cards.clear();
    store.invoices.clear();
    store.plans.clear();
    store.transactions.clear();
    store.rules.clear();
    store.budgets.clear();
    store.notifications.clear();
    store.emitAll();
  }
}

class _E2eCategoryRepo implements CategoryRepository {
  _E2eCategoryRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<List<CategoryEntity>> watchCategories(String userId) async* {
    yield List.unmodifiable(store.categories);
    yield* store.categoriesCtrl.stream;
  }

  @override
  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _E2eAccountRepo implements AccountRepository {
  _E2eAccountRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<List<AccountEntity>> watchAccounts(String userId) async* {
    yield List.unmodifiable(store.accounts);
    yield* store.accountsCtrl.stream;
  }

  @override
  Future<AccountEntity> createAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    final created = account.copyWith(id: 'acc_${store.accounts.length + 1}');
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
    final now = DateTime.now();
    final groupId = 'tr_${store.transactions.length + 1}';

    store.accounts[srcIdx] = store.accounts[srcIdx].copyWith(
      currentBalanceCents:
          store.accounts[srcIdx].currentBalanceCents - amountCents,
    );
    store.accounts[dstIdx] = store.accounts[dstIdx].copyWith(
      currentBalanceCents:
          store.accounts[dstIdx].currentBalanceCents + amountCents,
    );

    store.transactions.addAll([
      TransactionEntity(
        id: 'tx_${store.transactions.length + 1}',
        kind: TransactionKind.transfer,
        description: '$description (saída)',
        amountCents: amountCents,
        accountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        transferGroupId: groupId,
        transferDirection: TransferDirection.outflow,
        competencyDate: transferDate,
        paymentDate: transferDate,
        status: TransactionStatus.completed,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 'tx_${store.transactions.length + 2}',
        kind: TransactionKind.transfer,
        description: '$description (entrada)',
        amountCents: amountCents,
        accountId: destinationAccountId,
        destinationAccountId: sourceAccountId,
        transferGroupId: groupId,
        transferDirection: TransferDirection.inflow,
        competencyDate: transferDate,
        paymentDate: transferDate,
        status: TransactionStatus.completed,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    store.emitAll();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _E2eTransactionRepo implements TransactionRepository {
  _E2eTransactionRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<List<TransactionEntity>> watchTransactions(String userId) async* {
    yield List.unmodifiable(store.transactions);
    yield* store.txCtrl.stream;
  }

  @override
  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  }) async {
    final created =
        transaction.copyWith(id: 'tx_${store.transactions.length + 1}');
    store.transactions.add(created);

    if (created.status.isSettled && created.accountId != null) {
      final accIdx =
          store.accounts.indexWhere((a) => a.id == created.accountId);
      if (accIdx != -1) {
        final signedDelta =
            created.signedBalanceDeltaForAccount(created.accountId!);
        store.accounts[accIdx] = store.accounts[accIdx].copyWith(
          currentBalanceCents:
              store.accounts[accIdx].currentBalanceCents + signedDelta,
        );
      }
    }

    store.emitAll();
    return created;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _E2eCreditCardRepo implements CreditCardRepository {
  _E2eCreditCardRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<List<CreditCardEntity>> watchCards(String userId) async* {
    yield List.unmodifiable(store.cards);
    yield* store.cardsCtrl.stream;
  }

  @override
  Stream<List<InvoiceEntity>> watchInvoices(String userId) async* {
    yield List.unmodifiable(store.invoices);
    yield* store.invoicesCtrl.stream;
  }

  @override
  Stream<List<InstallmentPlanEntity>> watchInstallmentPlans(
    String userId,
  ) async* {
    yield List.unmodifiable(store.plans);
    yield* store.plansCtrl.stream;
  }

  @override
  Future<CreditCardEntity> createCard({
    required String userId,
    required CreditCardEntity card,
  }) async {
    final created = card.copyWith(id: 'card_${store.cards.length + 1}');
    store.cards.add(created);
    store.emitAll();
    return created;
  }

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
  }) async {
    final cardIdx = store.cards.indexWhere((c) => c.id == cardId);
    final card = store.cards[cardIdx];
    final now = DateTime.now();
    final slices = CreditCardCycleCalculator.buildCardInstallmentSchedule(
      cardId: cardId,
      totalAmountCents: totalAmountCents,
      installmentCount: installmentCount,
      purchaseDate: purchaseDate,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
    );

    final planId = 'plan_${store.plans.length + 1}';
    if (installmentCount > 1) {
      store.plans.add(
        InstallmentPlanEntity(
          id: planId,
          description: description,
          totalAmountCents: totalAmountCents,
          installmentCount: installmentCount,
          firstCompetencyDate: slices.first.competencyDate,
          firstDueDate: slices.first.dueDate,
          cardId: cardId,
          categoryId: categoryId,
          status: InstallmentPlanStatus.active,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    for (final slice in slices) {
      final target = slice.invoiceTarget!;
      final invIdx =
          store.invoices.indexWhere((i) => i.id == target.invoiceId);
      if (invIdx == -1) {
        store.invoices.add(
          InvoiceEntity(
            id: target.invoiceId,
            cardId: cardId,
            referenceYear: target.referenceYear,
            referenceMonth: target.referenceMonth,
            closingDate: target.closingDate,
            dueDate: target.dueDate,
            totalAmountCents: slice.amountCents,
            paidAmountCents: 0,
            status: InvoiceStatus.open,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        store.invoices[invIdx] = store.invoices[invIdx].copyWith(
          totalAmountCents:
              store.invoices[invIdx].totalAmountCents + slice.amountCents,
        );
      }

      store.transactions.add(
        TransactionEntity(
          id: 'tx_${store.transactions.length + 1}',
          kind: TransactionKind.cardPurchase,
          description: installmentCount > 1
              ? '$description (${slice.installmentNumber}/$installmentCount)'
              : description,
          amountCents: slice.amountCents,
          categoryId: categoryId,
          cardId: cardId,
          invoiceId: target.invoiceId,
          installmentPlanId: installmentCount > 1 ? planId : null,
          installmentNumber: installmentCount > 1 ? slice.installmentNumber : null,
          totalInstallments: installmentCount > 1 ? installmentCount : null,
          competencyDate: slice.competencyDate,
          dueDate: slice.dueDate,
          status: TransactionStatus.pending,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    store.cards[cardIdx] = card.copyWith(
      usedLimitCents: CreditCardCycleCalculator.calculateUsedLimitFromInvoices(
        store.invoices,
        cardId: cardId,
      ),
    );
    store.emitAll();
  }

  @override
  Future<void> payInvoice({
    required String userId,
    required String invoiceId,
    required String paymentAccountId,
    required DateTime paymentDate,
  }) async {
    final invIdx = store.invoices.indexWhere((i) => i.id == invoiceId);
    final inv = store.invoices[invIdx];
    final remaining = inv.remainingAmountCents;
    final accIdx = store.accounts.indexWhere((a) => a.id == paymentAccountId);
    final now = DateTime.now();

    store.accounts[accIdx] = store.accounts[accIdx].copyWith(
      currentBalanceCents:
          store.accounts[accIdx].currentBalanceCents - remaining,
    );

    final paymentTxId = 'tx_${store.transactions.length + 1}';
    store.transactions.add(
      TransactionEntity(
        id: paymentTxId,
        kind: TransactionKind.invoicePayment,
        description: 'Pagamento de fatura $invoiceId',
        amountCents: remaining,
        accountId: paymentAccountId,
        cardId: inv.cardId,
        invoiceId: invoiceId,
        competencyDate: paymentDate,
        paymentDate: paymentDate,
        status: TransactionStatus.paid,
        createdAt: now,
        updatedAt: now,
      ),
    );

    for (var i = 0; i < store.transactions.length; i++) {
      final tx = store.transactions[i];
      if (tx.invoiceId == invoiceId &&
          tx.kind == TransactionKind.cardPurchase) {
        store.transactions[i] = tx.copyWith(
          status: TransactionStatus.paid,
          paymentDate: paymentDate,
        );
      }
    }

    store.invoices[invIdx] = inv.copyWith(
      paidAmountCents: inv.totalAmountCents,
      status: InvoiceStatus.paid,
      paymentTransactionId: paymentTxId,
      paidAt: paymentDate,
    );

    final cardIdx = store.cards.indexWhere((c) => c.id == inv.cardId);
    store.cards[cardIdx] = store.cards[cardIdx].copyWith(
      usedLimitCents: CreditCardCycleCalculator.calculateUsedLimitFromInvoices(
        store.invoices,
        cardId: inv.cardId,
      ),
    );
    store.emitAll();
  }

  @override
  Future<void> refundOrCancelCardPurchase({
    required String userId,
    required String transactionId,
    bool cancelAllPlanInstallments = true,
  }) async {
    final txIdx = store.transactions.indexWhere((t) => t.id == transactionId);
    final targetTx = store.transactions[txIdx];
    final invIdx =
        store.invoices.indexWhere((i) => i.id == targetTx.invoiceId);
    if (invIdx != -1) {
      final currentInv = store.invoices[invIdx];
      store.invoices[invIdx] = currentInv.copyWith(
        totalAmountCents:
            (currentInv.totalAmountCents - targetTx.amountCents).clamp(0, 1 << 60),
      );
    }
    store.transactions.removeAt(txIdx);
    if (targetTx.cardId != null) {
      final cardIdx = store.cards.indexWhere((c) => c.id == targetTx.cardId);
      store.cards[cardIdx] = store.cards[cardIdx].copyWith(
        usedLimitCents:
            CreditCardCycleCalculator.calculateUsedLimitFromInvoices(
          store.invoices,
          cardId: targetTx.cardId,
        ),
      );
    }
    store.emitAll();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _E2eRecurringRepo implements RecurringRepository {
  _E2eRecurringRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<List<RecurringRuleEntity>> watchRules(String userId) async* {
    yield List.unmodifiable(store.rules);
    yield* store.rulesCtrl.stream;
  }

  @override
  Future<RecurringRuleEntity> createRule({
    required String userId,
    required RecurringRuleEntity rule,
    DateTime? referenceDate,
  }) async {
    final created = rule.copyWith(id: 'rec_${store.rules.length + 1}');
    store.rules.add(created);
    await syncOccurrences(userId: userId, referenceDate: referenceDate);
    return created;
  }

  @override
  Future<int> syncOccurrences({
    required String userId,
    DateTime? referenceDate,
  }) async {
    var added = 0;
    final refDate = referenceDate ?? DateTime.now();
    for (final rule in store.rules) {
      if (rule.status != RecurringStatus.active) continue;
      final specs = RecurringScheduleCalculator.computeOccurrencesInWindow(
        rule: rule,
        referenceDate: refDate,
      );
      for (final spec in specs) {
        final alreadyExists = store.transactions
            .any((t) => t.id == spec.transactionDocId);
        if (alreadyExists) continue;
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
            competencyDate: spec.scheduledDate,
            dueDate: spec.scheduledDate,
            status: TransactionStatus.pending,
            recurringId: rule.id,
            occurrenceKey: spec.occurrenceKey,
            createdAt: refDate,
            updatedAt: refDate,
          ),
        );
        added++;
      }
    }
    store.emitAll();
    return added;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _E2eBudgetRepo implements BudgetRepository {
  _E2eBudgetRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<List<BudgetEntity>> watchBudgets(String userId) async* {
    yield List.unmodifiable(store.budgets);
    yield* store.budgetsCtrl.stream;
  }

  @override
  Future<BudgetEntity> upsertBudget({
    required String userId,
    required BudgetEntity budget,
  }) async {
    final idx = store.budgets.indexWhere((b) => b.id == budget.id);
    if (idx == -1) {
      store.budgets.add(budget);
    } else {
      store.budgets[idx] = budget;
    }
    store.emitAll();
    return budget;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _E2eNotificationRepo implements NotificationRepository {
  _E2eNotificationRepo(this.store);
  final _EndToEndStore store;

  @override
  Stream<List<AppNotificationEntity>> watchNotifications(String userId) async* {
    yield List.unmodifiable(store.notifications);
    yield* store.notificationsCtrl.stream;
  }

  @override
  Future<int> syncSystemAlerts({
    required String userId,
    required List<AppNotificationEntity> candidates,
  }) async =>
      0;

  @override
  Future<void> registerDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _e2eOverrides(
  _EndToEndStore store,
  _E2eAuthRepo authRepo, {
  FirebaseBootstrapState? bootstrapState,
}) {
  final effectiveFirebase = bootstrapState ??
      const FirebaseBootstrapState(
        status: FirebaseConnectionStatus.connected,
        message: 'Firebase conectado (Android).',
        projectId: 'finance-control-luizmgms',
        appCheckActive: true,
        appCheckStatusLabel: 'App Check ativo (Play Integrity)',
      );
  return [
    localStorageServiceProvider.overrideWithValue(LocalStorageService()),
    appBootstrapStateProvider.overrideWithValue(
      AppBootstrapState(
        firebase: effectiveFirebase,
        localStorageInitialized: true,
      ),
    ),
    authRepositoryProvider.overrideWithValue(authRepo),
    currentAuthUserProvider.overrideWithValue(authRepo.currentUser),
    profileRepositoryProvider.overrideWithValue(_E2eProfileRepo(store)),
    categoryRepositoryProvider.overrideWithValue(_E2eCategoryRepo(store)),
    accountRepositoryProvider.overrideWithValue(_E2eAccountRepo(store)),
    transactionRepositoryProvider
        .overrideWithValue(_E2eTransactionRepo(store)),
    creditCardRepositoryProvider.overrideWithValue(_E2eCreditCardRepo(store)),
    recurringRepositoryProvider.overrideWithValue(_E2eRecurringRepo(store)),
    budgetRepositoryProvider.overrideWithValue(_E2eBudgetRepo(store)),
    notificationRepositoryProvider
        .overrideWithValue(_E2eNotificationRepo(store)),
    notificationServiceProvider.overrideWithValue(
      NotificationService(const FirebaseBootstrapState.awaitingConfiguration()),
    ),
  ];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  group('Etapa 7 — Fluxos Integrados End-to-End (Regras Críticas + LGPD)', () {
    test(
        'executa jornada completa: contas, receita/despesa, transferência sem contagem dupla, compra parcelada 100,00 em 3x, pagamento de fatura, recorrência idempotente, orçamento, relatórios PDF/CSV e exclusão de conta',
        () async {
      final now = DateTime.now();
      final store = _EndToEndStore()
        ..categories.addAll(DefaultCategories.build(now));
      final authRepo = _E2eAuthRepo(store);
      addTearDown(store.dispose);

      final container = ProviderContainer(
        overrides: _e2eOverrides(store, authRepo),
      );
      addTearDown(container.dispose);

      // 1. Criação de 2 contas financeiras.
      final accountCtrl = container.read(accountControllerProvider.notifier);
      expect(
        await accountCtrl.saveAccount(
          name: 'Conta Corrente',
          institution: 'Nubank',
          type: AccountType.checking,
          initialBalanceCents: 100000, // R$ 1.000,00
          colorHex: '#0F766E',
          iconName: 'account_balance',
          openedAt: now,
        ),
        isTrue,
      );
      expect(
        await accountCtrl.saveAccount(
          name: 'Reserva',
          institution: 'Inter',
          type: AccountType.savings,
          initialBalanceCents: 20000, // R$ 200,00
          colorHex: '#2563EB',
          iconName: 'savings',
          openedAt: now,
        ),
        isTrue,
      );
      expect(store.accounts.length, 2);

      // 2. Receita + Despesa + Transferência entre contas.
      final txCtrl = container.read(transactionControllerProvider.notifier);
      expect(
        await txCtrl.saveTransaction(
          kind: TransactionKind.income,
          description: 'Freela App',
          amountCents: 500000, // R$ 5.000,00
          categoryId: 'cat_inc_freelance',
          accountId: 'acc_1',
          competencyDate: now,
          status: TransactionStatus.received,
        ),
        isTrue,
      );
      expect(
        await txCtrl.saveTransaction(
          kind: TransactionKind.expense,
          description: 'Supermercado',
          amountCents: 120000, // R$ 1.200,00
          categoryId: 'cat_exp_food',
          accountId: 'acc_1',
          competencyDate: now,
          status: TransactionStatus.paid,
        ),
        isTrue,
      );
      expect(
        await accountCtrl.transferBetweenAccounts(
          sourceAccountId: 'acc_1',
          destinationAccountId: 'acc_2',
          amountCents: 80000, // R$ 800,00
          transferDate: now,
          description: 'Aporte Reserva',
        ),
        isTrue,
      );

      expect(store.accounts[0].currentBalanceCents, 400000);
      expect(store.accounts[1].currentBalanceCents, 100000);
      expect(
        AccountBalanceCalculator.calculateBalance(
          accountId: 'acc_1',
          initialBalanceCents: store.accounts[0].initialBalanceCents,
          transactions: store.transactions,
        ),
        400000,
      );

      // 3. Cartão de crédito, compra parcelada R$ 100,00 em 3x [3334, 3333, 3333], pagamento da fatura e estorno.
      final cardCtrl = container.read(creditCardControllerProvider.notifier);
      expect(
        await cardCtrl.saveCard(
          name: 'Nubank Ultravioleta',
          institution: 'Nubank',
          brand: CardBrand.mastercard,
          totalLimitCents: 1000000,
          closingDay: 25,
          dueDay: 5,
          paymentAccountId: 'acc_1',
          colorHex: '#7C3AED',
        ),
        isTrue,
      );
      expect(
        await cardCtrl.recordCardPurchase(
          cardId: 'card_1',
          categoryId: 'cat_exp_shopping',
          description: 'Teclado Mecânico',
          totalAmountCents: 10000, // R$ 100,00
          purchaseDate: DateTime(now.year, now.month, 10),
          totalInstallments: 3,
        ),
        isTrue,
      );

      final installmentTxs = store.transactions
          .where((t) => t.kind == TransactionKind.cardPurchase)
          .toList();
      expect(installmentTxs.length, 3);
      expect(
        installmentTxs.map((t) => t.amountCents).toList(),
        const Money(cents: 10000).splitEqually(3).map((m) => m.cents).toList(),
      );
      expect(
        installmentTxs.fold<int>(0, (s, t) => s + t.amountCents),
        10000,
      );
      expect(store.cards.first.usedLimitCents, 10000);

      // Paga a primeira fatura -> deduz R$ 33,34 da acc_1 e recompõe limite sem contar segunda despesa!
      final firstInvoice = store.invoices.first;
      expect(
        await cardCtrl.payInvoice(
          invoiceId: firstInvoice.id,
          paymentAccountId: 'acc_1',
          paymentDate: now,
        ),
        isTrue,
      );
      expect(store.accounts[0].currentBalanceCents, 400000 - 3334);
      expect(store.cards.first.usedLimitCents, 6666);

      // Estorna a 2ª parcela restante
      final secondParcel = installmentTxs[1];
      expect(
        await cardCtrl.refundOrCancelCardPurchase(
          transactionId: secondParcel.id,
          cancelEntirePlan: false,
        ),
        isTrue,
      );
      expect(store.cards.first.usedLimitCents, 3333);

      // 4. Recorrência mensal + idempotência dupla.
      final recurringCtrl =
          container.read(recurringControllerProvider.notifier);
      expect(
        await recurringCtrl.saveRule(
          kind: RecurringKind.expense,
          description: 'Internet Fibra',
          amountCents: 15000,
          isVariableAmount: false,
          categoryId: 'cat_exp_housing',
          accountId: 'acc_1',
          frequency: RecurringFrequency.monthly,
          startDate: DateTime(now.year, now.month, 5),
        ),
        isTrue,
      );
      final countAfterCreate =
          store.transactions.where((t) => t.recurringId != null).length;
      expect(countAfterCreate, greaterThanOrEqualTo(1));
      await recurringCtrl.syncNow(silent: true);
      final countAfterSecondSync =
          store.transactions.where((t) => t.recurringId != null).length;
      expect(countAfterSecondSync, countAfterCreate);

      // 5. Orçamento mensal + Analytics sem duplicidade de transferências/pagamento de fatura + PDF/CSV.
      final ym = DatePeriod.resolveAccountingYearMonth(now);
      final budgetCtrl = container.read(budgetControllerProvider.notifier);
      expect(
        await budgetCtrl.saveBudget(
          categoryId: 'cat_exp_food',
          year: ym.year,
          month: ym.month,
          limitCents: 100000, // Limite 1.000, gasto 1.200 => exceeded
          alertThresholdPercent: 80,
        ),
        isTrue,
      );

      final period = DatePeriod.fromType(DatePeriodType.thisMonth, reference: now);
      final categoriesById = {for (final c in store.categories) c.id: c};
      final snapshot = FinancialAnalyticsService.buildSnapshot(
        period: period,
        allTransactions: store.transactions,
        accounts: store.accounts,
        cards: store.cards,
        invoices: store.invoices,
        installmentPlans: store.plans,
        categoriesById: categoriesById,
        referenceDate: now,
      );

      // Receitas do período: apenas 500000 (transferência de 80000 ignorada).
      expect(snapshot.summary.totalIncomeCents, 500000);
      // Pagamento de fatura (3334) e transferências não contam como despesa duplicada!
      final periodExpenseContainsInvoicePayment = snapshot.periodTransactions
          .any((t) => t.kind == TransactionKind.invoicePayment);
      expect(periodExpenseContainsInvoicePayment, isTrue);
      // Despesas contabilizadas no snapshot exclui invoicePayment (3334) e transfer (80000).
      expect(
        snapshot.summary.totalExpenseCents,
        greaterThanOrEqualTo(120000),
      );
      expect(
        snapshot.summary.totalExpenseCents < 120000 + 80000,
        isTrue,
      );

      final csv = ReportExportService.buildCsv(snapshot);
      expect(csv.startsWith('\uFEFF'), isTrue);
      final pdf = await ReportExportService.buildPdfBytes(snapshot);
      expect(ascii.decode(pdf.take(5).toList()), '%PDF-');

      // 6. Exclusão LGPD completa: dados antes do usuário Auth.
      final profileCtrl = container.read(profileControllerProvider.notifier);
      expect(
        await profileCtrl.deleteAccount(currentPassword: 'secret'),
        isTrue,
      );
      expect(
        store.auditLog,
        [
          'reauthenticateWithPassword',
          'deleteUserData:uid_e2e',
          'deleteCurrentAuthUser',
        ],
      );
      expect(store.accounts, isEmpty);
      expect(store.transactions, isEmpty);

      // 7. Verifica delegação do datasource de exclusão LGPD ao backend seguro.
      String? cleanedUid;
      final ds = ProfileRemoteDatasource(
        serverAccountCleaner: (uid) async {
          cleanedUid = uid;
        },
      );
      await ds.deleteUserData('uid_e2e');
      expect(cleanedUid, 'uid_e2e');
    });
  });

  group('Etapa 7 — UI Mobile Responsiva (Home compacta + Card em Ajustes)', () {
    testWidgets(
        'DashboardPage em 360x780 exibe botões menores, filtros compactos e oculta card técnico movido para Ajustes',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final store = _EndToEndStore()
        ..categories.addAll(DefaultCategories.build(now))
        ..accounts.addAll([
          AccountEntity(
            id: 'acc_1',
            name: 'Conta Corrente',
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
          AccountEntity(
            id: 'acc_2',
            name: 'Poupança',
            institution: 'Inter',
            type: AccountType.savings,
            initialBalanceCents: 50000,
            currentBalanceCents: 50000,
            colorHex: '#2563EB',
            iconName: 'savings',
            openedAt: now,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        ])
        ..cards.add(
          CreditCardEntity(
            id: 'card_1',
            name: 'Nubank',
            institution: 'Nubank',
            brand: CardBrand.mastercard,
            totalLimitCents: 500000,
            usedLimitCents: 0,
            closingDay: 10,
            dueDay: 20,
            paymentAccountId: 'acc_1',
            colorHex: '#7C3AED',
            defaultInstallments: 1,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      final authRepo = _E2eAuthRepo(store);
      addTearDown(store.dispose);

      Widget wrap(Widget child) => ProviderScope(
            overrides: _e2eOverrides(store, authRepo),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: child,
            ),
          );

      // DashboardPage: exibe card inicial de saldos por conta, sem card de conexões ativas, com botões compactos sem overflow.
      await tester.pumpWidget(wrap(const DashboardPage()));
      await tester.pumpAndSettle();

      expect(find.byType(AppBrandLogo), findsOneWidget);
      expect(find.text('Saldo das contas'), findsOneWidget);
      expect(find.text('Conta Corrente'), findsOneWidget);
      expect(find.text('Poupança'), findsOneWidget);
      expect(find.textContaining('2.000,00'), findsWidgets);
      expect(find.textContaining('500,00'), findsWidgets);
      expect(find.textContaining('2.500,00'), findsWidgets);
      expect(
        tester.getTopLeft(find.text('Saldo das contas')).dy,
        lessThan(tester.getTopLeft(find.text('Nova receita')).dy),
      );
      expect(find.text('Conexões Ativas e Diagnóstico'), findsNothing);
      expect(find.text('Sincronizado'), findsNothing);
      expect(find.text('Cache Hive ativo'), findsNothing);
      expect(find.text('Nova receita'), findsOneWidget);
      expect(find.text('Nova despesa'), findsOneWidget);
      expect(find.text('Compra no cartão'), findsOneWidget);
      expect(find.text('Transferir'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Este mês'), findsOneWidget);
      expect(find.text('Mês anterior'), findsOneWidget);
      expect(find.text('Personalizado'), findsOneWidget);

      final receitaButtonSize =
          tester.getSize(find.ancestor(of: find.text('Nova receita'), matching: find.bySubtype<ButtonStyleButton>()));
      expect(receitaButtonSize.height, lessThanOrEqualTo(36));
      final chipSize =
          tester.getSize(find.widgetWithText(ChoiceChip, 'Este mês'));
      expect(chipSize.height, lessThanOrEqualTo(36));
      expect(tester.takeException(), isNull);

      // Tocar em uma conta no card inicial abre seu extrato individual sem erros.
      await tester.tap(find.text('Conta Corrente'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountStatementPage), findsOneWidget);
      expect(find.textContaining('Saldo inicial:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AppBrandLogo), findsOneWidget);
      expect(find.text('Saldo das contas'), findsOneWidget);

      // SettingsPage (Ajustes): recebe o card de Conexões Ativas + App Check sem overflow.
      await tester.pumpWidget(wrap(const SettingsPage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Conexões Ativas e Diagnóstico'));
      await tester.pumpAndSettle();

      expect(find.text('Conexões Ativas e Diagnóstico'), findsOneWidget);
      expect(find.text('Sincronizado'), findsOneWidget);
      expect(find.text('Cache Hive ativo'), findsOneWidget);
      expect(find.text('Firebase conectado'), findsOneWidget);
      expect(find.text('App Check ativo (Play Integrity)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // CardPurchaseFormDialog em 360x780: cria compra recorrente infinita (assinatura) no cartão.
      await tester.pumpWidget(wrap(const CardPurchaseFormDialog()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Recorrente'));
      await tester.pumpAndSettle();
      expect(find.text('Nova assinatura no cartão'), findsOneWidget);
      expect(find.textContaining('Hora:'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome da assinatura / recorrência'),
        'Spotify Duo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor por cobrança (R\$)'),
        '27,90',
      );
      await tester.ensureVisible(find.text('Ativar assinatura'));
      await tester.tap(find.text('Ativar assinatura'));
      await tester.pumpAndSettle();

      expect(store.rules.length, 1);
      expect(store.rules.first.description, 'Spotify Duo');
      expect(store.rules.first.amountCents, 2790);
      expect(store.rules.first.cardId, 'card_1');
      expect(store.rules.first.accountId, isNull);
      expect(store.rules.first.frequency, RecurringFrequency.monthly);
      expect(store.rules.first.endDate, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
