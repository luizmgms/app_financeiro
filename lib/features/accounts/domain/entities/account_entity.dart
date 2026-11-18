import 'package:equatable/equatable.dart';

/// Tipos de contas financeiras suportados no Finance Control.
enum AccountType {
  checking('checking', 'Conta corrente', 'account_balance'),
  savings('savings', 'Conta poupança', 'savings'),
  cash('cash', 'Dinheiro em espécie', 'payments'),
  digitalWallet('digital_wallet', 'Carteira digital', 'account_balance_wallet'),
  investment('investment', 'Investimentos', 'trending_up'),
  custom('custom', 'Personalizada', 'credit_score');

  const AccountType(this.storageValue, this.label, this.defaultIconName);

  final String storageValue;
  final String label;
  final String defaultIconName;

  static AccountType fromStorage(String? value) {
    return switch (value) {
      'checking' => AccountType.checking,
      'savings' => AccountType.savings,
      'cash' => AccountType.cash,
      'digital_wallet' => AccountType.digitalWallet,
      'investment' => AccountType.investment,
      _ => AccountType.custom,
    };
  }
}

/// Conta financeira do usuário com saldos armazenados em centavos inteiros.
class AccountEntity extends Equatable {
  const AccountEntity({
    required this.id,
    required this.name,
    required this.institution,
    required this.type,
    required this.initialBalanceCents,
    required this.currentBalanceCents,
    required this.colorHex,
    required this.iconName,
    required this.openedAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String institution;
  final AccountType type;
  final int initialBalanceCents;
  final int currentBalanceCents;
  final String colorHex;
  final String iconName;
  final DateTime openedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccountEntity copyWith({
    String? id,
    String? name,
    String? institution,
    AccountType? type,
    int? initialBalanceCents,
    int? currentBalanceCents,
    String? colorHex,
    String? iconName,
    DateTime? openedAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      type: type ?? this.type,
      initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
      currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      openedAt: openedAt ?? this.openedAt,
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
        type,
        initialBalanceCents,
        currentBalanceCents,
        colorHex,
        iconName,
        openedAt,
        isActive,
        createdAt,
        updatedAt,
      ];
}
