import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Orçamento e Planejamento Financeiro (Etapa 5).
class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Orçamentos',
      stageLabel: 'Etapa 5 • Planejamento Mensal',
      summary:
          'Definição de limites mensais de gastos por categoria com alertas de aproximação e estouro.',
      icon: Icons.pie_chart_outline_rounded,
      accentColor: AppColors.income,
      plannedCapabilities: [
        'Limites mensais por categoria (ex.: Alimentação, Transporte, Lazer, Saúde)',
        'Acompanhamento de valor planejado, utilizado, disponível e % consumido',
        'Alertas visuais e notificações de aproximação e ultrapassagem do limite',
        'Comparativo entre meses anteriores',
      ],
    );
  }
}
