import '../../../accounts/domain/entities/account_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/ai_transaction_suggestion.dart';

/// Serviço puro de validação, desambiguação e proteção anti-duplicidade
/// aplicado antes de apresentar ou salvar qualquer sugestão da IA.
abstract final class AiSuggestionValidator {
  static String normalize(String value) {
    const accented = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const plain = 'aaaaaeeeeiiiiooooouuuucn';
    var lower = value.trim().toLowerCase();
    for (var i = 0; i < accented.length; i++) {
      lower = lower.replaceAll(accented[i], plain[i]);
    }
    return lower;
  }

  static CategoryEntity? matchCategory({
    required String? categoryId,
    required String? categoryName,
    required String transactionType,
    required List<CategoryEntity> categories,
  }) {
    if (categoryId != null && categoryId.isNotEmpty) {
      for (final c in categories) {
        if (c.id == categoryId) return c;
      }
    }
    final cleaned = (categoryName ?? '').trim();
    if (cleaned.isEmpty) return null;
    final target = normalize(cleaned);
    final isIncome =
        transactionType == 'income' || transactionType == 'recurring_income';
    final expectedType = isIncome ? CategoryType.income : CategoryType.expense;

    for (final c in categories.where((c) => c.type == expectedType)) {
      if (normalize(c.name) == target) return c;
    }
    for (final c in categories) {
      if (normalize(c.name) == target) return c;
    }
    return null;
  }

  static AccountEntity? matchAccount({
    required String? accountId,
    required String? accountName,
    required List<AccountEntity> accounts,
  }) {
    if (accountId != null && accountId.isNotEmpty) {
      for (final a in accounts) {
        if (a.id == accountId) return a;
      }
    }
    final cleaned = (accountName ?? '').trim();
    if (cleaned.isEmpty) return null;
    final target = normalize(cleaned);
    final exact = accounts.where((a) => normalize(a.name) == target).toList();
    if (exact.isNotEmpty) return exact.first;
    final partial = accounts
        .where(
          (a) =>
              normalize(a.name).contains(target) ||
              target.contains(normalize(a.name)),
        )
        .toList();
    return partial.length == 1 ? partial.first : null;
  }

  static CreditCardEntity? matchCard({
    required String? cardId,
    required String? cardName,
    required List<CreditCardEntity> cards,
  }) {
    if (cardId != null && cardId.isNotEmpty) {
      for (final c in cards) {
        if (c.id == cardId) return c;
      }
    }
    final cleaned = (cardName ?? '').trim();
    if (cleaned.isEmpty) return null;
    final target = normalize(cleaned);
    final exact = cards.where((c) => normalize(c.name) == target).toList();
    if (exact.isNotEmpty) return exact.first;
    final partial = cards
        .where(
          (c) =>
              normalize(c.name).contains(target) ||
              target.contains(normalize(c.name)),
        )
        .toList();
    return partial.length == 1 ? partial.first : null;
  }

  /// Enriquece uma sugestão recém-chegada do backend com IDs reais em cache local
  /// e checagem imediata de possível duplicidade contra transações já carregadas.
  static AiTransactionSuggestion enrichWithLocalCatalog({
    required AiTransactionSuggestion suggestion,
    required List<CategoryEntity> categories,
    required List<AccountEntity> accounts,
    required List<CreditCardEntity> cards,
    required List<TransactionEntity> existingTransactions,
  }) {
    final resolvedCat = matchCategory(
      categoryId: suggestion.categoryId,
      categoryName: suggestion.categorySuggestion,
      transactionType: suggestion.transactionType,
      categories: categories,
    );
    final resolvedAcc = matchAccount(
      accountId: suggestion.accountId,
      accountName: suggestion.accountName,
      accounts: accounts,
    );
    final resolvedDest = matchAccount(
      accountId: suggestion.destinationAccountId,
      accountName: suggestion.destinationAccountName,
      accounts: accounts,
    );
    final resolvedCard = matchCard(
      cardId: suggestion.creditCardId,
      cardName: suggestion.creditCardName,
      cards: cards,
    );

    final dupWarning = suggestion.potentialDuplicateWarning ??
        findPotentialDuplicateWarning(
          suggestion: suggestion,
          existingTransactions: existingTransactions,
        );

    return suggestion.copyWith(
      categoryId: resolvedCat?.id,
      categorySuggestion: resolvedCat?.name ?? suggestion.categorySuggestion,
      categoryIsNew:
          resolvedCat == null && (suggestion.categorySuggestion ?? '').isNotEmpty,
      accountId: resolvedAcc?.id,
      accountName: resolvedAcc?.name ?? suggestion.accountName,
      destinationAccountId: resolvedDest?.id,
      destinationAccountName:
          resolvedDest?.name ?? suggestion.destinationAccountName,
      creditCardId: resolvedCard?.id,
      creditCardName: resolvedCard?.name ?? suggestion.creditCardName,
      potentialDuplicateWarning: dupWarning,
    );
  }

