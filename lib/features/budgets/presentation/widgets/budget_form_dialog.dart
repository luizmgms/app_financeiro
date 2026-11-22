import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../application/controllers/budget_controller.dart';
import '../../domain/entities/budget_entity.dart';

/// Formulário modal para definir ou editar meta mensal por categoria.
Future<bool?> showBudgetFormDialog(
  BuildContext context, {
  required int year,
  required int month,
  BudgetEntity? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => BudgetFormDialog(
      year: year,
      month: month,
      existing: existing,
    ),
  );
}

class BudgetFormDialog extends ConsumerStatefulWidget {
  const BudgetFormDialog({
    super.key,
    required this.year,
    required this.month,
    this.existing,
  });

  final int year;
  final int month;
  final BudgetEntity? existing;

  @override
  ConsumerState<BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitController;
  late final TextEditingController _notesController;
  String? _selectedCategoryId;
  late int _alertThresholdPercent;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _selectedCategoryId = existing?.categoryId;
    _alertThresholdPercent = existing?.alertThresholdPercent ?? 80;
    final formattedLimit = existing != null
        ? (existing.limitCents / 100.0).toStringAsFixed(2).replaceAll('.', ',')
        : '';
    _limitController = TextEditingController(text: formattedLimit);
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _limitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cents = CurrencyFormatter.parseToCents(_limitController.text);
    if (cents == null || cents <= 0) {
      setState(() => _localError = 'Informe um limite mensal maior que zero.');
      return;
    }

    final ok = await ref.read(budgetControllerProvider.notifier).saveBudget(
          categoryId: _selectedCategoryId ?? '',
          year: widget.year,
          month: widget.month,
          limitCents: cents,
          alertThresholdPercent: _alertThresholdPercent,
          notes: _notesController.text,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _localError = ref.read(budgetControllerProvider).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(budgetControllerProvider).isLoading;
    final expenseCategories = ref
        .watch(activeCategoriesProvider)
        .where((c) => c.type == CategoryType.expense)
        .toList(growable: false);
    final isEditing = widget.existing != null;
    final theme = Theme.of(context);

    if ((_selectedCategoryId == null ||
            !expenseCategories.any((c) => c.id == _selectedCategoryId)) &&
        expenseCategories.isNotEmpty) {
      _selectedCategoryId = expenseCategories.first.id;
    }

    final mm = widget.month.toString().padLeft(2, '0');

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      title: Text(
        isEditing
            ? 'Editar orçamento ($mm/${widget.year})'
            : 'Novo orçamento ($mm/${widget.year})',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 6),
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
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria de despesa',
                  ),
                  items: [
                    for (final category in expenseCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                  ],
                  onChanged: isLoading || isEditing
                      ? null
                      : (value) => setState(() => _selectedCategoryId = value),
                  validator: (value) =>
                      value == null ? 'Selecione uma categoria.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _limitController,
                  enabled: !isLoading,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Limite mensal (R\$)',
                    hintText: 'Ex.: 1000,00',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    final parsed = CurrencyFormatter.parseToCents(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Informe um valor maior que zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: const [70, 75, 80, 85, 90, 95]
                          .contains(_alertThresholdPercent)
                      ? _alertThresholdPercent
                      : 80,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Alertar ao atingir (%)',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 70,
                      child: Text('70% do limite planejado'),
                    ),
                    DropdownMenuItem(
                      value: 75,
                      child: Text('75% do limite planejado'),
                    ),
                    DropdownMenuItem(
                      value: 80,
                      child: Text('80% do limite planejado (recomendado)'),
                    ),
                    DropdownMenuItem(
                      value: 85,
                      child: Text('85% do limite planejado'),
                    ),
                    DropdownMenuItem(
                      value: 90,
                      child: Text('90% do limite planejado'),
                    ),
                    DropdownMenuItem(
                      value: 95,
                      child: Text('95% do limite planejado'),
                    ),
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _alertThresholdPercent = value);
                          }
                        },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  enabled: !isLoading,
                  maxLines: 2,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                  ),
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
          onPressed: isLoading || expenseCategories.isEmpty ? null : _submit,
          child: Text(isLoading ? 'Salvando...' : 'Salvar meta'),
        ),
      ],
    );
  }
}
