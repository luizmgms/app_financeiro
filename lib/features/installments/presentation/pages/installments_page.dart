import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Parcelamentos (Etapa 3).
class InstallmentsPage extends StatelessWidget {
  const InstallmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Parcelamentos',
      stageLabel: 'Etapa 3 • Compras Parceladas',
      summary:
          'Controle de compras parceladas com distribuição exata de centavos e acompanhamento do saldo comprometido.',
      icon: Icons.view_week_outlined,
      accentColor: AppColors.credit,
      plannedCapabilities: [
        'Divisão exata em centavos garantindo que a soma das parcelas corresponda ao total',
        'Visualização de parcelas pagas, pendentes e futuras',
        'Total já pago e valor ainda comprometido por conta ou cartão',
        'Vínculo automático com as faturas correspondentes do cartão de crédito',
      ],
    );
  }
}
