import 'package:flutter/material.dart';

/// Opção tipada de ícone para seletores visuais sem quebra do tree-shaking.
class IconCatalogOption {
  const IconCatalogOption({
    required this.name,
    required this.label,
    required this.icon,
  });

  final String name;
  final String label;
  final IconData icon;
}

/// Catálogo estático de ícones usados em categorias e contas financeiras.
abstract final class IconCatalog {
  static const List<IconCatalogOption> categoryOptions = <IconCatalogOption>[
    IconCatalogOption(
      name: 'restaurant',
      label: 'Alimentação',
      icon: Icons.restaurant_rounded,
    ),
    IconCatalogOption(
      name: 'home',
      label: 'Moradia',
      icon: Icons.home_rounded,
    ),
    IconCatalogOption(
      name: 'directions_car',
      label: 'Transporte',
      icon: Icons.directions_car_rounded,
    ),
    IconCatalogOption(
      name: 'favorite',
      label: 'Saúde',
      icon: Icons.favorite_rounded,
    ),
    IconCatalogOption(
      name: 'school',
      label: 'Educação',
      icon: Icons.school_rounded,
    ),
    IconCatalogOption(
      name: 'sports_esports',
      label: 'Lazer',
      icon: Icons.sports_esports_rounded,
    ),
    IconCatalogOption(
      name: 'shopping_bag',
      label: 'Compras',
      icon: Icons.shopping_bag_rounded,
    ),
    IconCatalogOption(
      name: 'build',
      label: 'Serviços',
      icon: Icons.build_rounded,
    ),
    IconCatalogOption(
      name: 'receipt_long',
      label: 'Impostos',
      icon: Icons.receipt_long_rounded,
    ),
    IconCatalogOption(
      name: 'payments',
      label: 'Salário',
      icon: Icons.payments_rounded,
    ),
    IconCatalogOption(
      name: 'work',
      label: 'Freelance',
      icon: Icons.work_rounded,
    ),
    IconCatalogOption(
      name: 'trending_up',
      label: 'Rendimentos',
      icon: Icons.trending_up_rounded,
    ),
    IconCatalogOption(
      name: 'apartment',
      label: 'Aluguel',
      icon: Icons.apartment_rounded,
    ),
    IconCatalogOption(
      name: 'storefront',
      label: 'Vendas',
      icon: Icons.storefront_rounded,
    ),
    IconCatalogOption(
      name: 'local_cafe',
      label: 'Café',
      icon: Icons.local_cafe_rounded,
    ),
    IconCatalogOption(
      name: 'pets',
      label: 'Pets',
      icon: Icons.pets_rounded,
    ),
    IconCatalogOption(
      name: 'flight',
      label: 'Viagens',
      icon: Icons.flight_rounded,
    ),
    IconCatalogOption(
      name: 'subscriptions',
      label: 'Assinaturas',
      icon: Icons.subscriptions_rounded,
    ),
    IconCatalogOption(
      name: 'fitness_center',
      label: 'Academia',
      icon: Icons.fitness_center_rounded,
    ),
    IconCatalogOption(
      name: 'category',
      label: 'Outros',
      icon: Icons.category_rounded,
    ),
  ];

  static const List<IconCatalogOption> accountOptions = <IconCatalogOption>[
    IconCatalogOption(
      name: 'account_balance',
      label: 'Banco',
      icon: Icons.account_balance_rounded,
    ),
    IconCatalogOption(
      name: 'savings',
      label: 'Poupança',
      icon: Icons.savings_rounded,
    ),
    IconCatalogOption(
      name: 'payments',
      label: 'Dinheiro',
      icon: Icons.payments_rounded,
    ),
    IconCatalogOption(
      name: 'account_balance_wallet',
      label: 'Carteira',
      icon: Icons.account_balance_wallet_rounded,
    ),
    IconCatalogOption(
      name: 'trending_up',
      label: 'Investimentos',
      icon: Icons.trending_up_rounded,
    ),
    IconCatalogOption(
      name: 'credit_score',
      label: 'Conta Digital',
      icon: Icons.credit_score_rounded,
    ),
    IconCatalogOption(
      name: 'currency_exchange',
      label: 'Câmbio',
      icon: Icons.currency_exchange_rounded,
    ),
    IconCatalogOption(
      name: 'business_center',
      label: 'Empresarial',
      icon: Icons.business_center_rounded,
    ),
  ];

  static final Map<String, IconData> _byName = <String, IconData>{
    for (final option in categoryOptions) option.name: option.icon,
    for (final option in accountOptions) option.name: option.icon,
  };

  static IconData resolve(
    String? name, {
    IconData fallback = Icons.category_rounded,
  }) {
    if (name == null) return fallback;
    return _byName[name] ?? fallback;
  }
}
