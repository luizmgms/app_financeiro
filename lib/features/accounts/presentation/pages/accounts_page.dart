import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Contas e Transferências (Etapa 2).
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Contas',
      stageLabel: 'Etapa 2 • Contas e Transferências',
      summary:
          'Gerenciamento de contas correntes, poupanças, dinheiro em espécie, carteiras digitais e investimentos.',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: AppColors.primaryLight,
      plannedCapabilities: [
        'Cadastro com instituição, tipo, saldo inicial, cor, ícone e status',
        'Cálculo automático do saldo atual considerando o histórico de movimentações',
        'Extrato filtrado por conta e arquivamento seguro',
        'Transferências atômicas entre contas sem contabilizar como receita ou despesa',
      ],
    );
  }
}
