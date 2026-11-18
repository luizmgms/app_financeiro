import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Bandeira do cartão de crédito.
enum CardBrand {
  mastercard('mastercard', 'Mastercard'),
  visa('visa', 'Visa'),
  elo('elo', 'Elo'),
  amex('amex', 'American Express'),
  hipercard('hipercard', 'Hipercard'),
  other('other', 'Outra');

  const CardBrand(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static CardBrand fromStorage(String? value) {
    return switch (value) {
      'mastercard' => CardBrand.mastercard,
      'visa' => CardBrand.visa,
      'elo' => CardBrand.elo,
      'amex' => CardBrand.amex,
      'hipercard' => CardBrand.hipercard,
      _ => CardBrand.other,
    };
  }
}

/// Entidade de cartão de crédito com controle de limite em centavos e ciclo de fatura.
class CreditCardEntity extends Equatable {
  const CreditCardEntity({
    required this.id,
    required this.name,
    required this.institution,
    required this.brand,
    required this.totalLimitCents,
    required this.usedLimitCents,
    required this.closingDay,
    required this.dueDay,
    this.paymentAccountId,
    required this.colorHex,
    this.defaultInstallments = 1,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String institution;
  final CardBrand brand;
  final int totalLimitCents;
  final int usedLimitCents;
  final int closingDay;
  final int dueDay;
  final String? paymentAccountId;
  final String colorHex;
  final int defaultInstallments;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Limite disponível em centavos (nunca negativo para exibição padrão).
  int get availableLimitCents => math.max(0, totalLimitCents - usedLimitCents);

  /// Proporção de uso do limite entre 0.0 e 1.0.
  double get usageRatio {
    if (totalLimitCents <= 0) return 0;
    return (usedLimitCents / totalLimitCents).clamp(0.0, 1.0);
  }

  CreditCardEntity copyWith({
    String? id,
    String? name,
    String? institution,
    CardBrand? brand,
    int? totalLimitCents,
    int? usedLimitCents,
    int? closingDay,
    int? dueDay,
    String? paymentAccountId,
    bool clearPaymentAccountId = false,
    String? colorHex,
    int? defaultInstallments,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditCardEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      brand: brand ?? this.brand,
      totalLimitCents: totalLimitCents ?? this.totalLimitCents,
      usedLimitCents: usedLimitCents ?? this.usedLimitCents,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
      paymentAccountId: clearPaymentAccountId
          ? null
          : (paymentAccountId ?? this.paymentAccountId),
      colorHex: colorHex ?? this.colorHex,
      defaultInstallments: defaultInstallments ?? this.defaultInstallments,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        institution,
        brand,
        totalLimitCents,
        usedLimitCents,
        closingDay,
        dueDay,
        paymentAccountId,
        colorHex,
        defaultInstallments,
        isActive,
        createdAt,
        updatedAt,
      ];
}
