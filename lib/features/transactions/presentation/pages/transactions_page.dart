import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Movimentações Financeiras (Etapa 2).
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Movimentações',
      stageLabel: 'Etapa 2 • Lançamentos',
      summary:
          'Módulo dedicado ao registro rápido, pesquisa e filtragem de receitas e despesas com anexos e controle de status.',
      icon: Icons.swap_horiz_rounded,
      accentColor: AppColors.income,
      plannedCapabilities: [
        'Receitas (recebida/pendente) e despesas (paga/pendente/atrasada) em centavos inteiros',
        'Separação entre data de lançamento, vencimento e pagamento',
        'Lançamento rápido, duplicação e exclusão com confirmação',
        'Pesquisa por descrição e filtros por período, categoria, conta e status',
        'Upload de comprovantes e anexos no Firebase Storage',
      ],
    );
  }
}
