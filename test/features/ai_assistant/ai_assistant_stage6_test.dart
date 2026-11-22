import 'dart:async';
import 'dart:typed_data';
import 'package:finance_control/core/services/attachment_storage_service.dart';
import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/core/theme/app_theme.dart';
import 'package:finance_control/features/accounts/application/providers/account_providers.dart';
import 'package:finance_control/features/accounts/domain/entities/account_entity.dart';
import 'package:finance_control/features/accounts/domain/repositories/account_repository.dart';
import 'package:finance_control/features/ai_assistant/application/providers/ai_providers.dart';
import 'package:finance_control/features/ai_assistant/data/datasources/gemini_datasource.dart';
import 'package:finance_control/features/ai_assistant/data/datasources/media_input_service.dart';
import 'package:finance_control/features/ai_assistant/data/datasources/voice_input_service.dart';
import 'package:finance_control/features/ai_assistant/data/repositories/ai_repository_impl.dart';
import 'package:finance_control/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:finance_control/features/ai_assistant/domain/entities/ai_quota_status.dart';
import 'package:finance_control/features/ai_assistant/domain/entities/ai_transaction_suggestion.dart';
import 'package:finance_control/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:finance_control/features/ai_assistant/domain/services/ai_suggestion_validator.dart';
import 'package:finance_control/features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/categories/application/providers/category_providers.dart';
import 'package:finance_control/features/categories/domain/entities/category_entity.dart';
import 'package:finance_control/features/categories/domain/repositories/category_repository.dart';
import 'package:finance_control/features/credit_cards/application/providers/credit_card_providers.dart';
import 'package:finance_control/features/credit_cards/domain/entities/credit_card_entity.dart';
import 'package:finance_control/features/credit_cards/domain/entities/invoice_entity.dart';
import 'package:finance_control/features/credit_cards/domain/repositories/credit_card_repository.dart';
import 'package:finance_control/features/installments/domain/entities/installment_plan_entity.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/features/recurring/application/providers/recurring_providers.dart';
import 'package:finance_control/features/recurring/domain/entities/recurring_rule_entity.dart';
import 'package:finance_control/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finance_control/features/transactions/application/providers/transaction_providers.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_attachment.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _AiTestStore {
  final List<CategoryEntity> categories = [
    CategoryEntity(
      id: 'cat_food',
      name: 'Alimentação',
      description: 'Refeições e mercado',
      type: CategoryType.expense,
      iconName: 'restaurant',
      colorHex: '#0F766E',
      isDefault: true,
      isActive: true,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    ),
    CategoryEntity(
      id: 'cat_salary',
      name: 'Salário',
      description: 'Rendimentos',
      type: CategoryType.income,
      iconName: 'payments',
      colorHex: '#10B981',
      isDefault: true,
      isActive: true,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    ),
  ];

  final List<AccountEntity> accounts = [
    AccountEntity(
      id: 'acc_chk',
      name: 'Conta Corrente',
      institution: 'Banco do Brasil',
      type: AccountType.checking,
      initialBalanceCents: 200000,
      currentBalanceCents: 200000,
      colorHex: '#0F766E',
      iconName: 'account_balance',
      openedAt: DateTime(2026, 1, 1),
      isActive: true,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    ),
    AccountEntity(
      id: 'acc_sav',
      name: 'Reserva Poupança',
      institution: 'Caixa',
      type: AccountType.savings,
      initialBalanceCents: 500000,
      currentBalanceCents: 500000,
      colorHex: '#3B82F6',
      iconName: 'savings',
      openedAt: DateTime(2026, 1, 1),
      isActive: true,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    ),
  ];

  final List<CreditCardEntity> cards = [
    CreditCardEntity(
      id: 'card_nu',
      name: 'Nubank',
      institution: 'Nubank',
      brand: CardBrand.mastercard,
      totalLimitCents: 800000,
      usedLimitCents: 120000,
      closingDay: 5,
      dueDay: 12,
      paymentAccountId: 'acc_chk',
      colorHex: '#8B5CF6',
      defaultInstallments: 1,
      isActive: true,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    ),
  ];

  final List<InvoiceEntity> invoices = [
    InvoiceEntity(
      id: 'card_nu_2026_11',
      cardId: 'card_nu',
      referenceYear: 2026,
      referenceMonth: 11,
      closingDate: DateTime(2026, 11, 5),
      dueDate: DateTime(2026, 11, 12),
      totalAmountCents: 120000,
      paidAmountCents: 0,
      status: InvoiceStatus.closed,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    ),
  ];

  final List<TransactionEntity> createdTransactions = [];
  final List<Map<String, dynamic>> createdCardPurchases = [];
  final List<Map<String, dynamic>> paidInvoices = [];
  final List<Map<String, dynamic>> createdTransfers = [];
  final List<RecurringRuleEntity> createdRecurringRules = [];
  final List<CategoryEntity> createdCategories = [];

  UserProfile profile = UserProfile(
    uid: 'u_ai',
    displayName: 'Luiz',
    email: 'luiz@financecontrol.app',
    aiAssistantEnabled: true,
    aiShareFinancialContext: true,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );

  final categoriesCtrl = StreamController<List<CategoryEntity>>.broadcast();
  final accountsCtrl = StreamController<List<AccountEntity>>.broadcast();
  final cardsCtrl = StreamController<List<CreditCardEntity>>.broadcast();
  final invoicesCtrl = StreamController<List<InvoiceEntity>>.broadcast();
  final txCtrl = StreamController<List<TransactionEntity>>.broadcast();
  final profileCtrl = StreamController<UserProfile?>.broadcast();

  void dispose() {
    categoriesCtrl.close();
    accountsCtrl.close();
    cardsCtrl.close();
    invoicesCtrl.close();
    txCtrl.close();
    profileCtrl.close();
  }
}

