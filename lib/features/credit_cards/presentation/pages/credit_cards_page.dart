import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Cartões de Crédito e Faturas (Etapa 3).
class CreditCardsPage extends StatelessWidget {
  const CreditCardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Cartões de Crédito',
      stageLabel: 'Etapa 3 • Cartões e Faturas',
      summary:
          'Controle completo de limites, ciclos de fechamento/vencimento, compras parceladas e pagamento de faturas.',
      icon: Icons.credit_card_rounded,
      accentColor: AppColors.credit,
      plannedCapabilities: [
        'Cadastro de cartão com bandeira, limite total, fechamento, vencimento e conta pagadora',
        'Alocação automática de compras na fatura correta conforme dia de fechamento',
        'Compras parceladas distribuídas automaticamente entre faturas futuras',
        'Pagamento de fatura gerando saída na conta sem duplicar despesa',
        'Cancelamento e estorno mantendo integridade de histórico e limite',
      ],
    );
  }
}
