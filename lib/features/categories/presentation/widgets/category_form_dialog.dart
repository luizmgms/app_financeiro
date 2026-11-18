import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../shared/widgets/color_and_icon_picker.dart';
import '../../application/controllers/category_controller.dart';
import '../../domain/entities/category_entity.dart';

/// Formulário modal para criação e edição de categorias financeiras.
Future<bool?> showCategoryFormDialog(
  BuildContext context, {
  CategoryEntity? existing,
  CategoryType initialType = CategoryType.expense,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CategoryFormDialog(
      existing: existing,
      initialType: initialType,
    ),
  );
}

class CategoryFormDialog extends ConsumerStatefulWidget {
  const CategoryFormDialog({
    super.key,
    this.existing,
    this.initialType = CategoryType.expense,
  });

  final CategoryEntity? existing;
  final CategoryType initialType;

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late CategoryType _type;
  late String _iconName;
  late String _colorHex;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _type = existing?.type ?? widget.initialType;
    _iconName = existing?.iconName ??
        (_type == CategoryType.income ? 'payments' : 'restaurant');
    _colorHex = existing?.colorHex ??
        (_type == CategoryType.income ? '#10B981' : '#F97316');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(categoryControllerProvider.notifier).saveCategory(
          existing: widget.existing,
          name: _nameController.text,
          description: _descriptionController.text,
          type: _type,
          iconName: _iconName,
          colorHex: _colorHex,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _localError = ref.read(categoryControllerProvider).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(categoryControllerProvider).isLoading;
    final isEditing = widget.existing != null;
    final accent = ColorUtils.fromHex(_colorHex);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEditing ? 'Editar categoria' : 'Nova categoria'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_localError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _localError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SegmentedButton<CategoryType>(
                  segments: const [
                    ButtonSegment<CategoryType>(
                      value: CategoryType.expense,
                      label: Text('Despesa'),
                      icon: Icon(Icons.trending_down_rounded),
                    ),
                    ButtonSegment<CategoryType>(
                      value: CategoryType.income,
                      label: Text('Receita'),
                      icon: Icon(Icons.trending_up_rounded),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: isEditing || isLoading
                      ? null
                      : (selection) {
                          setState(() => _type = selection.first);
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  enabled: !isLoading,
                  maxLength: 60,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome da categoria',
                    hintText: 'Ex.: Mercado, Assinaturas, Bônus',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da categoria.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !isLoading,
                  maxLength: 140,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Breve observação sobre o uso da categoria',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cor',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ColorPickerRow(
                  selectedHex: _colorHex,
                  onSelected: (hex) => setState(() => _colorHex = hex),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ícone',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                IconPickerGrid(
                  options: IconCatalog.categoryOptions,
                  selectedIconName: _iconName,
                  accentColor: accent,
                  onSelected: (name) => setState(() => _iconName = name),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: Text(isLoading ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}
