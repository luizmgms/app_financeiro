import 'dart:async';
import 'package:finance_control/core/services/attachment_storage_service.dart';
import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/core/services/local_storage_service.dart';
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
import 'package:finance_control/features/credit_cards/application/controllers/credit_card_controller.dart';
import 'package:finance_control/features/credit_cards/application/providers/credit_card_providers.dart';
import 'package:finance_control/features/credit_cards/domain/entities/credit_card_entity.dart';
import 'package:finance_control/features/credit_cards/domain/entities/invoice_entity.dart';
import 'package:finance_control/features/credit_cards/domain/repositories/credit_card_repository.dart';
import 'package:finance_control/features/credit_cards/domain/services/credit_card_cycle_calculator.dart';
import 'package:finance_control/features/credit_cards/presentation/pages/credit_cards_page.dart';
import 'package:finance_control/features/credit_cards/presentation/widgets/card_purchase_form_dialog.dart';
import 'package:finance_control/features/credit_cards/presentation/widgets/credit_card_form_dialog.dart';
import 'package:finance_control/features/credit_cards/presentation/widgets/pay_invoice_dialog.dart';
import 'package:finance_control/features/installments/domain/entities/installment_plan_entity.dart';
import 'package:finance_control/features/installments/presentation/pages/installments_page.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/features/transactions/application/providers/transaction_providers.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_attachment.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_summary.dart';
import 'package:finance_control/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeAuthRepo implements AuthRepository {
  static const user = AuthUser(
    uid: 'u_stage3',
    email: 'luiz@financecontrol.app',
    displayName: 'Luiz',
  );
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(user);
  @override
  AuthUser? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepo implements ProfileRepository {
  final _profile = UserProfile(
    uid: 'u_stage3',
    displayName: 'Luiz',
    email: 'luiz@financecontrol.app',
    createdAt: DateTime(2026, 11, 18),
    updatedAt: DateTime(2026, 11, 18),
  );
  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(_profile);
  @override
  Future<UserProfile> ensureProfile({required AuthUser user}) async => _profile;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stage3InMemoryStore {
  final cardsController = StreamController<List<CreditCardEntity>>.broadcast();
  final invoicesController = StreamController<List<InvoiceEntity>>.broadcast();
  final plansController =
      StreamController<List<InstallmentPlanEntity>>.broadcast();
  final accountsController = StreamController<List<AccountEntity>>.broadcast();
  final categoriesController =
      StreamController<List<CategoryEntity>>.broadcast();
  final transactionsController =
      StreamController<List<TransactionEntity>>.broadcast();

  final List<CreditCardEntity> cards = [];
  final List<InvoiceEntity> invoices = [];
  final List<InstallmentPlanEntity> plans = [];
  final List<AccountEntity> accounts = [];
  final List<CategoryEntity> categories = [];
  final List<TransactionEntity> transactions = [];

  void dispose() {
    cardsController.close();
    invoicesController.close();
    plansController.close();
    accountsController.close();
    categoriesController.close();
    transactionsController.close();
  }

  void emitAll() {
    cardsController.add(List.unmodifiable(cards));
    invoicesController.add(List.unmodifiable(invoices));
    plansController.add(List.unmodifiable(plans));
    accountsController.add(List.unmodifiable(accounts));
    categoriesController.add(List.unmodifiable(categories));
    transactionsController.add(List.unmodifiable(transactions));
  }
}

class _FakeCategoryRepo implements CategoryRepository {
  _FakeCategoryRepo(this.store);
  final _Stage3InMemoryStore store;

  @override
  Stream<List<CategoryEntity>> watchCategories(String userId) async* {
    yield List.unmodifiable(store.categories);
    yield* store.categoriesController.stream;
  }

  @override
  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {
    if (store.categories.isEmpty) {
      store.categories.addAll(DefaultCategories.build(DateTime(2026, 11, 18)));
      store.emitAll();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountRepo implements AccountRepository {
  _FakeAccountRepo(this.store);
  final _Stage3InMemoryStore store;

  @override
  Stream<List<AccountEntity>> watchAccounts(String userId) async* {
    yield List.unmodifiable(store.accounts);
    yield* store.accountsController.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionRepo implements TransactionRepository {
  _FakeTransactionRepo(this.store);
  final _Stage3InMemoryStore store;

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
  final _Stage3InMemoryStore store;

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
  }) async {
    final created = card.copyWith(id: 'card_${store.cards.length + 1}');
    store.cards.add(created);
    store.emitAll();
    return created;
  }

  @override
  Future<void> updateCard({
    required String userId,
    required CreditCardEntity card,
  }) async {
    final idx = store.cards.indexWhere((c) => c.id == card.id);
    store.cards[idx] = card;
    store.emitAll();
  }

  @override
  Future<void> setArchived({
    required String userId,
    required String cardId,
    required bool archived,
  }) async {
    final idx = store.cards.indexWhere((c) => c.id == cardId);
    store.cards[idx] = store.cards[idx].copyWith(isActive: !archived);
    store.emitAll();
  }

  @override
  Future<void> deleteCard({
    required String userId,
    required String cardId,
  }) async {
    store.cards.removeWhere((c) => c.id == cardId);
    store.emitAll();
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

    final schedule = CreditCardCycleCalculator.buildCardInstallmentSchedule(
      cardId: card.id,
      totalAmountCents: totalAmountCents,
      installmentCount: installmentCount,
      purchaseDate: purchaseDate,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
    );

    String? planId;
    if (installmentCount > 1) {
      planId = 'plan_${store.plans.length + 1}';
      store.plans.add(
        InstallmentPlanEntity(
          id: planId,
          description: description,
          totalAmountCents: totalAmountCents,
          installmentCount: installmentCount,
          firstCompetencyDate: schedule.first.competencyDate,
          firstDueDate: schedule.first.dueDate,
          categoryId: categoryId,
          cardId: cardId,
          status: InstallmentPlanStatus.active,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    for (final slice in schedule) {
      final invCycle = slice.invoiceTarget!;
      final existingInvIdx =
          store.invoices.indexWhere((inv) => inv.id == invCycle.invoiceId);
      if (existingInvIdx != -1) {
        final existing = store.invoices[existingInvIdx];
        store.invoices[existingInvIdx] = existing.copyWith(
          totalAmountCents: existing.totalAmountCents + slice.amountCents,
        );
      } else {
        store.invoices.add(
          InvoiceEntity(
            id: invCycle.invoiceId,
            cardId: card.id,
            referenceMonth: invCycle.referenceMonth,
            referenceYear: invCycle.referenceYear,
            closingDate: invCycle.closingDate,
            dueDate: invCycle.dueDate,
            totalAmountCents: slice.amountCents,
            paidAmountCents: 0,
            status: InvoiceStatus.open,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      store.transactions.add(
        TransactionEntity(
          id: 'tx_${store.transactions.length + 1}',
          kind: TransactionKind.cardPurchase,
          description: installmentCount > 1
              ? '$description (${slice.installmentNumber}/${slice.totalInstallments})'
              : description,
          amountCents: slice.amountCents,
          categoryId: categoryId,
          cardId: card.id,
          invoiceId: invCycle.invoiceId,
          installmentPlanId: planId,
          installmentNumber: slice.installmentNumber,
          totalInstallments: slice.totalInstallments,
          competencyDate: slice.competencyDate,
          dueDate: slice.dueDate,
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    store.cards[cardIdx] = card.copyWith(
      usedLimitCents: card.usedLimitCents + totalAmountCents,
    );
    store.emitAll();
  }

  @override
  Future<void> recordCardStandaloneRefund({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime refundDate,
    String? notes,
  }) async {
    final cardIdx = store.cards.indexWhere((c) => c.id == cardId);
    final card = store.cards[cardIdx];
    final now = DateTime.now();

    final target = CreditCardCycleCalculator.resolveInvoiceForPurchase(
      cardId: card.id,
      purchaseDate: refundDate,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
    );

    final invIdx =
        store.invoices.indexWhere((inv) => inv.id == target.invoiceId);
    if (invIdx != -1) {
      final existing = store.invoices[invIdx];
      final nextTotal = existing.totalAmountCents - amountCents;
      store.invoices[invIdx] = existing.copyWith(
        totalAmountCents: nextTotal < 0 ? 0 : nextTotal,
      );
    } else {
      store.invoices.add(
        InvoiceEntity(
          id: target.invoiceId,
          cardId: card.id,
          referenceMonth: target.referenceMonth,
          referenceYear: target.referenceYear,
          closingDate: target.closingDate,
          dueDate: target.dueDate,
          totalAmountCents: 0,
          paidAmountCents: 0,
          status: InvoiceStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    store.transactions.add(
      TransactionEntity(
        id: 'tx_refund_${store.transactions.length + 1}',
        kind: TransactionKind.cardRefund,
        description: description,
        amountCents: amountCents,
        categoryId: categoryId,
        cardId: card.id,
        invoiceId: target.invoiceId,
        competencyDate: refundDate,
        dueDate: target.dueDate,
        status: TransactionStatus.pending,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final nextUsed = card.usedLimitCents - amountCents;
    store.cards[cardIdx] = card.copyWith(
      usedLimitCents: nextUsed < 0 ? 0 : nextUsed,
    );
    store.emitAll();
  }

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
  }) async {
    final invIdx = store.invoices.indexWhere((inv) => inv.id == invoiceId);
    final invoice = store.invoices[invIdx];
    final remaining = invoice.remainingAmountCents;

    final accIdx = store.accounts.indexWhere((a) => a.id == paymentAccountId);
    store.accounts[accIdx] = store.accounts[accIdx].copyWith(
      currentBalanceCents: store.accounts[accIdx].currentBalanceCents - remaining,
    );

    final cardIdx = store.cards.indexWhere((c) => c.id == invoice.cardId);
    store.cards[cardIdx] = store.cards[cardIdx].copyWith(
      usedLimitCents: store.cards[cardIdx].usedLimitCents - remaining,
    );

    store.invoices[invIdx] = invoice.copyWith(
      status: InvoiceStatus.paid,
      paidAmountCents: invoice.totalAmountCents,
      paidAt: paymentDate,
    );

    for (var i = 0; i < store.transactions.length; i++) {
      final tx = store.transactions[i];
      if (tx.kind == TransactionKind.cardPurchase &&
          tx.invoiceId == invoiceId) {
        store.transactions[i] = tx.copyWith(
          status: TransactionStatus.paid,
          paymentDate: paymentDate,
        );
      }
    }

    final now = DateTime.now();
    store.transactions.add(
      TransactionEntity(
        id: 'tx_inv_pay_${store.transactions.length + 1}',
        kind: TransactionKind.invoicePayment,
        description: 'Pagamento Fatura ${invoice.referenceLabel}',
        amountCents: remaining,
        accountId: paymentAccountId,
        cardId: invoice.cardId,
        invoiceId: invoice.id,
        competencyDate: paymentDate,
        paymentDate: paymentDate,
        status: TransactionStatus.paid,
        createdAt: now,
        updatedAt: now,
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
    final target =
        store.transactions.firstWhere((tx) => tx.id == transactionId);
    final toRefund = cancelAllPlanInstallments && target.installmentPlanId != null
        ? store.transactions
            .where(
              (tx) =>
                  tx.installmentPlanId == target.installmentPlanId &&
                  !tx.status.isSettled,
            )
            .toList()
        : [target];

    var refundedSum = 0;
    for (final item in toRefund) {
      refundedSum += item.amountCents;
      final invIdx =
          store.invoices.indexWhere((inv) => inv.id == item.invoiceId);
      if (invIdx != -1) {
        final inv = store.invoices[invIdx];
        store.invoices[invIdx] = inv.copyWith(
          totalAmountCents: inv.totalAmountCents - item.amountCents,
        );
      }
      store.transactions.removeWhere((tx) => tx.id == item.id);
    }

    if (target.cardId != null) {
      final cardIdx = store.cards.indexWhere((c) => c.id == target.cardId);
      store.cards[cardIdx] = store.cards[cardIdx].copyWith(
        usedLimitCents: store.cards[cardIdx].usedLimitCents - refundedSum,
      );
    }
    store.emitAll();
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  group('CreditCardCycleCalculator', () {
    test('routes purchase before closing day to current month invoice', () {
      final cycle = CreditCardCycleCalculator.resolveInvoiceForPurchase(
        cardId: 'card_1',
        purchaseDate: DateTime(2026, 11, 4),
        closingDay: 5,
        dueDay: 12,
      );

      expect(cycle.referenceMonth, 11);
      expect(cycle.referenceYear, 2026);
      expect(cycle.closingDate, DateTime(2026, 11, 5, 12));
      expect(cycle.dueDate, DateTime(2026, 11, 12, 12));
    });

    test('routes purchase on or after closing day to next month invoice', () {
      final onClosing = CreditCardCycleCalculator.resolveInvoiceForPurchase(
        cardId: 'card_1',
        purchaseDate: DateTime(2026, 11, 5),
        closingDay: 5,
        dueDay: 12,
      );
      expect(onClosing.referenceMonth, 12);
      expect(onClosing.referenceYear, 2026);
      expect(onClosing.closingDate, DateTime(2026, 12, 5, 12));
      expect(onClosing.dueDate, DateTime(2026, 12, 12, 12));

      final yearRollover = CreditCardCycleCalculator.resolveInvoiceForPurchase(
        cardId: 'card_1',
        purchaseDate: DateTime(2026, 12, 20),
        closingDay: 15,
        dueDay: 25,
      );
      expect(yearRollover.referenceMonth, 1);
      expect(yearRollover.referenceYear, 2027);
    });

    test('rolls due date to following month when dueDay < closingDay', () {
      final cycle = CreditCardCycleCalculator.resolveInvoiceForPurchase(
        cardId: 'card_1',
        purchaseDate: DateTime(2026, 11, 10),
        closingDay: 25,
        dueDay: 5,
      );

      expect(cycle.referenceMonth, 11);
      expect(cycle.referenceYear, 2026);
      expect(cycle.closingDate, DateTime(2026, 11, 25, 12));
      expect(cycle.dueDate, DateTime(2026, 12, 5, 12));
    });

    test(
        'splits installment purchases with exact cents and consecutive invoices',
        () {
      final schedule = CreditCardCycleCalculator.buildCardInstallmentSchedule(
        cardId: 'card_1',
        totalAmountCents: 10000, // R$ 100,00 em 3x -> 3334 + 3333 + 3333
        installmentCount: 3,
        purchaseDate: DateTime(2026, 11, 2),
        closingDay: 10,
        dueDay: 17,
      );

      expect(schedule.length, 3);
      expect(schedule[0].amountCents, 3334);
      expect(schedule[1].amountCents, 3333);
      expect(schedule[2].amountCents, 3333);
      expect(
        schedule.fold<int>(0, (sum, s) => sum + s.amountCents),
        10000,
      );
      expect(schedule[0].invoiceTarget!.referenceMonth, 11);
      expect(schedule[1].invoiceTarget!.referenceMonth, 12);
      expect(schedule[2].invoiceTarget!.referenceMonth, 1);
      expect(schedule[2].invoiceTarget!.referenceYear, 2027);

      final timedSchedule =
          CreditCardCycleCalculator.buildCardInstallmentSchedule(
        cardId: 'card_1',
        totalAmountCents: 6000,
        installmentCount: 2,
        purchaseDate: DateTime(2026, 11, 2, 19, 45),
        closingDay: 10,
        dueDay: 17,
      );
      expect(timedSchedule[0].competencyDate, DateTime(2026, 11, 2, 19, 45));
      expect(timedSchedule[1].competencyDate, DateTime(2026, 12, 2, 19, 45));
    });
  });

  group('CreditCardController & Invoice Payment Flow', () {
    test(
        'records installment purchase, pays first invoice without duplicating expenses, and refunds remaining installments',
        () async {
      final now = DateTime(2026, 11, 3);
      final store = _Stage3InMemoryStore()
        ..categories.addAll(DefaultCategories.build(now))
        ..accounts.add(
          AccountEntity(
            id: 'acc_1',
            name: 'Nubank Conta',
            institution: 'Nubank',
            type: AccountType.checking,
            initialBalanceCents: 200000,
            currentBalanceCents: 200000,
            colorHex: '#7C3AED',
            iconName: 'account_balance',
            openedAt: now,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      addTearDown(store.dispose);

      final container = ProviderContainer(
        overrides: [
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
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
          categoryRepositoryProvider
              .overrideWithValue(_FakeCategoryRepo(store)),
          accountRepositoryProvider.overrideWithValue(_FakeAccountRepo(store)),
          transactionRepositoryProvider
              .overrideWithValue(_FakeTransactionRepo(store)),
          creditCardRepositoryProvider
              .overrideWithValue(_FakeCreditCardRepo(store)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(creditCardControllerProvider.notifier);

      // 1. Cria cartão com R$ 5.000,00 de limite
      final createdCard = await controller.saveCard(
        name: 'Nubank Ultravioleta',
        institution: 'Nubank',
        brand: CardBrand.mastercard,
        totalLimitCents: 500000,
        closingDay: 10,
        dueDay: 17,
        paymentAccountId: 'acc_1',
        colorHex: '#7C3AED',
      );
      expect(createdCard, isTrue);
      expect(store.cards.single.totalLimitCents, 500000);
      expect(store.cards.single.usedLimitCents, 0);

      // 2. Registra compra parcelada de R$ 900,00 em 3x
      final recorded = await controller.recordCardPurchase(
        cardId: store.cards.single.id,
        categoryId: 'cat_exp_shopping',
        description: 'Monitor 27"',
        totalAmountCents: 90000,
        purchaseDate: DateTime(2026, 11, 3),
        totalInstallments: 3,
      );
      expect(recorded, isTrue);
      expect(store.cards.single.usedLimitCents, 90000);
      expect(store.cards.single.availableLimitCents, 410000);
      expect(store.invoices.length, 3);
      expect(store.transactions.length, 3);

      // 3. Paga a primeira fatura (11/2026 - R$ 300,00)
      final firstInvoice = store.invoices.firstWhere(
        (inv) => inv.referenceMonth == 11 && inv.referenceYear == 2026,
      );
      final paid = await controller.payInvoice(
        invoiceId: firstInvoice.id,
        paymentAccountId: 'acc_1',
        paymentDate: DateTime(2026, 11, 15),
      );
      expect(paid, isTrue);

      // Conta bancária teve R$ 300,00 debitados (200000 -> 170000)
      expect(store.accounts.single.currentBalanceCents, 170000);
      // Limite utilizado do cartão reduziu em R$ 300,00 (90000 -> 60000)
      expect(store.cards.single.usedLimitCents, 60000);
      expect(store.cards.single.availableLimitCents, 440000);

      // Resumo de despesas do período não duplica o pagamento da fatura
      final summary =
          TransactionPeriodSummary.fromTransactions(store.transactions);
      expect(summary.totalExpenseCents, 90000);

      // 4. Estorna o restante do parcelamento (parcelas 2 e 3 em aberto)
      final secondSlice = store.transactions
          .firstWhere((tx) => tx.installmentNumber == 2);
      final refunded = await controller.refundOrCancelCardPurchase(
        transactionId: secondSlice.id,
        cancelEntirePlan: true,
      );
      expect(refunded, isTrue);
      expect(store.cards.single.usedLimitCents, 0);
      expect(store.cards.single.availableLimitCents, 500000);

      // 5. Registra compra de R$ 50,00 e um estorno avulso de R$ 0,75 (centavos)
      await controller.recordCardPurchase(
        cardId: store.cards.single.id,
        categoryId: 'cat_exp_food',
        description: 'Padaria',
        totalAmountCents: 5000,
        purchaseDate: DateTime(2026, 11, 12),
      );
      expect(store.cards.single.usedLimitCents, 5000);

      final standaloneRefunded = await controller.recordCardStandaloneRefund(
        cardId: store.cards.single.id,
        categoryId: 'cat_exp_food',
        description: 'Estorno parcial / Cashback centavos',
        amountCents: 75, // R$ 0,75
        refundDate: DateTime(2026, 11, 13),
      );
      expect(standaloneRefunded, isTrue);
      expect(store.cards.single.usedLimitCents, 4925);
      expect(store.cards.single.availableLimitCents, 495075);

      final decInvoice = store.invoices.firstWhere(
        (inv) => inv.referenceMonth == 12 && inv.referenceYear == 2026,
      );
      expect(decInvoice.totalAmountCents, 4925);

      final updatedSummary =
          TransactionPeriodSummary.fromTransactions(store.transactions);
      // 30000 (1ª parcela paga) + 5000 (Padaria) - 75 (Estorno avulso) = 34925
      expect(updatedSummary.totalExpenseCents, 34925);
    });
  });

  testWidgets('CreditCardsPage and InstallmentsPage render cards and plans',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime(2026, 11, 18);
    final store = _Stage3InMemoryStore()
      ..categories.addAll(DefaultCategories.build(now))
      ..accounts.add(
        AccountEntity(
          id: 'acc_1',
          name: 'Conta Principal',
          institution: 'Itaú',
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
      )
      ..cards.add(
        CreditCardEntity(
          id: 'card_1',
          name: 'Itaú Personalité',
          institution: 'Itaú',
          brand: CardBrand.visa,
          totalLimitCents: 1000000,
          usedLimitCents: 150000,
          closingDay: 10,
          dueDay: 17,
          paymentAccountId: 'acc_1',
          colorHex: '#2563EB',
          defaultInstallments: 1,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..invoices.add(
        InvoiceEntity(
          id: 'card_1_2026_12',
          cardId: 'card_1',
          referenceMonth: 12,
          referenceYear: 2026,
          closingDate: DateTime(2026, 12, 10),
          dueDate: DateTime(2026, 12, 17),
          totalAmountCents: 150000,
          paidAmountCents: 0,
          status: InvoiceStatus.open,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..plans.add(
        InstallmentPlanEntity(
          id: 'plan_1',
          description: 'Geladeira Inverter',
          totalAmountCents: 300000,
          installmentCount: 2,
          firstCompetencyDate: now,
          firstDueDate: DateTime(2026, 12, 17),
          categoryId: 'cat_exp_housing',
          cardId: 'card_1',
          status: InstallmentPlanStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..transactions.add(
        TransactionEntity(
          id: 'tx_1',
          kind: TransactionKind.cardPurchase,
          description: 'Geladeira Inverter (1/2)',
          amountCents: 150000,
          categoryId: 'cat_exp_housing',
          cardId: 'card_1',
          invoiceId: 'card_1_2026_12',
          installmentPlanId: 'plan_1',
          installmentNumber: 1,
          totalInstallments: 2,
          competencyDate: now,
          dueDate: DateTime(2026, 12, 17),
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );
    addTearDown(store.dispose);

    Widget buildTestable(Widget child) {
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
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
          categoryRepositoryProvider
              .overrideWithValue(_FakeCategoryRepo(store)),
          accountRepositoryProvider.overrideWithValue(_FakeAccountRepo(store)),
          transactionRepositoryProvider
              .overrideWithValue(_FakeTransactionRepo(store)),
          creditCardRepositoryProvider
              .overrideWithValue(_FakeCreditCardRepo(store)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      );
    }

    await tester.pumpWidget(buildTestable(const CreditCardsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Itaú Personalité'), findsOneWidget);
    expect(find.text('Fatura 12/2026'), findsOneWidget);
    expect(find.text('Geladeira Inverter (1/2)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(buildTestable(const InstallmentsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Parcelamentos'), findsOneWidget);
    expect(find.text('Geladeira Inverter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Mobile narrow viewport (360x780) renders Stage 3 dialogs and pages without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime(2026, 11, 18);
    final invoice = InvoiceEntity(
      id: 'card_1_2026_12',
      cardId: 'card_1',
      referenceMonth: 12,
      referenceYear: 2026,
      closingDate: DateTime(2026, 12, 1),
      dueDate: DateTime(2026, 12, 25),
      totalAmountCents: 1250000,
      paidAmountCents: 0,
      status: InvoiceStatus.open,
      createdAt: now,
      updatedAt: now,
    );
    final card = CreditCardEntity(
      id: 'card_1',
      name: 'Nubank',
      institution: 'Nubank',
      brand: CardBrand.mastercard,
      totalLimitCents: 1250000,
      usedLimitCents: 449100,
      closingDay: 1,
      dueDay: 25,
      paymentAccountId: 'acc_1',
      colorHex: '#7C3AED',
      defaultInstallments: 1,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    final store = _Stage3InMemoryStore()
      ..categories.addAll(DefaultCategories.build(now))
      ..accounts.add(
        AccountEntity(
          id: 'acc_1',
          name: 'Conta Corrente Principal Muito Longa',
          institution: 'Nubank',
          type: AccountType.checking,
          initialBalanceCents: 500000,
          currentBalanceCents: 500000,
          colorHex: '#0F766E',
          iconName: 'account_balance',
          openedAt: now,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..cards.add(card)
      ..invoices.add(invoice)
      ..plans.add(
        InstallmentPlanEntity(
          id: 'plan_mobile_1',
          description: 'Notebook Profissional',
          totalAmountCents: 600000,
          installmentCount: 6,
          firstCompetencyDate: now,
          firstDueDate: invoice.dueDate,
          categoryId: 'cat_exp_food',
          cardId: 'card_1',
          status: InstallmentPlanStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..transactions.addAll([
        TransactionEntity(
          id: 'tx_mobile_purchase',
          kind: TransactionKind.cardPurchase,
          description: 'Notebook Profissional (1/6)',
          amountCents: 100000,
          categoryId: 'cat_exp_food',
          cardId: 'card_1',
          invoiceId: invoice.id,
          installmentPlanId: 'plan_mobile_1',
          installmentNumber: 1,
          totalInstallments: 6,
          competencyDate: now,
          dueDate: invoice.dueDate,
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx_mobile_refund',
          kind: TransactionKind.cardRefund,
          description: 'Ajuste de centavos',
          amountCents: 75,
          categoryId: 'cat_exp_food',
          cardId: 'card_1',
          invoiceId: invoice.id,
          competencyDate: now,
          dueDate: invoice.dueDate,
          status: TransactionStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    addTearDown(store.dispose);

    Widget buildMobileScope(Widget child) {
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
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
          categoryRepositoryProvider
              .overrideWithValue(_FakeCategoryRepo(store)),
          accountRepositoryProvider.overrideWithValue(_FakeAccountRepo(store)),
          transactionRepositoryProvider
              .overrideWithValue(_FakeTransactionRepo(store)),
          creditCardRepositoryProvider
              .overrideWithValue(_FakeCreditCardRepo(store)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    // 1. Formulário Novo Cartão em tela estreita
    await tester.pumpWidget(buildMobileScope(const CreditCardFormDialog()));
    await tester.pumpAndSettle();
    expect(find.text('Novo cartão'), findsOneWidget);
    expect(find.text('Nenhuma selecionada'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 2. Formulário Compra / Estorno / Em conta com tipo Parcelada vs Recorrente e seletor de Hora
    await tester.pumpWidget(buildMobileScope(const CardPurchaseFormDialog()));
    await tester.pumpAndSettle();
    expect(find.text('Nova compra no cartão'), findsOneWidget);
    expect(find.text('Compra'), findsOneWidget);
    expect(find.text('Estorno'), findsOneWidget);
    expect(find.text('Em conta'), findsOneWidget);
    expect(find.text('Tipo de compra'), findsOneWidget);
    expect(find.text('Parcelada'), findsOneWidget);
    expect(find.text('Recorrente'), findsOneWidget);
    expect(find.textContaining('Hora:'), findsOneWidget);

    final purchaseBtnSize = tester.getSize(find.text('Compra'));
    final refundBtnSize = tester.getSize(find.text('Estorno'));
    final accountBtnSize = tester.getSize(find.text('Em conta'));
    expect(purchaseBtnSize.height, lessThan(26));
    expect(refundBtnSize.height, lessThan(26));
    expect(accountBtnSize.height, lessThan(26));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Recorrente'));
    await tester.pumpAndSettle();
    expect(find.text('Nova assinatura no cartão'), findsOneWidget);
    expect(find.text('Ativar assinatura'), findsOneWidget);
    expect(find.text('Frequência'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Parcelada'));
    await tester.pumpAndSettle();
    expect(find.text('Nova compra no cartão'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Estorno'));
    await tester.pumpAndSettle();
    expect(find.text('Estorno avulso no cartão'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Em conta'));
    await tester.pumpAndSettle();
    expect(find.text('Parcelamento em conta'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 3. Modal de pagamento de fatura
    await tester.pumpWidget(
      buildMobileScope(PayInvoiceDialog(invoice: invoice, card: card)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pagar fatura 12/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 4. Páginas de Cartões e Parcelamentos em viewport mobile 360px
    await tester.pumpWidget(buildMobileScope(const CreditCardsPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(buildMobileScope(const InstallmentsPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final planTileFinder = find.ancestor(
      of: find.text('Notebook Profissional'),
      matching: find.byType(ListTile),
    );
    await tester.tap(planTileFinder);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.text('Parcela 1/6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
