import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../accounts/application/controllers/account_controller.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../credit_cards/application/controllers/credit_card_controller.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../../credit_cards/domain/entities/invoice_entity.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../recurring/application/controllers/recurring_controller.dart';
import '../../../recurring/domain/entities/recurring_rule_entity.dart';
import '../../../transactions/application/controllers/transaction_controller.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../data/datasources/media_input_service.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_quota_status.dart';
import '../../domain/entities/ai_transaction_suggestion.dart';
import '../../domain/services/ai_suggestion_validator.dart';
import '../providers/ai_providers.dart';

class AiAssistantState extends Equatable {
  const AiAssistantState({
    this.messages = const [],
    this.isProcessing = false,
    this.isSavingSuggestion = false,
    this.isListeningVoice = false,
    this.voiceDraftTranscript = '',
    this.quota = const AiQuotaStatus(),
    this.activeModelName = 'gemini-3.8-flash',
    this.aiAssistantEnabled = true,
    this.aiShareFinancialContext = true,
    this.errorMessage,
    this.successMessage,
  });

  final List<AiMessage> messages;
  final bool isProcessing;
  final bool isSavingSuggestion;
  final bool isListeningVoice;
  final String voiceDraftTranscript;
  final AiQuotaStatus quota;
  final String activeModelName;
  final bool aiAssistantEnabled;
  final bool aiShareFinancialContext;
  final String? errorMessage;
  final String? successMessage;

  AiAssistantState copyWith({
    List<AiMessage>? messages,
    bool? isProcessing,
    bool? isSavingSuggestion,
    bool? isListeningVoice,
    String? voiceDraftTranscript,
    AiQuotaStatus? quota,
    String? activeModelName,
    bool? aiAssistantEnabled,
    bool? aiShareFinancialContext,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      isSavingSuggestion: isSavingSuggestion ?? this.isSavingSuggestion,
      isListeningVoice: isListeningVoice ?? this.isListeningVoice,
      voiceDraftTranscript: voiceDraftTranscript ?? this.voiceDraftTranscript,
      quota: quota ?? this.quota,
      activeModelName: activeModelName ?? this.activeModelName,
      aiAssistantEnabled: aiAssistantEnabled ?? this.aiAssistantEnabled,
      aiShareFinancialContext:
          aiShareFinancialContext ?? this.aiShareFinancialContext,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isProcessing,
        isSavingSuggestion,
        isListeningVoice,
        voiceDraftTranscript,
        quota,
        activeModelName,
        aiAssistantEnabled,
        aiShareFinancialContext,
        errorMessage,
        successMessage,
      ];
}

/// Controller conversacional e multimodal do Assistente Financeiro IA (Módulo 23).
/// Regra inviolável: nenhum lançamento é persistido sem ação explícita do usuário em Confirmar.
class AiAssistantController extends Notifier<AiAssistantState> {
  @override
  AiAssistantState build() {
    ref.listen<AsyncValue<UserProfile?>>(
      userProfileProvider,
      (_, next) {
        final profile = next.valueOrNull;
        if (profile == null) return;
        state = state.copyWith(
          aiAssistantEnabled: profile.aiAssistantEnabled,
          aiShareFinancialContext: profile.aiShareFinancialContext,
        );
      },
    );

    final initialProfile = ref.read(userProfileProvider).valueOrNull;
    return AiAssistantState(
      aiAssistantEnabled: initialProfile?.aiAssistantEnabled ?? true,
      aiShareFinancialContext: initialProfile?.aiShareFinancialContext ?? true,
    );
  }

  void clearBanners() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void clearConversation() {
    state = state.copyWith(
      messages: const [],
      clearError: true,
      clearSuccess: true,
      voiceDraftTranscript: '',
    );
  }

  Future<void> loadStatus() async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return;
    try {
      final status = await ref.read(aiRepositoryProvider).fetchStatus();
      state = state.copyWith(
        quota: status.quota,
        activeModelName: status.modelName,
        aiAssistantEnabled: status.aiAssistantEnabled,
        aiShareFinancialContext: status.aiShareFinancialContext,
      );
    } catch (_) {
      // Silencioso em modo offline ou pré-deploy; erros detalhados aparecem no envio.
    }
  }

