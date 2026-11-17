import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Notificações e Alertas (Etapa 4).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Notificações e Alertas',
      stageLabel: 'Etapa 4 • Alertas Financeiros',
      summary:
          'Central de avisos para contas a vencer, faturas, orçamentos e lembretes configuráveis.',
      icon: Icons.notifications_active_outlined,
      accentColor: AppColors.warning,
      plannedCapabilities: [
        'Alertas de contas próximas do vencimento e contas vencidas',
        'Lembretes de faturas de cartão e receitas previstas',
        'Avisos de orçamento próximo ou acima do limite',
        'Configuração de antecedência e envio via FCM + Cloud Functions agendadas',
      ],
    );
  }
}
