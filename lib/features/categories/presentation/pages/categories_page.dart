import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../application/controllers/category_controller.dart';
import '../../application/providers/category_providers.dart';
import '../../domain/entities/category_entity.dart';
import '../widgets/category_form_dialog.dart';

/// Tela de gestão de categorias financeiras (Receitas e Despesas).
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  CategoryType _selectedType = CategoryType.expense;
  bool _showArchived = false;

  Future<void> _confirmDelete(CategoryEntity category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: Text(
          'Deseja excluir a categoria "${category.name}"? '
          'Se ela já estiver vinculada a movimentações, será necessário arquivá-la.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref
        .read(categoryControllerProvider.notifier)
        .deleteCategory(category.id);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CategoryActionState>(categoryControllerProvider, (prev, next) {
      if (!mounted) return;
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.expense,
          ),
        );
      } else if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }
    });

    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final theme = Theme.of(context);

    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias Financeiras'),
        actions: [
          if (isCompact)
            IconButton(
              tooltip: 'Nova categoria',
              onPressed: () => showCategoryFormDialog(
                context,
                initialType: _selectedType,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
            )
          else
            FilledButton.icon(
              onPressed: () => showCategoryFormDialog(
                context,
                initialType: _selectedType,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova categoria'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar categorias',
          description: error.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.invalidate(categoriesStreamProvider),
        ),
        data: (categories) {
          final filtered = categories.where((c) {
            if (c.type != _selectedType) return false;
            if (!_showArchived && !c.isActive) return false;
            return true;
          }).toList(growable: false);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<CategoryType>(
                          segments: const [
                            ButtonSegment<CategoryType>(
                              value: CategoryType.expense,
                              label: Text('Despesas'),
                              icon: Icon(Icons.trending_down_rounded),
                            ),
                            ButtonSegment<CategoryType>(
                              value: CategoryType.income,
                              label: Text('Receitas'),
                              icon: Icon(Icons.trending_up_rounded),
                            ),
                          ],
                          selected: {_selectedType},
                          onSelectionChanged: (selection) {
                            setState(() => _selectedType = selection.first);
                          },
                        ),
                        FilterChip(
                          label: const Text('Mostrar arquivadas'),
                          selected: _showArchived,
                          onSelected: (value) {
                            setState(() => _showArchived = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyStateView(
                            icon: Icons.category_outlined,
                            title: 'Nenhuma categoria encontrada',
                            description: _showArchived
                                ? 'Cadastre uma categoria para organizar suas movimentações.'
                                : 'Nenhuma categoria ativa neste tipo. Crie uma nova ou exiba as arquivadas.',
                            actionLabel: 'Criar categoria',
                            onAction: () => showCategoryFormDialog(
                              context,
                              initialType: _selectedType,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final category = filtered[index];
                              final color = ColorUtils.fromHex(
                                category.colorHex,
                                fallback: AppColors.primaryLight,
                              );
                              final iconData =
                                  IconCatalog.resolve(category.iconName);

                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(iconData, color: color),
                                  ),
                                  title: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        category.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          decoration: category.isActive
                                              ? null
                                              : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      if (category.isDefault)
                                        const StatusBadge(
                                          label: 'Padrão',
                                          color: AppColors.transfer,
                                        ),
                                      if (!category.isActive)
                                        const StatusBadge(
                                          label: 'Arquivada',
                                          color: AppColors.warning,
                                        ),
                                    ],
                                  ),
                                  subtitle: category.description.isEmpty
                                      ? null
                                      : Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(category.description),
                                        ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'edit':
                                          showCategoryFormDialog(
                                            context,
                                            existing: category,
                                          );
                                          break;
                                        case 'archive':
                                          ref
                                              .read(categoryControllerProvider
                                                  .notifier)
                                              .setArchived(
                                                categoryId: category.id,
                                                archived: category.isActive,
                                              );
                                          break;
                                        case 'delete':
                                          _confirmDelete(category);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Text(
                                          category.isActive
                                              ? 'Arquivar'
                                              : 'Reativar',
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
