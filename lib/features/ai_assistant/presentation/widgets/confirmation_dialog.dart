import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../credit_cards/domain/entities/credit_card_entity.dart';
import '../../../recurring/domain/entities/recurring_rule_entity.dart';
import '../../domain/entities/ai_transaction_suggestion.dart';
import '../../domain/services/ai_suggestion_validator.dart';

/// Modal de edição explícita dos campos sugeridos pela IA antes da confirmação.
Future<AiTransactionSuggestion?> showAiSuggestionEditDialog(
  BuildContext context, {
  required AiTransactionSuggestion initial,
  required List<CategoryEntity> categories,
  required List<AccountEntity> accounts,
  required List<CreditCardEntity> cards,
  String submitLabel = 'Aplicar edição',
}) {
  return showDialog<AiTransactionSuggestion>(
    context: context,
    builder: (context) => _AiSuggestionEditDialog(
      initial: initial,
      categories: categories,
      accounts: accounts,
      cards: cards,
      submitLabel: submitLabel,
    ),
  );
}

class _AiSuggestionEditDialog extends StatefulWidget {
  const _AiSuggestionEditDialog({
    required this.initial,
    required this.categories,
    required this.accounts,
    required this.cards,
    required this.submitLabel,
  });

  final AiTransactionSuggestion initial;
  final List<CategoryEntity> categories;
  final List<AccountEntity> accounts;
  final List<CreditCardEntity> cards;
  final String submitLabel;

  @override
  State<_AiSuggestionEditDialog> createState() =>
      _AiSuggestionEditDialogState();
}

