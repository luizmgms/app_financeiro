import 'package:equatable/equatable.dart';

/// Item individual identificado em cupons ou notas fiscais com múltiplos produtos.
class AiReceiptLineItem extends Equatable {
  const AiReceiptLineItem({
    required this.description,
    required this.amountCents,
    this.categorySuggestion,
    this.categoryId,
  });

  factory AiReceiptLineItem.fromJson(Map<String, dynamic> json) {
    final desc = (json['description'] as String?)?.trim() ?? '';
    final amount = (json['amount_cents'] as num?)?.toInt() ?? 0;
    return AiReceiptLineItem(
      description: desc.isEmpty ? 'Item da nota' : desc,
      amountCents: amount < 0 ? 0 : amount,
      categorySuggestion: (json['category_suggestion'] as String?)?.trim(),
      categoryId: (json['category_id'] as String?)?.trim(),
    );
  }

  final String description;
  final int amountCents;
  final String? categorySuggestion;
  final String? categoryId;

  @override
  List<Object?> get props =>
      [description, amountCents, categorySuggestion, categoryId];
}

/// Proposta estruturada retornada pela camada backend do Gemini AI.
/// Por regra de negócio, `requiresConfirmation` é sempre obrigatório antes de salvar.
class AiTransactionSuggestion extends Equatable {
  const AiTransactionSuggestion({
    required this.success,
    required this.transactionType,
    required this.description,
    required this.amountCents,
    required this.currency,
    required this.date,
    this.categorySuggestion,
    this.categoryId,
    this.categoryIsNew = false,
    this.paymentMethod,
    this.creditCardName,
    this.creditCardId,
    this.accountName,
    this.accountId,
    this.destinationAccountName,
    this.destinationAccountId,
    this.installments = 1,
    this.frequency,
    this.confidence = 0,
    this.requiresConfirmation = true,
    this.missingInformation = const [],
    this.ambiguousAccounts = const [],
    this.ambiguousCards = const [],
    this.merchantName,
    this.discountCents,
    this.taxCents,
    this.notes,
    this.extractedItems = const [],
    this.potentialDuplicateWarning,
    this.splitIntoItems = false,
    this.settled = true,
  });

  /// Parser estrito para propostas completas de movimentação.
  /// Rejeita propostas sem valor inteiro positivo (`amount_cents <= 0`).
  factory AiTransactionSuggestion.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount_cents'];
    if (rawAmount is! int || rawAmount <= 0) {
      throw const FormatException(
        'amount_cents deve ser um inteiro positivo em centavos.',
      );
    }

