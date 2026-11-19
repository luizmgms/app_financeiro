import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../credit_cards/application/providers/credit_card_providers.dart';
import '../../application/controllers/recurring_controller.dart';
import '../../domain/entities/recurring_rule_entity.dart';

/// Formulário modal para cadastro e edição de contas e receitas recorrentes.
Future<bool?> showRecurringRuleFormDialog(
  BuildContext context, {
  RecurringRuleEntity? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => RecurringRuleFormDialog(existing: existing),
  );
}

class RecurringRuleFormDialog extends ConsumerStatefulWidget {
  const RecurringRuleFormDialog({super.key, this.existing});

  final RecurringRuleEntity? existing;

  @override
  ConsumerState<RecurringRuleFormDialog> createState() =>
      _RecurringRuleFormDialogState();
}

class _RecurringRuleFormDialogState
    extends ConsumerState<RecurringRuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _customDaysController;
  late final TextEditingController _notesController;

  late RecurringKind _kind;
  late bool _useCardTarget;
  late bool _isVariableAmount;
  late RecurringFrequency _frequency;
  String? _categoryId;
  String? _accountId;
  String? _cardId;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final initialCents = existing?.amountCents ?? 0;
    final formattedAmount =
        (initialCents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
    _amountController = TextEditingController(
      text: existing != null ? formattedAmount : '',
    );
    _customDaysController = TextEditingController(
      text: (existing?.customIntervalDays ?? 10).toString(),
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');

    _kind = existing?.kind ?? RecurringKind.expense;
    _useCardTarget = existing?.isCardTarget ?? false;
    _isVariableAmount = existing?.isVariableAmount ?? false;
    _frequency = existing?.frequency ?? RecurringFrequency.monthly;
    _categoryId = existing?.categoryId;
    _accountId = existing?.accountId;
    _cardId = existing?.cardId;
    _startDate = existing?.startDate ?? DateFormatter.dateOnly(DateTime.now());
    _endDate = existing?.endDate;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _customDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = DateFormatter.dateOnly(picked));
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = DateFormatter.dateOnly(picked));
    }
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsedCents = CurrencyFormatter.parseToCents(_amountController.text);
    if (parsedCents == null || parsedCents <= 0) {
      setState(() => _localError = 'Informe um valor maior que zero.');
      return;
    }

    int? customDays;
    if (_frequency == RecurringFrequency.custom) {
      customDays = int.tryParse(_customDaysController.text.trim());
      if (customDays == null || customDays <= 0) {
        setState(() => _localError = 'Informe um intervalo válido em dias.');
        return;
      }
    }

    final ok = await ref.read(recurringControllerProvider.notifier).saveRule(
          existing: widget.existing,
          kind: _kind,
          description: _descriptionController.text,
          amountCents: parsedCents,
          isVariableAmount: _isVariableAmount,
          categoryId: _categoryId ?? '',
          accountId: _useCardTarget ? null : _accountId,
          cardId: _useCardTarget ? _cardId : null,
          frequency: _frequency,
          customIntervalDays: customDays,
          startDate: _startDate,
          endDate: _endDate,
          notes: _notesController.text,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _localError = ref.read(recurringControllerProvider).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(recurringControllerProvider).isLoading;
    final accounts = ref.watch(activeAccountsProvider);
    final cards = ref.watch(activeCreditCardsProvider);
    final allCategories = ref.watch(activeCategoriesProvider);
    final isEditing = widget.existing != null;
    final theme = Theme.of(context);

    final targetCatType = _kind == RecurringKind.income
        ? CategoryType.income
        : CategoryType.expense;
    final matchingCategories = allCategories
        .where((c) => c.type == targetCatType)
        .toList(growable: false);

    if (_categoryId == null ||
        !matchingCategories.any((c) => c.id == _categoryId)) {
      _categoryId =
          matchingCategories.isNotEmpty ? matchingCategories.first.id : null;
    }

    if (_kind == RecurringKind.income && _useCardTarget) {
      _useCardTarget = false;
    }

    if (!_useCardTarget &&
        (_accountId == null || !accounts.any((a) => a.id == _accountId)) &&
        accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

    if (_useCardTarget &&
        (_cardId == null || !cards.any((c) => c.id == _cardId)) &&
        cards.isNotEmpty) {
      _cardId = cards.first.id;
    }

    final amountField = TextFormField(
      controller: _amountController,
      enabled: !isLoading,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: _isVariableAmount ? 'Valor estimado (R\$)' : 'Valor fixo (R\$)',
        hintText: '0,00',
        prefixText: 'R\$ ',
      ),
      validator: (value) {
        final cents = CurrencyFormatter.parseToCents(value ?? '');
        if (cents == null || cents <= 0) {
          return 'Valor inválido.';
        }
        return null;
      },
    );

    final frequencyField = DropdownButtonFormField<RecurringFrequency>(
      value: _frequency,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Frequência'),
      items: [
        for (final freq in RecurringFrequency.values)
          DropdownMenuItem(
            value: freq,
            child: Text(
              freq.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
      onChanged: isLoading
          ? null
          : (value) {
              if (value != null) setState(() => _frequency = value);
            },
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      title: Text(isEditing ? 'Editar recorrência' : 'Nova conta recorrente'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 340;
              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _CompactOptionPill(
                          label: 'Despesa',
                          icon: Icons.trending_down_rounded,
                          selected: _kind == RecurringKind.expense,
                          accentColor: AppColors.expense,
                          onTap: isLoading
                              ? null
                              : () => setState(() => _kind = RecurringKind.expense),
                        ),
                        _CompactOptionPill(
                          label: 'Receita',
                          icon: Icons.trending_up_rounded,
                          selected: _kind == RecurringKind.income,
                          accentColor: AppColors.income,
                          onTap: isLoading
                              ? null
                              : () => setState(() {
                                    _kind = RecurringKind.income;
                                    _useCardTarget = false;
                                  }),
                        ),
                        if (_kind == RecurringKind.expense && cards.isNotEmpty) ...[
                          _CompactOptionPill(
                            label: 'Em conta',
                            icon: Icons.account_balance_wallet_outlined,
                            selected: !_useCardTarget,
                            accentColor: theme.colorScheme.primary,
                            onTap: isLoading
                                ? null
                                : () => setState(() => _useCardTarget = false),
                          ),
                          _CompactOptionPill(
                            label: 'No cartão',
                            icon: Icons.credit_card_rounded,
                            selected: _useCardTarget,
                            accentColor: AppColors.credit,
                            onTap: isLoading
                                ? null
                                : () => setState(() => _useCardTarget = true),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
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
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !isLoading,
                      maxLength: 80,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        hintText: _kind == RecurringKind.income
                            ? 'Ex.: Salário, Aluguel recebido'
                            : 'Ex.: Aluguel, Internet, Energia, Streaming',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe a descrição.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    if (isNarrow) ...[
                      amountField,
                      const SizedBox(height: 10),
                      frequencyField,
                    ] else
                      Row(
                        children: [
                          Expanded(child: amountField),
                          const SizedBox(width: 10),
                          Expanded(child: frequencyField),
                        ],
                      ),
                    if (_frequency == RecurringFrequency.custom) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _customDaysController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Intervalo personalizado (dias)',
                          hintText: 'Ex.: 10, 21, 45',
                        ),
                        validator: (value) {
                          if (_frequency != RecurringFrequency.custom) {
                            return null;
                          }
                          final days = int.tryParse((value ?? '').trim());
                          if (days == null || days < 1 || days > 3650) {
                            return 'Informe entre 1 e 3650 dias.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _isVariableAmount,
                      onChanged: isLoading
                          ? null
                          : (value) =>
                              setState(() => _isVariableAmount = value),
                      title: const Text('Valor variável'),
                      subtitle: const Text(
                        'Útil para contas como energia ou água editadas a cada mês',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: [
                        for (final cat in matchingCategories)
                          DropdownMenuItem(
                            value: cat.id,
                            child: Text(
                              cat.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                      onChanged: isLoading
                          ? null
                          : (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'Selecione uma categoria.' : null,
                    ),
                    const SizedBox(height: 10),
                    if (!_useCardTarget)
                      DropdownButtonFormField<String>(
                        value: _accountId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _kind == RecurringKind.income
                              ? 'Conta de crédito'
                              : 'Conta de pagamento',
                        ),
                        items: [
                          for (final acc in accounts)
                            DropdownMenuItem(
                              value: acc.id,
                              child: Text(
                                acc.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _accountId = value),
                        validator: (value) =>
                            value == null ? 'Selecione uma conta.' : null,
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _cardId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Cartão de crédito',
                        ),
                        items: [
                          for (final card in cards)
                            DropdownMenuItem(
                              value: card.id,
                              child: Text(
                                card.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _cardId = value),
                        validator: (value) =>
                            value == null ? 'Selecione um cartão.' : null,
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : _pickStartDate,
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(
                            'Início: ${DateFormatter.shortDate(_startDate)}',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : _pickEndDate,
                          icon: const Icon(
                            Icons.event_busy_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _endDate != null
                                ? 'Fim: ${DateFormatter.shortDate(_endDate!)}'
                                : 'Data final (opcional)',
                          ),
                        ),
                        if (_endDate != null)
                          IconButton(
                            tooltip: 'Remover data final',
                            onPressed: isLoading
                                ? null
                                : () => setState(() => _endDate = null),
                            icon: const Icon(Icons.clear_rounded, size: 18),
                          ),
                      ],
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
              );
            },
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

class _CompactOptionPill extends StatelessWidget {
  const _CompactOptionPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? accentColor
        : theme.colorScheme.onSurface.withOpacity(0.85);
    final background = selected
        ? accentColor.withOpacity(0.16)
        : theme.colorScheme.surfaceVariant.withOpacity(0.22);
    final border = selected
        ? accentColor.withOpacity(0.75)
        : theme.colorScheme.outline.withOpacity(0.4);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border, width: selected ? 1.3 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_rounded : icon,
                size: 15,
                color: foreground,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