class _FakeAuthRepo implements AuthRepository {
  static const _user = AuthUser(
    uid: 'u_ai',
    email: 'luiz@financecontrol.app',
    displayName: 'Luiz',
  );
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);
  @override
  AuthUser? get currentUser => _user;
  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _user;
  @override
  Future<AuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async =>
      _user;
  @override
  Future<AuthUser> signInWithGoogle() async => _user;
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
  final _AiTestStore store;
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
    store.profileCtrl.add(profile);
  }

  @override
  Future<void> deleteUserData(String uid) async {}
}

class _FakeCategoryRepo implements CategoryRepository {
  _FakeCategoryRepo(this.store);
  final _AiTestStore store;
  @override
  Stream<List<CategoryEntity>> watchCategories(String userId) async* {
    yield List.unmodifiable(store.categories);
    yield* store.categoriesCtrl.stream;
  }

  @override
  Future<void> seedDefaultCategoriesIfNeeded(String userId) async {}

  @override
  Future<CategoryEntity> createCategory({
    required String userId,
    required CategoryEntity category,
  }) async {
    final created = category.copyWith(id: 'cat_new_${store.createdCategories.length + 1}');
    store.createdCategories.add(created);
    store.categories.add(created);
    store.categoriesCtrl.add(List.unmodifiable(store.categories));
    return created;
  }

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
  final _AiTestStore store;
  @override
  Stream<List<AccountEntity>> watchAccounts(String userId) async* {
    yield List.unmodifiable(store.accounts);
    yield* store.accountsCtrl.stream;
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
  }) async {
    store.createdTransfers.add({
      'src': sourceAccountId,
      'dst': destinationAccountId,
      'amountCents': amountCents,
      'description': description,
    });
  }
}

class _FakeTransactionRepo implements TransactionRepository {
  _FakeTransactionRepo(this.store);
  final _AiTestStore store;
  @override
  Stream<List<TransactionEntity>> watchTransactions(String userId) async* {
    yield List.unmodifiable(store.createdTransactions);
    yield* store.txCtrl.stream;
  }

  @override
  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  }) async {
    final saved = transaction.copyWith(
      id: 'tx_${store.createdTransactions.length + 1}',
    );
    store.createdTransactions.add(saved);
    store.txCtrl.add(List.unmodifiable(store.createdTransactions));
    return saved;
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
  final _AiTestStore store;
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
  Stream<List<InstallmentPlanEntity>> watchInstallmentPlans(String userId) =>
      Stream.value(const []);
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
  }) async {
    store.createdCardPurchases.add({
      'cardId': cardId,
      'categoryId': categoryId,
      'description': description,
      'totalAmountCents': totalAmountCents,
      'installmentCount': installmentCount,
    });
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
  }) async {
    store.paidInvoices.add({
      'invoiceId': invoiceId,
      'paymentAccountId': paymentAccountId,
    });
  }

  @override
  Future<void> refundOrCancelCardPurchase({
    required String userId,
    required String transactionId,
    bool cancelAllPlanInstallments = true,
  }) async {}
}

