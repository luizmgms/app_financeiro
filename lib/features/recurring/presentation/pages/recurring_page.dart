import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Contas Recorrentes (Etapa 4).
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Contas Recorrentes',
      stageLabel: 'Etapa 4 • Automatizações',
      summary:
          'Gerenciamento de receitas e despesas periódicas com geração idempotente e sem duplicidades.',
      icon: Icons.repeat_rounded,
      accentColor: AppColors.transfer,
      plannedCapabilities: [
        'Frequências: diária, semanal, quinzenal, mensal, bimestral, trimestral, semestral, anual e personalizada',
        'Suporte a valor fixo ou variável, data inicial e data final opcional',
        'Edição individual de uma ocorrência sem alterar o restante da série',
        'Pausar, retomar e cancelar recorrências com garantia anti-duplicidade',
      ],
    );
  }
}