    return _parseInternal(json, enforcePositiveAmount: true);
  }

  /// Parser tolerante para respostas de esclarecimento/nota ilegível (`amount_cents == 0`),
  /// mantendo validação estrita dos tipos e `requiresConfirmation = true`.
  static AiTransactionSuggestion? tryFromResponseJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return null;
    try {
      return _parseInternal(json, enforcePositiveAmount: false);
    } catch (_) {
      return null;
    }
  }

  static AiTransactionSuggestion _parseInternal(
    Map<String, dynamic> json, {
    required bool enforcePositiveAmount,
  }) {
    final rawAmount = json['amount_cents'];
    final parsedAmount = rawAmount is int
        ? rawAmount
        : (rawAmount is num ? rawAmount.round() : 0);

    if (enforcePositiveAmount && parsedAmount <= 0) {
      throw const FormatException(
        'amount_cents deve ser um inteiro positivo em centavos.',
      );
    }

    final rawType = json['transaction_type'];
    if (rawType is! String || rawType.trim().isEmpty) {
      throw const FormatException('transaction_type inválido.');
    }

    final rawDescription = json['description'];
    if (rawDescription is! String || rawDescription.trim().isEmpty) {
      throw const FormatException('description inválida.');
    }

    final rawDate = json['date'];
    if (rawDate is! String || DateTime.tryParse(rawDate) == null) {
      throw const FormatException('date deve estar no formato ISO-8601.');
    }

    final rawMissing = json['missing_information'];
    final missing = rawMissing is List
        ? rawMissing.whereType<String>().toList(growable: false)
        : const <String>[];

    final ambiguousAccounts = json['ambiguous_accounts'] is List
        ? (json['ambiguous_accounts'] as List)
            .whereType<String>()
            .toList(growable: false)
        : const <String>[];

    final ambiguousCards = json['ambiguous_cards'] is List
        ? (json['ambiguous_cards'] as List)
            .whereType<String>()
            .toList(growable: false)
        : const <String>[];

    final extractedItems = <AiReceiptLineItem>[];
    if (json['extracted_items'] is List) {
      for (final item in json['extracted_items'] as List) {
        if (item is Map<String, dynamic>) {
          final parsed = AiReceiptLineItem.fromJson(item);
          if (parsed.amountCents > 0) extractedItems.add(parsed);
        } else if (item is Map) {
          final parsed =
              AiReceiptLineItem.fromJson(Map<String, dynamic>.from(item));
          if (parsed.amountCents > 0) extractedItems.add(parsed);
        }
      }
    }

    final rawInstallments = json['installments'];
    final installments = rawInstallments is num && rawInstallments >= 1
        ? rawInstallments.toInt().clamp(1, 48)
        : 1;

    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is num
        ? rawConfidence.toDouble().clamp(0.0, 1.0)
        : 0.0;

    return AiTransactionSuggestion(
      success: json['success'] == true && parsedAmount > 0,
      transactionType: rawType.trim(),
      description: rawDescription.trim(),
      amountCents: parsedAmount < 0 ? 0 : parsedAmount,
      currency: (json['currency'] as String?)?.trim().isNotEmpty == true
          ? (json['currency'] as String).trim()
          : 'BRL',
      date: DateTime.parse(rawDate),
      categorySuggestion: (json['category_suggestion'] as String?)?.trim(),
      categoryId: (json['category_id'] as String?)?.trim(),
      categoryIsNew: json['category_is_new'] == true,
      paymentMethod: (json['payment_method'] as String?)?.trim(),
      creditCardName: (json['credit_card_name'] as String?)?.trim(),
      creditCardId: (json['credit_card_id'] as String?)?.trim(),
      accountName: (json['account_name'] as String?)?.trim(),
      accountId: (json['account_id'] as String?)?.trim(),
      destinationAccountName:
          (json['destination_account_name'] as String?)?.trim(),
      destinationAccountId:
          (json['destination_account_id'] as String?)?.trim(),
      installments: installments,
      frequency: (json['frequency'] as String?)?.trim(),
      confidence: confidence,
      // Regra fundamental: nenhum lançamento pode ser salvo automaticamente.
      requiresConfirmation: true,
      missingInformation: missing,
      ambiguousAccounts: ambiguousAccounts,
      ambiguousCards: ambiguousCards,
      merchantName: (json['merchant_name'] as String?)?.trim(),
      discountCents: (json['discount_cents'] as num?)?.toInt(),
      taxCents: (json['tax_cents'] as num?)?.toInt(),
      notes: (json['notes'] as String?)?.trim(),
      extractedItems: extractedItems,
      potentialDuplicateWarning:
          (json['potential_duplicate_warning'] as String?)?.trim(),
    );
  }

  final bool success;
  final String transactionType;
  final String description;
  final int amountCents;
  final String currency;
  final DateTime date;
  final String? categorySuggestion;
  final String? categoryId;
  final bool categoryIsNew;
  final String? paymentMethod;
  final String? creditCardName;
  final String? creditCardId;
  final String? accountName;
  final String? accountId;
  final String? destinationAccountName;
  final String? destinationAccountId;
  final int installments;
  final String? frequency;
  final double confidence;
  final bool requiresConfirmation;
  final List<String> missingInformation;
  final List<String> ambiguousAccounts;
  final List<String> ambiguousCards;
  final String? merchantName;
  final int? discountCents;
  final int? taxCents;
  final String? notes;
  final List<AiReceiptLineItem> extractedItems;
  final String? potentialDuplicateWarning;
  final bool splitIntoItems;
  final bool settled;

  bool get hasMissingInformation => missingInformation.isNotEmpty;
  bool get hasMultipleItems => extractedItems.length > 1;
  bool get isCardTransaction =>
      transactionType == 'card_purchase' ||
      transactionType == 'card_refund' ||
      transactionType == 'invoice_payment';
  bool get isRecurringTransaction =>
      transactionType == 'recurring_expense' ||
      transactionType == 'recurring_income';

  AiTransactionSuggestion copyWith({
    bool? success,
    String? transactionType,
    String? description,
    int? amountCents,
    String? currency,
    DateTime? date,
    String? categorySuggestion,
    bool clearCategorySuggestion = false,
    String? categoryId,
    bool clearCategoryId = false,
    bool? categoryIsNew,
    String? paymentMethod,
    String? creditCardName,
    bool clearCreditCardName = false,
    String? creditCardId,
    bool clearCreditCardId = false,
    String? accountName,
    bool clearAccountName = false,
    String? accountId,
    bool clearAccountId = false,
    String? destinationAccountName,
    bool clearDestinationAccountName = false,
    String? destinationAccountId,
    bool clearDestinationAccountId = false,
    int? installments,
    String? frequency,
    double? confidence,
    List<String>? missingInformation,
    List<String>? ambiguousAccounts,
    List<String>? ambiguousCards,
    String? merchantName,
    int? discountCents,
    int? taxCents,
    String? notes,
    List<AiReceiptLineItem>? extractedItems,
    String? potentialDuplicateWarning,
    bool clearPotentialDuplicateWarning = false,
    bool? splitIntoItems,
    bool? settled,
  }) {
    return AiTransactionSuggestion(
      success: success ?? this.success,
      transactionType: transactionType ?? this.transactionType,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      categorySuggestion: clearCategorySuggestion
          ? null
          : (categorySuggestion ?? this.categorySuggestion),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      categoryIsNew: categoryIsNew ?? this.categoryIsNew,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      creditCardName: clearCreditCardName
          ? null
          : (creditCardName ?? this.creditCardName),
      creditCardId:
          clearCreditCardId ? null : (creditCardId ?? this.creditCardId),
      accountName: clearAccountName ? null : (accountName ?? this.accountName),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      destinationAccountName: clearDestinationAccountName
          ? null
          : (destinationAccountName ?? this.destinationAccountName),
      destinationAccountId: clearDestinationAccountId
          ? null
          : (destinationAccountId ?? this.destinationAccountId),
      installments: installments ?? this.installments,
      frequency: frequency ?? this.frequency,
      confidence: confidence ?? this.confidence,
      requiresConfirmation: true,
      missingInformation: missingInformation ?? this.missingInformation,
      ambiguousAccounts: ambiguousAccounts ?? this.ambiguousAccounts,
      ambiguousCards: ambiguousCards ?? this.ambiguousCards,
      merchantName: merchantName ?? this.merchantName,
      discountCents: discountCents ?? this.discountCents,
      taxCents: taxCents ?? this.taxCents,
      notes: notes ?? this.notes,
      extractedItems: extractedItems ?? this.extractedItems,
      potentialDuplicateWarning: clearPotentialDuplicateWarning
          ? null
          : (potentialDuplicateWarning ?? this.potentialDuplicateWarning),
      splitIntoItems: splitIntoItems ?? this.splitIntoItems,
      settled: settled ?? this.settled,
    );
  }

  @override
  List<Object?> get props => [
        success,
        transactionType,
        description,
        amountCents,
        currency,
        date,
        categorySuggestion,
        categoryId,
        categoryIsNew,
        paymentMethod,
        creditCardName,
        creditCardId,
        accountName,
        accountId,
        destinationAccountName,
        destinationAccountId,
        installments,
        frequency,
        confidence,
        requiresConfirmation,
        missingInformation,
        ambiguousAccounts,
        ambiguousCards,
        merchantName,
        discountCents,
        taxCents,
        notes,
        extractedItems,
        potentialDuplicateWarning,
        splitIntoItems,
        settled,
      ];
}