  Future<void> sendTextMessage(String rawPrompt) async {
    final prompt = rawPrompt.trim();
    if (prompt.isEmpty || state.isProcessing) return;

    if (!state.aiAssistantEnabled) {
      state = state.copyWith(
        errorMessage:
            'O Assistente Financeiro IA está desativado nas configurações de privacidade.',
      );
      return;
    }

    final userMsg = AiMessage(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      role: AiMessageRole.user,
      content: prompt,
      createdAt: DateTime.now(),
    );

    final historySnapshot = state.messages;
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isProcessing: true,
      voiceDraftTranscript: '',
      clearError: true,
      clearSuccess: true,
    );

    try {
      final categories = ref.read(activeCategoriesProvider);
      final accounts = ref.read(activeAccountsProvider);
      final cards = ref.read(activeCreditCardsProvider);

      final result = await ref.read(aiRepositoryProvider).sendTextPrompt(
            prompt: prompt,
            history: historySnapshot,
            availableCategories:
                categories.map((c) => c.name).toList(growable: false),
            availableAccounts:
                accounts.map((a) => a.name).toList(growable: false),
            availableCards: cards.map((c) => c.name).toList(growable: false),
          );

      final enriched = _enrichAssistantMessage(result.message);
      state = state.copyWith(
        messages: [...state.messages, enriched],
        isProcessing: false,
        quota: result.quota,
        activeModelName: result.message.modelName ?? state.activeModelName,
      );
    } on Failure catch (failure) {
      _appendErrorMessage(failure.message);
    } catch (error) {
      _appendErrorMessage(
        formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível consultar o Assistente IA.',
        ),
      );
    }
  }

  Future<bool> startVoiceInput({
    required void Function(String recognizedText) onTranscriptChanged,
  }) async {
    if (!state.aiAssistantEnabled) {
      state = state.copyWith(
        errorMessage:
            'O Assistente Financeiro IA está desativado nas configurações de privacidade.',
      );
      return false;
    }

    final voiceService = ref.read(voiceInputServiceProvider);
    if (!voiceService.isPlatformSupported) {
      state = state.copyWith(
        errorMessage:
            'Captura de microfone nativa indisponível nesta plataforma desktop. Digite ou use texto.',
      );
      return false;
    }

    try {
      final ready = await voiceService.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            state = state.copyWith(isListeningVoice: false);
          }
        },
        onError: (err) {
          state = state.copyWith(
            isListeningVoice: false,
            errorMessage: 'Erro no reconhecimento de voz: $err',
          );
        },
      );
      if (!ready) {
        state = state.copyWith(
          isListeningVoice: false,
          errorMessage:
              'Permissão de microfone negada ou reconhecimento de voz indisponível.',
        );
        return false;
      }

      state = state.copyWith(
        isListeningVoice: true,
        clearError: true,
      );

      await voiceService.startListening(
        onResult: (text, isFinal) {
          onTranscriptChanged(text);
          state = state.copyWith(
            voiceDraftTranscript: text,
            isListeningVoice: !isFinal,
          );
        },
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isListeningVoice: false,
        errorMessage: 'Não foi possível iniciar o reconhecimento de voz: $error',
      );
      return false;
    }
  }

  Future<void> stopVoiceInput() async {
    await ref.read(voiceInputServiceProvider).stopListening();
    state = state.copyWith(isListeningVoice: false);
  }

  Future<void> pickAndAnalyzeReceipt({
    required bool fromCamera,
    String? caption,
  }) async {
    if (state.isProcessing) return;
    if (!state.aiAssistantEnabled) {
      state = state.copyWith(
        errorMessage:
            'O Assistente Financeiro IA está desativado nas configurações de privacidade.',
      );
      return;
    }

    try {
      final media = ref.read(mediaInputServiceProvider);
      final picked = fromCamera
          ? await media.captureFromCamera()
          : await media.pickFromGallery();
      if (picked == null) return;

      await analyzeReceiptImage(picked, caption: caption);
    } on Failure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    } catch (error) {
      state = state.copyWith(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível selecionar a imagem.',
        ),
      );
    }
  }

  Future<void> analyzeReceiptImage(
    PickedReceiptImage image, {
    String? caption,
  }) async {
    if (state.isProcessing) return;

    final userMsg = AiMessage(
      id: 'u_img_${DateTime.now().microsecondsSinceEpoch}',
      role: AiMessageRole.user,
      content: (caption ?? '').trim().isNotEmpty
          ? caption!.trim()
          : 'Analisar documento: ${image.fileName}',
      createdAt: DateTime.now(),
      attachmentLabel: image.fileName,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isProcessing: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final categories = ref.read(activeCategoriesProvider);
      final accounts = ref.read(activeAccountsProvider);
      final cards = ref.read(activeCreditCardsProvider);

      final result = await ref.read(aiRepositoryProvider).analyzeReceiptImage(
            imageBytes: image.bytes,
            mimeType: image.mimeType,
            caption: caption,
            availableCategories:
                categories.map((c) => c.name).toList(growable: false),
            availableAccounts:
                accounts.map((a) => a.name).toList(growable: false),
            availableCards: cards.map((c) => c.name).toList(growable: false),
          );

      final enriched = _enrichAssistantMessage(result.message);
      state = state.copyWith(
        messages: [...state.messages, enriched],
        isProcessing: false,
        quota: result.quota,
        activeModelName: result.message.modelName ?? state.activeModelName,
      );
    } on Failure catch (failure) {
      _appendErrorMessage(failure.message);
    } catch (error) {
      _appendErrorMessage(
        formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível analisar a imagem.',
        ),
      );
    }
  }

  /// Atualiza a proposta de uma mensagem após edição explícita do usuário.
  void updateSuggestion(
    String messageId,
    AiTransactionSuggestion updatedSuggestion,
  ) {
    final existingTxs =
        ref.read(transactionsStreamProvider).valueOrNull ?? const [];
    final categories = ref.read(activeCategoriesProvider);
    final accounts = ref.read(activeAccountsProvider);
    final cards = ref.read(activeCreditCardsProvider);

    final refreshed = updatedSuggestion.copyWith(
      clearPotentialDuplicateWarning: true,
    );
    final enriched = AiSuggestionValidator.enrichWithLocalCatalog(
      suggestion: refreshed,
      categories: categories,
      accounts: accounts,
      cards: cards,
      existingTransactions: existingTxs,
    );

    state = state.copyWith(
      messages: state.messages
          .map(
            (m) => m.id == messageId ? m.copyWith(suggestion: enriched) : m,
          )
          .toList(growable: false),
      clearError: true,
    );
  }

  void cancelSuggestion(String messageId) {
    final updated = state.messages
        .map(
          (m) => m.id == messageId && m.resolution == AiSuggestionResolution.pending
              ? m.copyWith(resolution: AiSuggestionResolution.canceled)
              : m,
        )
        .toList(growable: false);

    state = state.copyWith(
      messages: [
        ...updated,
        AiMessage(
          id: 'sys_cancel_${DateTime.now().microsecondsSinceEpoch}',
          role: AiMessageRole.system,
          content: 'Proposta cancelada. Nenhum lançamento foi gravado.',
          createdAt: DateTime.now(),
        ),
      ],
      clearError: true,
    );
  }

  /// Persiste a proposta EXCLUSIVAMENTE após clique explícito do usuário em Confirmar,
  /// roteando pelos controllers e regras de negócio convencionais de cada módulo.
  Future<bool> confirmAndSaveSuggestion(String messageId) async {
    if (state.isSavingSuggestion) return false;

    final targetIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (targetIndex < 0) return false;

    final targetMsg = state.messages[targetIndex];
    final suggestion = targetMsg.suggestion;
    if (suggestion == null ||
        targetMsg.resolution != AiSuggestionResolution.pending) {
      return false;
    }

    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Faça login para salvar lançamentos confirmados.',
      );
      return false;
    }

    final categories = ref.read(activeCategoriesProvider);
    final accounts = ref.read(activeAccountsProvider);
    final cards = ref.read(activeCreditCardsProvider);
    final openInvoices = ref.read(openInvoicesProvider);

    final itemsToSave =
        suggestion.splitIntoItems && suggestion.hasMultipleItems
            ? AiSuggestionValidator.expandSplitItems(suggestion)
            : <AiTransactionSuggestion>[suggestion];

    for (final item in itemsToSave) {
      final validationError = AiSuggestionValidator.validateReadyToConfirm(
        item,
        accounts: accounts,
        cards: cards,
        categories: categories,
      );
      if (validationError != null) {
        state = state.copyWith(errorMessage: validationError);
        return false;
      }
    }

    state = state.copyWith(
      isSavingSuggestion: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final createdCategoryCache = <String, String>{};
      var savedCount = 0;

      for (final item in itemsToSave) {
        final ok = await _executeSingleConfirmedSave(
          userId: user.uid,
          item: item,
          categories: categories,
          accounts: accounts,
          cards: cards,
          openInvoices: openInvoices,
          createdCategoryCache: createdCategoryCache,
        );
        if (!ok) {
          state = state.copyWith(isSavingSuggestion: false);
          return false;
        }
        savedCount++;
      }

      final nextMessages = state.messages
          .map(
            (m) => m.id == messageId
                ? m.copyWith(resolution: AiSuggestionResolution.confirmed)
                : m,
          )
          .toList(growable: false);

      final successNote = savedCount > 1
          ? '$savedCount lançamentos individuais confirmados e salvos com sucesso.'
          : 'Lançamento "${suggestion.description}" confirmado e salvo com sucesso.';

      state = state.copyWith(
        messages: [
          ...nextMessages,
          AiMessage(
            id: 'sys_saved_${DateTime.now().microsecondsSinceEpoch}',
            role: AiMessageRole.system,
            content: successNote,
            createdAt: DateTime.now(),
          ),
        ],
        isSavingSuggestion: false,
        successMessage: successNote,
      );
      return true;
    } on Failure catch (failure) {
      state = state.copyWith(
        isSavingSuggestion: false,
        errorMessage: failure.message,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isSavingSuggestion: false,
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível salvar o lançamento confirmado.',
        ),
      );
      return false;
    }
  }

  Future<bool> _executeSingleConfirmedSave({
    required String userId,
    required AiTransactionSuggestion item,
    required List<CategoryEntity> categories,
    required List<AccountEntity> accounts,
    required List<CreditCardEntity> cards,
    required List<InvoiceEntity> openInvoices,
    required Map<String, String> createdCategoryCache,
  }) async {
    final type = item.transactionType;
    final now = DateTime.now();
    final isMidnightToday = item.date.hour == 0 &&
        item.date.minute == 0 &&
        item.date.second == 0 &&
        item.date.year == now.year &&
        item.date.month == now.month &&
        item.date.day == now.day;
    final effectiveDate =
        isMidnightToday ? DateFormatter.preserveTime(item.date, now) : item.date;

    if (type == 'transfer') {
      final src = AiSuggestionValidator.matchAccount(
        accountId: item.accountId,
        accountName: item.accountName,
        accounts: accounts,
      )!;
      final dst = AiSuggestionValidator.matchAccount(
        accountId: item.destinationAccountId,
        accountName: item.destinationAccountName,
        accounts: accounts,
      )!;
      final ok = await ref
          .read(accountControllerProvider.notifier)
          .transferBetweenAccounts(
            sourceAccountId: src.id,
            destinationAccountId: dst.id,
            amountCents: item.amountCents,
            transferDate: effectiveDate,
            description: item.description,
            notes: _composeNotes(item),
          );
      if (!ok) {
        state = state.copyWith(
          errorMessage: ref.read(accountControllerProvider).errorMessage,
        );
      }
      return ok;
    }

    if (type == 'invoice_payment') {
      final card = AiSuggestionValidator.matchCard(
        cardId: item.creditCardId,
        cardName: item.creditCardName,
        cards: cards,
      )!;
      final acc = AiSuggestionValidator.matchAccount(
        accountId: item.accountId,
        accountName: item.accountName,
        accounts: accounts,
      )!;
      final matchingInvoices = openInvoices
          .where((inv) => inv.cardId == card.id && inv.remainingAmountCents > 0)
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      if (matchingInvoices.isEmpty) {
        state = state.copyWith(
          errorMessage:
              'Nenhuma fatura em aberto encontrada para o cartão ${card.name}.',
        );
        return false;
      }
      final ok = await ref.read(creditCardControllerProvider.notifier).payInvoice(
            invoiceId: matchingInvoices.first.id,
            paymentAccountId: acc.id,
            paymentDate: effectiveDate,
          );
      if (!ok) {
        state = state.copyWith(
          errorMessage: ref.read(creditCardControllerProvider).errorMessage,
        );
      }
      return ok;
    }

    // Resolve ou cria categoria apenas após confirmação explícita do usuário.
    final resolvedCategoryId = await _resolveOrCreateCategoryId(
      userId: userId,
      item: item,
      categories: categories,
      createdCategoryCache: createdCategoryCache,
    );
    if (resolvedCategoryId == null) {
      state = state.copyWith(
        errorMessage: 'Não foi possível resolver ou criar a categoria.',
      );
      return false;
    }

    if (type == 'card_purchase') {
      final card = AiSuggestionValidator.matchCard(
        cardId: item.creditCardId,
        cardName: item.creditCardName,
        cards: cards,
      )!;
      final ok = await ref
          .read(creditCardControllerProvider.notifier)
          .recordCardPurchase(
            cardId: card.id,
            categoryId: resolvedCategoryId,
            description: item.description,
            totalAmountCents: item.amountCents,
            purchaseDate: effectiveDate,
            totalInstallments: item.installments,
            notes: _composeNotes(item),
          );
      if (!ok) {
        state = state.copyWith(
          errorMessage: ref.read(creditCardControllerProvider).errorMessage,
        );
      }
      return ok;
    }

    if (type == 'card_refund') {
      final card = AiSuggestionValidator.matchCard(
        cardId: item.creditCardId,
        cardName: item.creditCardName,
        cards: cards,
      )!;
      final ok = await ref
          .read(creditCardControllerProvider.notifier)
          .recordCardStandaloneRefund(
            cardId: card.id,
            categoryId: resolvedCategoryId,
            description: item.description,
            amountCents: item.amountCents,
            refundDate: effectiveDate,
            notes: _composeNotes(item),
          );
      if (!ok) {
        state = state.copyWith(
          errorMessage: ref.read(creditCardControllerProvider).errorMessage,
        );
      }
      return ok;
    }

    if (type == 'recurring_expense' || type == 'recurring_income') {
      final acc = AiSuggestionValidator.matchAccount(
        accountId: item.accountId,
        accountName: item.accountName,
        accounts: accounts,
      );
      final card = AiSuggestionValidator.matchCard(
        cardId: item.creditCardId,
        cardName: item.creditCardName,
        cards: cards,
      );
      final recKind = type == 'recurring_income'
          ? RecurringKind.income
          : RecurringKind.expense;
      final ok = await ref.read(recurringControllerProvider.notifier).saveRule(
            kind: recKind,
            description: item.description,
            amountCents: item.amountCents,
            isVariableAmount: false,
            categoryId: resolvedCategoryId,
            accountId: card != null ? null : acc?.id,
            cardId: recKind == RecurringKind.expense ? card?.id : null,
            frequency: RecurringFrequency.fromStorage(item.frequency),
            startDate: effectiveDate,
            notes: _composeNotes(item),
          );
      if (!ok) {
        state = state.copyWith(
          errorMessage: ref.read(recurringControllerProvider).errorMessage,
        );
      }
      return ok;
    }

    // Receita ou despesa direta em conta bancária/carteira.
    final account = AiSuggestionValidator.matchAccount(
      accountId: item.accountId,
      accountName: item.accountName,
      accounts: accounts,
    )!;
    final txKind =
        type == 'income' ? TransactionKind.income : TransactionKind.expense;
    final txStatus = !item.settled
        ? TransactionStatus.pending
        : (txKind == TransactionKind.income
            ? TransactionStatus.received
            : TransactionStatus.paid);

    final ok =
        await ref.read(transactionControllerProvider.notifier).saveTransaction(
              kind: txKind,
              description: item.description,
              amountCents: item.amountCents,
              categoryId: resolvedCategoryId,
              accountId: account.id,
              competencyDate: effectiveDate,
              dueDate: effectiveDate,
              paymentDate: item.settled ? effectiveDate : null,
              status: txStatus,
              notes: _composeNotes(item),
            );
    if (!ok) {
      state = state.copyWith(
        errorMessage: ref.read(transactionControllerProvider).errorMessage,
      );
    }
    return ok;
  }

  Future<String?> _resolveOrCreateCategoryId({
    required String userId,
    required AiTransactionSuggestion item,
    required List<CategoryEntity> categories,
    required Map<String, String> createdCategoryCache,
  }) async {
    final existing = AiSuggestionValidator.matchCategory(
      categoryId: item.categoryId,
      categoryName: item.categorySuggestion,
      transactionType: item.transactionType,
      categories: categories,
    );
    if (existing != null) return existing.id;

    final rawName = (item.categorySuggestion ?? '').trim();
    if (rawName.isEmpty) return null;

    final cacheKey =
        '${item.transactionType}::${AiSuggestionValidator.normalize(rawName)}';
    if (createdCategoryCache.containsKey(cacheKey)) {
      return createdCategoryCache[cacheKey];
    }

    final isIncome = item.transactionType == 'income' ||
        item.transactionType == 'recurring_income';
    final now = DateTime.now();
    final created = await ref.read(categoryRepositoryProvider).createCategory(
          userId: userId,
          category: CategoryEntity(
            id: '',
            name: rawName,
            description: 'Criada mediante confirmação no Assistente IA',
            type: isIncome ? CategoryType.income : CategoryType.expense,
            iconName: isIncome ? 'payments' : 'category',
            colorHex: isIncome ? '#159947' : '#0B6E4F',
            isDefault: false,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
    createdCategoryCache[cacheKey] = created.id;
    return created.id;
  }

  String? _composeNotes(AiTransactionSuggestion item) {
    final parts = <String>[
      if ((item.merchantName ?? '').trim().isNotEmpty)
        'Estabelecimento: ${item.merchantName!.trim()}',
      if ((item.notes ?? '').trim().isNotEmpty) item.notes!.trim(),
    ];
    if (parts.isEmpty) return null;
    final joined = parts.join(' • ');
    return joined.length > 480 ? joined.substring(0, 480) : joined;
  }

  AiMessage _enrichAssistantMessage(AiMessage msg) {
    final suggestion = msg.suggestion;
    if (suggestion == null) return msg;

    final now = DateTime.now();
    final normalizedSuggestion = (suggestion.date.hour == 0 &&
            suggestion.date.minute == 0 &&
            suggestion.date.second == 0 &&
            suggestion.date.year == now.year &&
            suggestion.date.month == now.month &&
            suggestion.date.day == now.day)
        ? suggestion.copyWith(date: DateFormatter.preserveTime(suggestion.date, now))
        : suggestion;

    final categories = ref.read(activeCategoriesProvider);
    final accounts = ref.read(activeAccountsProvider);
    final cards = ref.read(activeCreditCardsProvider);
    final txs = ref.read(transactionsStreamProvider).valueOrNull ?? const [];

    final enriched = AiSuggestionValidator.enrichWithLocalCatalog(
      suggestion: normalizedSuggestion,
      categories: categories,
      accounts: accounts,
      cards: cards,
      existingTransactions: txs,
    );
    return msg.copyWith(suggestion: enriched);
  }

  void _appendErrorMessage(String message) {
    state = state.copyWith(
      isProcessing: false,
      errorMessage: message,
      messages: [
        ...state.messages,
        AiMessage(
          id: 'err_${DateTime.now().microsecondsSinceEpoch}',
          role: AiMessageRole.assistant,
          content: message,
          createdAt: DateTime.now(),
          isError: true,
        ),
      ],
    );
  }
}