class _FakeRecurringRepo implements RecurringRepository {
  _FakeRecurringRepo(this.store);
  final _AiTestStore store;
  @override
  Stream<List<RecurringRuleEntity>> watchRules(String userId) =>
      Stream.value(const []);
  @override
  Future<RecurringRuleEntity> createRule({
    required String userId,
    required RecurringRuleEntity rule,
    DateTime? referenceDate,
  }) async {
    final created = rule.copyWith(id: 'rec_1');
    store.createdRecurringRules.add(created);
    return created;
  }

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

class _FakeAiRepository implements AiRepository {
  int sendCount = 0;
  late AiChatResult Function(String prompt) onSendText;
  late AiChatResult Function(List<int> bytes, String mimeType) onAnalyzeImage;

  @override
  Future<AiChatResult> sendTextPrompt({
    required String prompt,
    List<AiMessage> history = const [],
    List<String> availableCategories = const [],
    List<String> availableAccounts = const [],
    List<String> availableCards = const [],
  }) async {
    sendCount++;
    return onSendText(prompt);
  }

  @override
  Future<AiChatResult> analyzeReceiptImage({
    required List<int> imageBytes,
    required String mimeType,
    String? caption,
    List<String> availableCategories = const [],
    List<String> availableAccounts = const [],
    List<String> availableCards = const [],
  }) async {
    sendCount++;
    return onAnalyzeImage(imageBytes, mimeType);
  }

  @override
  Future<AiStatusResult> fetchStatus() async {
    return const AiStatusResult(
      quota: AiQuotaStatus(dailyLimit: 60, dailyUsed: 2, remainingToday: 58),
      aiAssistantEnabled: true,
      aiShareFinancialContext: true,
      modelName: 'gemini-3.8-flash',
    );
  }
}

class _FakeVoiceInputService implements VoiceInputService {
  String simulatedTranscript =
      'Hoje gastei 58,90 na farmácia no cartão Nubank';
  bool initializedResult = true;

  @override
  bool get isPlatformSupported => true;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String errorMessage)? onError,
  }) async =>
      initializedResult;

  @override
  Future<void> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
  }) async {
    onResult(simulatedTranscript, true);
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancelListening() async {}
}

class _FakeMediaInputService implements MediaInputService {
  PickedReceiptImage? nextImage;

  @override
  bool get supportsCameraCapture => true;

  @override
  Future<PickedReceiptImage?> captureFromCamera() async => nextImage;

  @override
  Future<PickedReceiptImage?> pickFromGallery() async => nextImage;
}