class _AiSuggestionEditDialogState extends State<_AiSuggestionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _newCategoryCtrl;
  late final TextEditingController _notesCtrl;

  late String _transactionType;
  late DateTime _date;
  late int _installments;
  late String _frequency;
  late bool _settled;
  late bool _createNewCategory;
  String? _categoryId;
  String? _accountId;
  String? _destinationAccountId;
  String? _cardId;

  static const _typeLabels = <String, String>{
    'expense': 'Despesa',
    'income': 'Receita',
    'card_purchase': 'Compra no cartão',
    'card_refund': 'Estorno no cartão',
    'transfer': 'Transferência entre contas',
    'invoice_payment': 'Pagamento de fatura',
    'recurring_expense': 'Despesa recorrente',
    'recurring_income': 'Receita recorrente',
  };

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _transactionType =
        _typeLabels.containsKey(s.transactionType) ? s.transactionType : 'expense';
    _date = s.date;
    _installments = s.installments.clamp(1, 48);
    _frequency = s.frequency ?? 'monthly';
    _settled = s.settled;
    _descriptionCtrl = TextEditingController(text: s.description);
    _amountCtrl = TextEditingController(
      text: s.amountCents > 0
          ? (s.amountCents / 100.0).toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _notesCtrl = TextEditingController(text: s.notes ?? '');

    final matchedCat = AiSuggestionValidator.matchCategory(
      categoryId: s.categoryId,
      categoryName: s.categorySuggestion,
      transactionType: _transactionType,
      categories: widget.categories,
    );
    _categoryId = matchedCat?.id;
    _createNewCategory = matchedCat == null &&
        s.categoryIsNew &&
        (s.categorySuggestion ?? '').trim().isNotEmpty;
    _newCategoryCtrl = TextEditingController(
      text: _createNewCategory ? (s.categorySuggestion ?? '') : '',
    );

    _accountId = AiSuggestionValidator.matchAccount(
          accountId: s.accountId,
          accountName: s.accountName,
          accounts: widget.accounts,
        )?.id ??
        (widget.accounts.length == 1 ? widget.accounts.first.id : null);

    _destinationAccountId = AiSuggestionValidator.matchAccount(
      accountId: s.destinationAccountId,
      accountName: s.destinationAccountName,
      accounts: widget.accounts,
    )?.id;

    _cardId = AiSuggestionValidator.matchCard(
          cardId: s.creditCardId,
          cardName: s.creditCardName,
          cards: widget.cards,
        )?.id ??
        (widget.cards.length == 1 ? widget.cards.first.id : null);
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _newCategoryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _needsCategory =>
      _transactionType != 'transfer' && _transactionType != 'invoice_payment';

  bool get _isIncomeType =>
      _transactionType == 'income' || _transactionType == 'recurring_income';

  bool get _usesCard =>
      _transactionType == 'card_purchase' ||
      _transactionType == 'card_refund' ||
      _transactionType == 'invoice_payment';

  bool get _usesAccount =>
      _transactionType == 'expense' ||
      _transactionType == 'income' ||
      _transactionType == 'transfer' ||
      _transactionType == 'invoice_payment' ||
      _transactionType == 'recurring_expense' ||
      _transactionType == 'recurring_income';

  @override
  Widget build(BuildContext context) {
    final scopedCategories = widget.categories
        .where(
          (c) =>
              c.type ==
              (_isIncomeType ? CategoryType.income : CategoryType.expense),
        )
        .toList(growable: false);
    final selectedCatId =
        scopedCategories.any((c) => c.id == _categoryId) ? _categoryId : null;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: const Text('Editar proposta da IA'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _transactionType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de movimentação',
                    ),
                    items: [
                      for (final entry in _typeLabels.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _transactionType = value;
                        _categoryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Informe a descrição'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      prefixText: 'R\$ ',
                    ),
                    validator: (val) {
                      final cents = CurrencyFormatter.parseToCents(val ?? '');
                      if (cents == null || cents <= 0) {
                        return 'Informe um valor maior que zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && mounted) {
                        setState(() => _date = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('Data: ${DateFormatter.shortDate(_date)}'),
                  ),
                  if (_needsCategory) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCatId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      validator: (val) => !_createNewCategory &&
                              (val == null || val.isEmpty)
                          ? 'Selecione uma categoria'
                          : null,
                      items: [
                        for (final c in scopedCategories)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _createNewCategory
                          ? null
                          : (val) => setState(() => _categoryId = val),
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _createNewCategory,
                      onChanged: (val) {
                        setState(() => _createNewCategory = val ?? false);
                      },
                      title: const Text('Criar nova categoria ao confirmar'),
                    ),
                    if (_createNewCategory)
                      TextFormField(
                        controller: _newCategoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da nova categoria',
                        ),
                        validator: (val) => _createNewCategory &&
                                (val == null || val.trim().isEmpty)
                            ? 'Informe o nome da nova categoria'
                            : null,
                      ),
                  ],
                  if (_usesAccount) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: widget.accounts.any((a) => a.id == _accountId)
                          ? _accountId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _transactionType == 'transfer'
                            ? 'Conta de origem'
                            : 'Conta financeira',
                      ),
                      validator: (val) => (val == null || val.isEmpty)
                          ? 'Selecione a conta financeira'
                          : null,
                      items: [
                        for (final a in widget.accounts)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) => setState(() => _accountId = val),
                    ),
                  ],
                  if (_transactionType == 'transfer') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: widget.accounts
                              .any((a) => a.id == _destinationAccountId)
                          ? _destinationAccountId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Conta de destino',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Selecione a conta de destino';
                        }
                        if (val == _accountId) {
                          return 'Escolha uma conta diferente da origem';
                        }
                        return null;
                      },
                      items: [
                        for (final a in widget.accounts)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) =>
                          setState(() => _destinationAccountId = val),
                    ),
                  ],
                  if (_usesCard) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: widget.cards.any((c) => c.id == _cardId)
                          ? _cardId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cartão de crédito',
                      ),
                      validator: (val) => (val == null || val.isEmpty)
                          ? 'Selecione o cartão de crédito'
                          : null,
                      items: [
                        for (final c in widget.cards)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) => setState(() => _cardId = val),
                    ),
                  ],
                  if (_transactionType == 'card_purchase') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _installments,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Parcelas'),
                      items: [
                        for (var i = 1; i <= 24; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              i == 1 ? '1x (À vista)' : '${i}x',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _installments = val);
                      },
                    ),
                  ],
                  if (_transactionType == 'recurring_expense' ||
                      _transactionType == 'recurring_income') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Frequência'),
                      items: [
                        for (final f in RecurringFrequency.values)
                          if (f != RecurringFrequency.custom)
                            DropdownMenuItem(
                              value: f.storageValue,
                              child: Text(
                                f.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _frequency = val);
                      },
                    ),
                  ],
                  if (_transactionType == 'expense' ||
                      _transactionType == 'income') ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _settled,
                      onChanged: (val) => setState(() => _settled = val),
                      title: Text(
                        _transactionType == 'income'
                            ? 'Já recebida'
                            : 'Já paga',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amountCents = CurrencyFormatter.parseToCents(_amountCtrl.text) ?? 0;

    final selectedCategory = widget.categories
        .where((c) => c.id == _categoryId)
        .cast<CategoryEntity?>()
        .firstOrNull;
    final selectedAccount = widget.accounts
        .where((a) => a.id == _accountId)
        .cast<AccountEntity?>()
        .firstOrNull;
    final selectedDest = widget.accounts
        .where((a) => a.id == _destinationAccountId)
        .cast<AccountEntity?>()
        .firstOrNull;
    final selectedCard = widget.cards
        .where((c) => c.id == _cardId)
        .cast<CreditCardEntity?>()
        .firstOrNull;

    final updated = widget.initial.copyWith(
      success: amountCents > 0,
      transactionType: _transactionType,
      description: _descriptionCtrl.text.trim(),
      amountCents: amountCents,
      date: _date,
      categoryId: _createNewCategory ? null : selectedCategory?.id,
      clearCategoryId: _createNewCategory || selectedCategory == null,
      categorySuggestion: _createNewCategory
          ? _newCategoryCtrl.text.trim()
          : selectedCategory?.name,
      categoryIsNew: _createNewCategory,
      accountId: selectedAccount?.id,
      clearAccountId: selectedAccount == null,
      accountName: selectedAccount?.name,
      clearAccountName: selectedAccount == null,
      destinationAccountId: selectedDest?.id,
      clearDestinationAccountId: selectedDest == null,
      destinationAccountName: selectedDest?.name,
      clearDestinationAccountName: selectedDest == null,
      creditCardId: selectedCard?.id,
      clearCreditCardId: selectedCard == null,
      creditCardName: selectedCard?.name,
      clearCreditCardName: selectedCard == null,
      installments: _installments,
      frequency: _frequency,
      settled: _settled,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      missingInformation: const [],
    );

    Navigator.of(context).pop(updated);
  }
}
