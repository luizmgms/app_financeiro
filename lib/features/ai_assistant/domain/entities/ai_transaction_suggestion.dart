import 'package:equatable/equatable.dart';

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
    this.paymentMethod,
    this.creditCardName,
    this.accountName,
    this.installments = 1,
    this.confidence = 0,
    this.requiresConfirmation = true,
    this.missingInformation = const [],
  });

  factory AiTransactionSuggestion.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount_cents'];
    if (rawAmount is! int || rawAmount <= 0) {
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

    final rawInstallments = json['installments'];
    final installments =
        rawInstallments is int && rawInstallments > 0 ? rawInstallments : 1;

    final rawConfidence = json['confidence'];
    final confidence = rawConfidence is num
        ? rawConfidence.toDouble().clamp(0.0, 1.0)
        : 0.0;

    return AiTransactionSuggestion(
      success: json['success'] == true,
      transactionType: rawType.trim(),
      description: rawDescription.trim(),
      amountCents: rawAmount,
      currency: (json['currency'] as String?)?.trim().isNotEmpty == true
          ? (json['currency'] as String).trim()
          : 'BRL',
      date: DateTime.parse(rawDate),
      categorySuggestion: (json['category_suggestion'] as String?)?.trim(),
      paymentMethod: (json['payment_method'] as String?)?.trim(),
      creditCardName: (json['credit_card_name'] as String?)?.trim(),
      accountName: (json['account_name'] as String?)?.trim(),
      installments: installments,
      confidence: confidence,
      // Regra fundamental: nenhum lançamento pode ser salvo automaticamente.
      requiresConfirmation: true,
      missingInformation: missing,
    );
  }

  final bool success;
  final String transactionType;
  final String description;
  final int amountCents;
  final String currency;
  final DateTime date;
  final String? categorySuggestion;
  final String? paymentMethod;
  final String? creditCardName;
  final String? accountName;
  final int installments;
  final double confidence;
  final bool requiresConfirmation;
  final List<String> missingInformation;

  bool get hasMissingInformation => missingInformation.isNotEmpty;

  @override
  List<Object?> get props => [
        success,
        transactionType,
        description,
        amountCents,
        currency,
        date,
        categorySuggestion,
        paymentMethod,
        creditCardName,
        accountName,
        installments,
        confidence,
        requiresConfirmation,
        missingInformation,
      ];
}