ProviderContainer _createAiContainer({
  required _AiTestStore store,
  required _FakeAiRepository aiRepo,
  _FakeVoiceInputService? voiceService,
  _FakeMediaInputService? mediaService,
}) {
  return ProviderContainer(
    overrides: [
      appBootstrapStateProvider.overrideWithValue(
        const AppBootstrapState(
          firebase: FirebaseBootstrapState(
            status: FirebaseConnectionStatus.connected,
            message: 'OK',
            projectId: 'finance-control-luizmgms',
          ),
          localStorageInitialized: false,
        ),
      ),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
      currentAuthUserProvider.overrideWithValue(_FakeAuthRepo._user),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepo(store)),
      categoryRepositoryProvider.overrideWithValue(_FakeCategoryRepo(store)),
      accountRepositoryProvider.overrideWithValue(_FakeAccountRepo(store)),
      transactionRepositoryProvider
          .overrideWithValue(_FakeTransactionRepo(store)),
      creditCardRepositoryProvider
          .overrideWithValue(_FakeCreditCardRepo(store)),
      recurringRepositoryProvider.overrideWithValue(_FakeRecurringRepo(store)),
      aiRepositoryProvider.overrideWithValue(aiRepo),
      if (voiceService != null)
        voiceInputServiceProvider.overrideWithValue(voiceService),
      if (mediaService != null)
        mediaInputServiceProvider.overrideWithValue(mediaService),
    ],
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('Stage 6 Unit & Controller Tests (AI Financial Assistant)', () {
    test(
        'interprets text expense & income, enforces manual confirm/cancel, prevents duplicate saves',
        () async {
      final store = _AiTestStore();
      final aiRepo = _FakeAiRepository()
        ..onSendText = (prompt) => AiChatResult(
              quota: const AiQuotaStatus(
                dailyLimit: 60,
                dailyUsed: 1,
                remainingToday: 59,
              ),
              message: AiMessage(
                id: 'ai_exp_1',
                role: AiMessageRole.assistant,
                content: 'Identifiquei uma despesa no almoço.',
                createdAt: DateTime(2026, 11, 22),
                intent: 'transaction_proposal',
                suggestion: AiTransactionSuggestion(
                  success: true,
                  transactionType: 'expense',
                  description: 'Almoço executivo',
                  amountCents: 4500,
                  currency: 'BRL',
                  date: DateTime(2026, 11, 22),
                  categorySuggestion: 'Alimentação',
                  accountName: 'Conta Corrente',
                  confidence: 0.95,
                  requiresConfirmation: true,
                ),
              ),
            );

      final container = _createAiContainer(store: store, aiRepo: aiRepo);
      addTearDown(() {
        container.dispose();
        store.dispose();
      });

      container.listen(aiAssistantControllerProvider, (_, __) {});
      await container.read(userProfileProvider.future);
      await container.read(categoriesStreamProvider.future);
      await container.read(accountsStreamProvider.future);
      await container.read(creditCardsStreamProvider.future);

      final controller = container.read(aiAssistantControllerProvider.notifier);
      await controller.sendTextMessage('Gastei 45 reais no almoço');

      // Regra fundamental: absolutamente nada é salvo antes da confirmação explícita.
      expect(store.createdTransactions, isEmpty);

      final msg = container.read(aiAssistantControllerProvider).messages.last;
      expect(msg.suggestion?.requiresConfirmation, isTrue);
      expect(msg.suggestion?.categoryId, 'cat_food');
      expect(msg.suggestion?.accountId, 'acc_chk');

      final savedFirst = await controller.confirmAndSaveSuggestion(msg.id);
      expect(savedFirst, isTrue);
      expect(store.createdTransactions.length, 1);
      expect(store.createdTransactions.first.amountCents, 4500);
      expect(store.createdTransactions.first.kind, TransactionKind.expense);

      // Proteção anti-duplicidade em segundo clique no mesmo cartão já confirmado.
      final savedSecond = await controller.confirmAndSaveSuggestion(msg.id);
      expect(savedSecond, isFalse);
      expect(store.createdTransactions.length, 1);

      // Receita com criação opcional de nova categoria após confirmação + cancelamento separado.
      aiRepo.onSendText = (_) => AiChatResult(
            quota: const AiQuotaStatus(
              dailyLimit: 60,
              dailyUsed: 2,
              remainingToday: 58,
            ),
            message: AiMessage(
              id: 'ai_inc_1',
              role: AiMessageRole.assistant,
              content: 'Identifiquei uma receita.',
              createdAt: DateTime(2026, 11, 22),
              suggestion: AiTransactionSuggestion(
                success: true,
                transactionType: 'income',
                description: 'Consultoria',
                amountCents: 80000,
                currency: 'BRL',
                date: DateTime(2026, 11, 22),
                categorySuggestion: 'Consultoria Tech',
                categoryIsNew: true,
                accountName: 'Conta Corrente',
                confidence: 0.91,
              ),
            ),
          );

      await controller.sendTextMessage('Recebi 800 reais de consultoria');
      final incMsg =
          container.read(aiAssistantControllerProvider).messages.last;
      expect(store.createdCategories, isEmpty);

      final incOk = await controller.confirmAndSaveSuggestion(incMsg.id);
      expect(incOk, isTrue);
      expect(store.createdCategories.length, 1);
      expect(store.createdTransactions.length, 2);
      expect(store.createdTransactions.last.kind, TransactionKind.income);
    });

    test(
        'voice dictation lets user review transcript before sending and card installments & invoice payments route cleanly',
        () async {
      final store = _AiTestStore();
      final voice = _FakeVoiceInputService();
      final aiRepo = _FakeAiRepository()
        ..onSendText = (prompt) => AiChatResult(
              quota: const AiQuotaStatus(
                dailyLimit: 60,
                dailyUsed: 1,
                remainingToday: 59,
              ),
              message: AiMessage(
                id: 'ai_card_1',
                role: AiMessageRole.assistant,
                content: 'Compra parcelada identificada no Nubank.',
                createdAt: DateTime(2026, 11, 22),
                suggestion: AiTransactionSuggestion(
                  success: true,
                  transactionType: 'card_purchase',
                  description: 'Farmácia',
                  amountCents: 15000,
                  currency: 'BRL',
                  date: DateTime(2026, 11, 22),
                  categorySuggestion: 'Alimentação',
                  creditCardName: 'Nubank',
                  installments: 3,
                  confidence: 0.93,
                ),
              ),
            );

      final container = _createAiContainer(
        store: store,
        aiRepo: aiRepo,
        voiceService: voice,
      );
      addTearDown(() {
        container.dispose();
        store.dispose();
      });

      container.listen(aiAssistantControllerProvider, (_, __) {});
      await container.read(userProfileProvider.future);
      await container.read(categoriesStreamProvider.future);
      await container.read(accountsStreamProvider.future);
      await container.read(creditCardsStreamProvider.future);
      await container.read(invoicesStreamProvider.future);

      final controller = container.read(aiAssistantControllerProvider.notifier);
      String capturedTranscript = '';
      final started = await controller.startVoiceInput(
        onTranscriptChanged: (t) => capturedTranscript = t,
      );

      expect(started, isTrue);
      expect(capturedTranscript, voice.simulatedTranscript);
      // Ditado não envia sozinho para o Gemini nem grava nada sem o usuário revisar.
      expect(aiRepo.sendCount, 0);

      await controller.sendTextMessage(capturedTranscript);
      expect(aiRepo.sendCount, 1);
      final cardMsg =
          container.read(aiAssistantControllerProvider).messages.last;
      expect(cardMsg.suggestion?.creditCardId, 'card_nu');
      expect(cardMsg.suggestion?.installments, 3);

      final savedPurchase =
          await controller.confirmAndSaveSuggestion(cardMsg.id);
      expect(savedPurchase, isTrue);
      expect(store.createdCardPurchases.length, 1);
      expect(store.createdCardPurchases.first['installmentCount'], 3);
      expect(store.createdTransactions, isEmpty);

      // Pagamento de fatura usa CreditCardController.payInvoice (sem duplicar despesa)
      aiRepo.onSendText = (_) => AiChatResult(
            quota: const AiQuotaStatus(
              dailyLimit: 60,
              dailyUsed: 2,
              remainingToday: 58,
            ),
            message: AiMessage(
              id: 'ai_inv_pay',
              role: AiMessageRole.assistant,
              content: 'Pagamento da fatura do cartão Nubank.',
              createdAt: DateTime(2026, 11, 22),
              suggestion: AiTransactionSuggestion(
                success: true,
                transactionType: 'invoice_payment',
                description: 'Pagamento fatura Nubank',
                amountCents: 120000,
                currency: 'BRL',
                date: DateTime(2026, 11, 22),
                creditCardName: 'Nubank',
                accountName: 'Conta Corrente',
              ),
            ),
          );

      await controller.sendTextMessage('Paguei a fatura do Nubank na Conta Corrente');
      final payMsg = container.read(aiAssistantControllerProvider).messages.last;
      final paidOk = await controller.confirmAndSaveSuggestion(payMsg.id);
      expect(paidOk, isTrue);
      expect(store.paidInvoices.length, 1);
      expect(store.paidInvoices.first['invoiceId'], 'card_nu_2026_11');
      expect(store.createdTransactions, isEmpty);
    });

    test(
        'receipt multimodal extraction splits multiple items, detects duplicates, and rejects incomplete/disabled AI',
        () async {
      final store = _AiTestStore();
      final media = _FakeMediaInputService()
        ..nextImage = PickedReceiptImage(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          mimeType: 'image/jpeg',
          fileName: 'cupom_fiscal.jpg',
        );

      final aiRepo = _FakeAiRepository()
        ..onAnalyzeImage = (bytes, mime) => AiChatResult(
              quota: const AiQuotaStatus(
                dailyLimit: 60,
                dailyUsed: 1,
                remainingToday: 59,
              ),
              message: AiMessage(
                id: 'ai_rcpt_1',
                role: AiMessageRole.assistant,
                content: 'Extraí os dados do cupom fiscal.',
                createdAt: DateTime(2026, 11, 22),
                suggestion: AiTransactionSuggestion(
                  success: true,
                  transactionType: 'expense',
                  description: 'Supermercado Central',
                  merchantName: 'Supermercado Central',
                  amountCents: 12000,
                  currency: 'BRL',
                  date: DateTime(2026, 11, 22),
                  categorySuggestion: 'Alimentação',
                  accountName: 'Conta Corrente',
                  extractedItems: const [
                    AiReceiptLineItem(
                      description: 'Hortifruti',
                      amountCents: 4500,
                      categorySuggestion: 'Alimentação',
                    ),
                    AiReceiptLineItem(
                      description: 'Limpeza',
                      amountCents: 7500,
                      categorySuggestion: 'Alimentação',
                    ),
                  ],
                ),
              ),
            );

      final container = _createAiContainer(
        store: store,
        aiRepo: aiRepo,
        mediaService: media,
      );
      addTearDown(() {
        container.dispose();
        store.dispose();
      });

      container.listen(aiAssistantControllerProvider, (_, __) {});
      await container.read(userProfileProvider.future);
      await container.read(categoriesStreamProvider.future);
      await container.read(accountsStreamProvider.future);
      await container.read(creditCardsStreamProvider.future);

      final controller = container.read(aiAssistantControllerProvider.notifier);
      await controller.pickAndAnalyzeReceipt(fromCamera: false);

      final rcptMsg = container.read(aiAssistantControllerProvider).messages.last;
      expect(rcptMsg.suggestion?.hasMultipleItems, isTrue);

      // Usuário escolhe separar os 2 itens em lançamentos individuais
      controller.updateSuggestion(
        rcptMsg.id,
        rcptMsg.suggestion!.copyWith(splitIntoItems: true),
      );

      final splitOk = await controller.confirmAndSaveSuggestion(rcptMsg.id);
      expect(splitOk, isTrue);
      expect(store.createdTransactions.length, 2);
      expect(
        store.createdTransactions.map((t) => t.amountCents).toList(),
        [4500, 7500],
      );

      // Detecção local de duplicidade se outro gasto igual aparecer em seguida
      final dupWarning = AiSuggestionValidator.findPotentialDuplicateWarning(
        suggestion: AiTransactionSuggestion(
          success: true,
          transactionType: 'expense',
          description: 'Hortifruti',
          amountCents: 4500,
          currency: 'BRL',
          date: DateTime(2026, 11, 22),
        ),
        existingTransactions: store.createdTransactions,
      );
      expect(dupWarning, isNotNull);

      // Proposta incompleta sem conta ou valor não é salva
      final incomplete = AiTransactionSuggestion.tryFromResponseJson(const {
        'success': false,
        'transaction_type': 'expense',
        'description': 'Recibo borrado',
        'amount_cents': 0,
        'date': '2026-11-22',
        'missing_information': ['Valor ilegível'],
      });
      expect(incomplete, isNotNull);
      expect(incomplete!.success, isFalse);
      final readyErr = AiSuggestionValidator.validateReadyToConfirm(
        incomplete,
        accounts: store.accounts,
        cards: store.cards,
        categories: store.categories,
      );
      expect(readyErr, isNotNull);

      // Cancelamento preserva histórico sem salvar
      await controller.pickAndAnalyzeReceipt(fromCamera: true);
      final cancelMsg =
          container.read(aiAssistantControllerProvider).messages.last;
      controller.cancelSuggestion(cancelMsg.id);
      expect(store.createdTransactions.length, 2);

      // Desativação por privacidade bloqueia envios
      store.profile = store.profile.copyWith(aiAssistantEnabled: false);
      store.profileCtrl.add(store.profile);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final countBeforeDisabled = aiRepo.sendCount;
      await controller.sendTextMessage('Teste bloqueado');
      expect(aiRepo.sendCount, countBeforeDisabled);
    });
  });

  group('Stage 6 Widget Tests (Desktop + Mobile 360x780)', () {
    testWidgets(
        'AiAssistantPage renders cleanly at 360x780 without overflow and executes confirm & edit flow',
        (tester) async {
      final store = _AiTestStore();
      final aiRepo = _FakeAiRepository()
        ..onSendText = (prompt) => AiChatResult(
              quota: const AiQuotaStatus(
                dailyLimit: 60,
                dailyUsed: 3,
                remainingToday: 57,
              ),
              message: AiMessage(
                id: 'widget_msg_1',
                role: AiMessageRole.assistant,
                content: 'Proposta pronta para sua confirmação:',
                createdAt: DateTime(2026, 11, 22),
                toolsUsed: const ['get_monthly_summary'],
                suggestion: AiTransactionSuggestion(
                  success: true,
                  transactionType: 'expense',
                  description: 'Supermercado Bairro',
                  amountCents: 18540,
                  currency: 'BRL',
                  date: DateTime(2026, 11, 22),
                  categorySuggestion: 'Alimentação',
                  accountName: 'Conta Corrente',
                  confidence: 0.92,
                ),
              ),
            );

      final container = _createAiContainer(store: store, aiRepo: aiRepo);
      container.listen(aiAssistantControllerProvider, (_, __) {});
      await container.read(userProfileProvider.future);
      await container.read(categoriesStreamProvider.future);
      await container.read(accountsStreamProvider.future);
      await container.read(creditCardsStreamProvider.future);

      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        container.dispose();
        store.dispose();
      });

      await tester.binding.setSurfaceSize(const Size(360, 780));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AiAssistantPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assistente Financeiro IA'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Envia prompt rápido por toque no chip
      await tester.ensureVisible(find.text('Gastei R\$ 45 no almoço'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gastei R\$ 45 no almoço'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Supermercado Bairro'));
      await tester.pumpAndSettle();
      expect(find.text('Supermercado Bairro'), findsOneWidget);
      expect(find.text('Confirmar e salvar'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(store.createdTransactions, isEmpty);

      // Abre diálogo de edição explícita
      await tester.ensureVisible(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar proposta da IA'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Supermercado Bairro'),
        'Supermercado Editado',
      );
      await tester.tap(find.text('Aplicar edição'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Supermercado Editado'));
      await tester.pumpAndSettle();
      expect(find.text('Supermercado Editado'), findsOneWidget);
      expect(store.createdTransactions, isEmpty);

      // Confirma explicitamente
      await tester.ensureVisible(find.text('Confirmar e salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar e salvar'));
      await tester.pumpAndSettle();

      expect(store.createdTransactions.length, 1);
      expect(store.createdTransactions.first.description, 'Supermercado Editado');
      expect(find.text('Confirmado e salvo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test(
        'GeminiDatasource & AiRepositoryImpl preserve nested Map<Object?, Object?> suggestions and quota from MethodChannel',
        () async {
      final rawChannelPayload = <String, dynamic>{
        'id': 'msg_channel_1',
        'intent': 'transaction_proposal',
        'reply': 'Revise os detalhes e confirme abaixo.',
        'model': 'gemini-3.8-flash',
        'tools_used': <Object?>['get_monthly_summary'],
        // Simula exatamente o mapa não-tipado retornado por cloud_functions no Android/Web.
        'suggestion': <Object?, Object?>{
          'success': true,
          'transaction_type': 'expense',
          'description': 'Almoço Executivo',
          'amount_cents': 4500,
          'currency': 'BRL',
          'date': '2026-11-22',
          'category_suggestion': 'Alimentação',
          'requires_confirmation': false,
          'missing_information': <Object?>[],
          'extracted_items': <Object?>[
            <Object?, Object?>{
              'description': 'Prato feito',
              'amount_cents': 4500,
            },
          ],
        },
        'quota': <Object?, Object?>{
          'dailyLimit': 60,
          'dailyUsed': 4,
          'remainingToday': 56,
        },
      };

      final normalized =
          GeminiDatasource.normalizePayloadMap(rawChannelPayload);
      expect(normalized['suggestion'], isA<Map<String, dynamic>>());

      final ds = _FakeChannelDatasource(rawChannelPayload);
      final repo = AiRepositoryImpl(ds);
      final result = await repo.sendTextPrompt(prompt: 'Gastei R\$ 45 no almoço');

      expect(result.message.suggestion, isNotNull);
      expect(result.message.suggestion!.amountCents, 4500);
      expect(result.message.suggestion!.requiresConfirmation, isTrue);
      expect(result.message.suggestion!.extractedItems.length, 1);
      expect(result.quota.remainingToday, 56);
    });

    test(
        'SpeechToTextVoiceInputService.resolvePortugueseLocaleId prioritizes pt-BR over en-US default',
        () {
      expect(
        SpeechToTextVoiceInputService.resolvePortugueseLocaleId(
          [LocaleName('en-US', 'English (US)')],
        ),
        'pt-BR',
      );
      expect(
        SpeechToTextVoiceInputService.resolvePortugueseLocaleId(
          [
            LocaleName('en_US', 'English'),
            LocaleName('pt_BR', 'Português (Brasil)'),
          ],
          preferHyphen: true,
        ),
        'pt-BR',
      );
      expect(
        SpeechToTextVoiceInputService.resolvePortugueseLocaleId(
          [
            LocaleName('pt_PT', 'Português (Portugal)'),
            LocaleName('pt_BR', 'Português (Brasil)'),
          ],
          preferHyphen: true,
        ),
        'pt-BR',
      );
      expect(
        SpeechToTextVoiceInputService.resolvePortugueseLocaleId(
          [LocaleName('pt_PT', 'Português (Portugal)')],
          preferHyphen: true,
        ),
        'pt-PT',
      );
    });

    testWidgets(
        'Tapping Confirmar or typing confirmo with missing account opens Edit dialog so user never gets stuck',
        (tester) async {
      final store = _AiTestStore();
      final aiRepo = _FakeAiRepository()
        ..onSendText = (_) => AiChatResult(
              quota: const AiQuotaStatus(
                dailyLimit: 60,
                dailyUsed: 1,
                remainingToday: 59,
              ),
              message: AiMessage(
                id: 'missing_acc_msg',
                role: AiMessageRole.assistant,
                content: 'Revise e escolha a conta antes de salvar.',
                createdAt: DateTime(2026, 11, 22),
                suggestion: AiTransactionSuggestion(
                  success: true,
                  transactionType: 'expense',
                  description: 'Almoço sem conta',
                  amountCents: 4500,
                  currency: 'BRL',
                  date: DateTime(2026, 11, 22),
                  categorySuggestion: 'Alimentação',
                  // Conta propositalmente omitida pelo usuário no primeiro comando
                  accountName: null,
                ),
              ),
            );

      final container = _createAiContainer(store: store, aiRepo: aiRepo);
      await container.read(categoriesStreamProvider.future);
      await container.read(accountsStreamProvider.future);
      await container.read(creditCardsStreamProvider.future);

      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        container.dispose();
        store.dispose();
      });

      await tester.binding.setSurfaceSize(const Size(360, 780));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AiAssistantPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Gastei R\$ 45 no almoço'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gastei R\$ 45 no almoço'));
      await tester.pumpAndSettle();

      expect(find.text('Almoço sem conta'), findsOneWidget);

      // Digitar "confirmo" não deve gerar novo ciclo na IA, e sim abrir o diálogo
      // para completar a conta financeira faltante.
      await tester.enterText(find.byType(TextField), 'confirmo');
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pumpAndSettle();

      expect(aiRepo.sendCount, 1);
      expect(find.text('Editar proposta da IA'), findsOneWidget);

      // Tentar confirmar sem conta escolhida valida dentro do próprio diálogo
      final dialogConfirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirmar e salvar'),
      );
      await tester.tap(dialogConfirmBtn);
      await tester.pumpAndSettle();
      expect(find.text('Selecione a conta financeira'), findsOneWidget);

      // Seleciona a conta financeira e confirma direto pelo diálogo
      await tester.ensureVisible(find.text('Conta financeira'));
      await tester.tap(find.text('Conta financeira'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conta Corrente').last);
      await tester.pumpAndSettle();

      await tester.tap(dialogConfirmBtn);
      await tester.pumpAndSettle();

      expect(store.createdTransactions.length, 1);
      expect(store.createdTransactions.first.amountCents, 4500);
      expect(store.createdTransactions.first.accountId, 'acc_chk');
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeChannelDatasource extends GeminiDatasource {
  _FakeChannelDatasource(this.payload);
  final Map<String, dynamic> payload;

  @override
  Future<Map<String, dynamic>> invokeAssistantEndpoint({
    required Map<String, dynamic> payload,
  }) async {
    return this.payload;
  }
}
