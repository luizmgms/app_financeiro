import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/feature_placeholder_page.dart';

/// Esqueleto do módulo de Categorias Financeiras (Etapa 2).
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Categorias Financeiras',
      stageLabel: 'Etapa 2 • Classificação',
      summary:
          'Separação entre categorias de receitas e despesas com categorias padrão e personalizáveis.',
      icon: Icons.category_outlined,
      accentColor: AppColors.warning,
      plannedCapabilities: [
        'Categorias padrão iniciais (Alimentação, Moradia, Transporte, Salário, etc.)',
        'Criação, edição e arquivamento com nome, descrição, ícone, cor e tipo',
        'Integração direta com o Assistente IA para sugestão inteligente sem invenção',
      ],
    );
  }
}