  /// Detecta localmente lançamentos semelhantes próximos no tempo para evitar duplicidade.
  static String? findPotentialDuplicateWarning({
    required AiTransactionSuggestion suggestion,
    required List<TransactionEntity> existingTransactions,
  }) {
    if (suggestion.amountCents <= 0) return null;
    final normTarget = normalize(suggestion.description);
    for (final tx in existingTransactions) {
      if (tx.amountCents != suggestion.amountCents) continue;
      final daysDiff =
          tx.competencyDate.difference(suggestion.date).inDays.abs();
      if (daysDiff > 3) continue;
      final normExisting = normalize(tx.description);
      if (normExisting == normTarget ||
          normExisting.contains(normTarget) ||
          normTarget.contains(normExisting)) {
        final d = tx.competencyDate;
        final dd = '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
        return 'Já existe "${tx.description}" no mesmo valor em $dd.';
      }
    }
    return null;
  }

  /// Retorna uma mensagem de erro caso falte algum dado obrigatório antes de gravar,
  /// ou `null` quando a proposta está pronta para ser persistida.
  static String? validateReadyToConfirm(
    AiTransactionSuggestion suggestion, {
    required List<AccountEntity> accounts,
    required List<CreditCardEntity> cards,
    required List<CategoryEntity> categories,
  }) {
    if (suggestion.description.trim().isEmpty) {
      return 'Informe uma descrição para o lançamento.';
    }
    if (suggestion.amountCents <= 0) {
      return 'Informe um valor maior que zero antes de confirmar.';
    }

    final type = suggestion.transactionType;
    if (type == 'transfer') {
      final src = matchAccount(
        accountId: suggestion.accountId,
        accountName: suggestion.accountName,
        accounts: accounts,
      );
      final dst = matchAccount(
        accountId: suggestion.destinationAccountId,
        accountName: suggestion.destinationAccountName,
        accounts: accounts,
      );
      if (src == null) return 'Selecione a conta de origem da transferência.';
      if (dst == null) return 'Selecione a conta de destino da transferência.';
      if (src.id == dst.id) {
        return 'As contas de origem e destino devem ser diferentes.';
      }
      return null;
    }

    if (type == 'invoice_payment') {
      final card = matchCard(
        cardId: suggestion.creditCardId,
        cardName: suggestion.creditCardName,
        cards: cards,
      );
      final acc = matchAccount(
        accountId: suggestion.accountId,
        accountName: suggestion.accountName,
        accounts: accounts,
      );
      if (card == null) {
        return 'Selecione o cartão cuja fatura será paga.';
      }
      if (acc == null) {
        return 'Selecione a conta utilizada para pagar a fatura.';
      }
      return null;
    }

    final cat = matchCategory(
      categoryId: suggestion.categoryId,
      categoryName: suggestion.categorySuggestion,
      transactionType: type,
      categories: categories,
    );
    if (cat == null && !suggestion.categoryIsNew) {
      return 'Selecione ou confirme a categoria do lançamento.';
    }
    if (cat == null &&
        suggestion.categoryIsNew &&
        (suggestion.categorySuggestion ?? '').trim().isEmpty) {
      return 'Informe o nome da categoria antes de salvar.';
    }

    if (type == 'card_purchase' || type == 'card_refund') {
      final card = matchCard(
        cardId: suggestion.creditCardId,
        cardName: suggestion.creditCardName,
        cards: cards,
      );
      if (card == null) {
        return 'Selecione um cartão de crédito cadastrado.';
      }
      return null;
    }

    final acc = matchAccount(
      accountId: suggestion.accountId,
      accountName: suggestion.accountName,
      accounts: accounts,
    );
    if (acc == null) {
      return 'Selecione a conta financeira para registrar o lançamento.';
    }

    return null;
  }

  /// Converte itens individuais de uma nota fiscal em sugestões editáveis independentes.
  static List<AiTransactionSuggestion> expandSplitItems(
    AiTransactionSuggestion parent,
  ) {
    if (parent.extractedItems.isEmpty) return [parent];
    return parent.extractedItems
        .map(
          (item) => parent.copyWith(
            success: item.amountCents > 0,
            description: item.description,
            amountCents: item.amountCents,
            categoryId: item.categoryId,
            clearCategoryId: item.categoryId == null,
            categorySuggestion:
                item.categorySuggestion ?? parent.categorySuggestion,
            extractedItems: const [],
            splitIntoItems: false,
            clearPotentialDuplicateWarning: true,
          ),
        )
        .toList(growable: false);
  }
}
