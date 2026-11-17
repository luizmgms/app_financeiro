import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Relatórios e Exportação (Etapa 5).
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Relatórios',
      stageLabel: 'Etapa 5 • Análises e Exportação',
      summary:
          'Relatórios detalhados de receitas, despesas, evolução patrimonial, fluxo de caixa e projeções financeiras.',
      icon: Icons.bar_chart_rounded,
      accentColor: AppColors.transfer,
      plannedCapabilities: [
        'Receitas e despesas por período, categoria, conta e cartão',
        'Evolução do patrimônio financeiro e comparativo mensal',
        'Visão de contas pagas, pendentes e compras parceladas comprometidas',
        'Fluxo de caixa e projeção financeira futura',
        'Exportação para PDF e CSV',
      ],
    );
  }
}
