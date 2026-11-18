import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/money.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../application/controllers/credit_card_controller.dart';
import '../../application/providers/credit_card_providers.dart';
import '../../domain/entities/credit_card_entity.dart';
import '../../domain/services/credit_card_cycle_calculator.dart';

/// Modos de lançamento suportados pelo formulário do cartão/parcelamento.
enum CardLaunchMode {
  cardPurchase,
  standaloneRefund,
  accountInstallment,
}

/// Modal para lançar compra no cartão de crédito (à vista ou parcelada),
/// estorno/crédito avulso na fatura ou despesa parcelada diretamente em conta.
Future<bool?> showCardPurchaseFormDialog(
  BuildContext context, {
  String? initialCardId,
  int initialInstallments = 1,
  bool startInAccountMode = false,
  bool startInRefundMode = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CardPurchaseFormDialog(
      initialCardId: initialCardId,
      initialInstallments: initialInstallments,
      startInAccountMode: startInAccountMode,
      startInRefundMode: startInRefundMode,
    ),
  );
}

class CardPurchaseFormDialog extends ConsumerStatefulWidget {
  const CardPurchaseFormDialog({
    super.key,
    this.initialCardId,
    this.initialInstallments = 1,
    this.startInAccountMode = false,
    this.startInRefundMode = false,
  });

  final String? initialCardId;
  final int initialInstallments;
  final bool startInAccountMode;
  final bool startInRefundMode;

  @override
  ConsumerState<CardPurchaseFormDialog> createState() =>
      _CardPurchaseFormDialogState();
}

class _CardPurchaseFormDialogState
    extends ConsumerState<CardPurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  late CardLaunchMode _mode;
  String? _selectedCardId;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  late int _installments;
  DateTime _purchaseDate = DateTime.now();
  String? _localError;

  bool get _isAccountMode => _mode == CardLaunchMode.accountInstallment;
  bool get _isRefundMode => _mode == CardLaunchMode.standaloneRefund;

  @override
  void initState() {
    super.initState();
    if (widget.startInRefundMode) {
      _mode = CardLaunchMode.standaloneRefund;
    } else if (widget.startInAccountMode) {
      _mode = CardLaunchMode.accountInstallment;
    } else {
      _mode = CardLaunchMode.cardPurchase;
    }
    _selectedCardId = widget.initialCardId;
    _installments = _isAccountMode && widget.initialInstallments < 2
        ? 2
        : (widget.initialInstallments < 1 ? 1 : widget.initialInstallments);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
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

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      setState(() => _localError = 'Selecione uma categoria.');
      return;
    }

    final controller = ref.read(creditCardControllerProvider.notifier);
    bool ok;

    if (_isAccountMode) {
      if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
        setState(() => _localError = 'Selecione uma conta para o parcelamento.');
        return;
      }
      ok = await controller.recordAccountInstallmentPurchase(
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text,
        totalAmountCents: parsedCents,
        purchaseDate: _purchaseDate,
        totalInstallments: _installments,
        notes: _notesController.text,
      );
    } else if (_isRefundMode) {
      if (_selectedCardId == null || _selectedCardId!.isEmpty) {
        setState(() => _localError = 'Selecione um cartão de crédito.');
        return;
      }
      ok = await controller.recordCardStandaloneRefund(
        cardId: _selectedCardId!,
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text,
        amountCents: parsedCents,
        refundDate: _purchaseDate,
        notes: _notesController.text,
      );
    } else {
      if (_selectedCardId == null || _selectedCardId!.isEmpty) {
        setState(() => _localError = 'Selecione um cartão de crédito.');
        return;
      }
      ok = await controller.recordCardPurchase(
        cardId: _selectedCardId!,
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text,
        totalAmountCents: parsedCents,
        purchaseDate: _purchaseDate,
        totalInstallments: _installments,
        notes: _notesController.text,
      );
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _localError = ref.read(creditCardControllerProvider).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(creditCardControllerProvider).isLoading;
    final cards = ref.watch(activeCreditCardsProvider);
    final accounts = ref.watch(activeAccountsProvider);
    final expenseCategories = ref
        .watch(activeCategoriesProvider)
        .where((c) => c.type == CategoryType.expense)
        .toList(growable: false);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final theme = Theme.of(context);

    if (!_isAccountMode &&
        (_selectedCardId == null ||
            !cards.any((card) => card.id == _selectedCardId)) &&
        cards.isNotEmpty) {
      _selectedCardId = cards.first.id;
    }
    if (_isAccountMode &&
        (_selectedAccountId == null ||
            !accounts.any((acc) => acc.id == _selectedAccountId)) &&
        accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }
    if ((_selectedCategoryId == null ||
            !expenseCategories.any((cat) => cat.id == _selectedCategoryId)) &&
        expenseCategories.isNotEmpty) {
      _selectedCategoryId = expenseCategories.first.id;
    }

    CreditCardEntity? selectedCard;
    if (!_isAccountMode && _selectedCardId != null) {
      for (final card in cards) {
        if (card.id == _selectedCardId) {
          selectedCard = card;
          break;
        }
      }
    }

    final parsedCents =
        CurrencyFormatter.parseToCents(_amountController.text) ?? 0;
    final splitSlices = parsedCents > 0 && !_isRefundMode
        ? Money(cents: parsedCents).splitEqually(_installments)
        : const <Money>[];

    final cyclePreview = selectedCard != null
        ? CreditCardCycleCalculator.resolveInvoiceForPurchase(
            cardId: selectedCard.id,
            purchaseDate: _purchaseDate,
            closingDay: selectedCard.closingDay,
            dueDay: selectedCard.dueDay,
          )
        : null;

    final titleText = switch (_mode) {
      CardLaunchMode.cardPurchase => 'Nova compra no cartão',
      CardLaunchMode.standaloneRefund => 'Estorno avulso no cartão',
      CardLaunchMode.accountInstallment => 'Parcelamento em conta',
    };

    final bannerAccent =
        _isRefundMode ? AppColors.income : AppColors.primaryLight;

    final amountField = TextFormField(
      controller: _amountController,
      enabled: !isLoading,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: _isRefundMode ? 'Valor do estorno (R\$)' : 'Valor total (R\$)',
        hintText: '0,00',
        prefixText: 'R\$ ',
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final parsed = CurrencyFormatter.parseToCents(value ?? '');
        if (parsed == null || parsed <= 0) {
          return 'Valor inválido.';
        }
        return null;
      },
    );

    final installmentsField = DropdownButtonFormField<int>(
      value: _installments,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Parcelas',
      ),
      items: [
        for (var i = (_isAccountMode ? 2 : 1); i <= 36; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
              i == 1 ? '1x (À vista)' : '${i}x',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
      onChanged: isLoading
          ? null
          : (value) {
              if (value != null) {
                setState(() => _installments = value);
              }
            },
    );

    const modeOptions = [
      (
        mode: CardLaunchMode.cardPurchase,
        label: 'Compra',
        tooltip: 'Compra no cartão de crédito',
        icon: Icons.credit_card_rounded,
      ),
      (
        mode: CardLaunchMode.standaloneRefund,
        label: 'Estorno',
        tooltip: 'Estorno avulso na fatura',
        icon: Icons.replay_rounded,
      ),
      (
        mode: CardLaunchMode.accountInstallment,
        label: 'Em conta',
        tooltip: 'Parcelamento direto em conta',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    void onModeSelected(CardLaunchMode nextMode) {
      if (isLoading || _mode == nextMode) return;
      setState(() {
        _mode = nextMode;
        if (_isAccountMode && _installments < 2) {
          _installments = 2;
        } else if (_isRefundMode) {
          _installments = 1;
        }
      });
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      title: Text(titleText),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 6),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final option in modeOptions)
                      _CompactLaunchModeButton(
                        label: option.label,
                        tooltip: option.tooltip,
                        icon: option.icon,
                        selected: _mode == option.mode,
                        accentColor: option.mode == CardLaunchMode.standaloneRefund
                            ? AppColors.income
                            : theme.colorScheme.primary,
                        onTap: isLoading
                            ? null
                            : () => onModeSelected(option.mode),
                      ),
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
                if (!_isAccountMode)
                  DropdownButtonFormField<String>(
                    value: _selectedCardId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cartão de crédito',
                    ),
                    items: [
                      for (final card in cards)
                        DropdownMenuItem(
                          value: card.id,
                          child: Text(
                            '${card.name} (${CurrencyFormatter.formatCents(card.availableLimitCents, locale: locale, currencyCode: currency)} disp.)',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (value) {
                            setState(() => _selectedCardId = value);
                          },
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Conta bancária / carteira',
                    ),
                    items: [
                      for (final account in accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            account.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (value) {
                            setState(() => _selectedAccountId = value);
                          },
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !isLoading,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _isRefundMode
                        ? 'Descrição do estorno / crédito'
                        : 'Descrição da compra',
                    hintText: _isRefundMode
                        ? 'Ex.: Estorno parcial, Cashback, Ajuste de centavos'
                        : 'Ex.: Notebook, Supermercado, Seguro Auto',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a descrição.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (_isRefundMode) return amountField;
                    if (constraints.maxWidth < 250) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          amountField,
                          const SizedBox(height: 10),
                          installmentsField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: amountField),
                        const SizedBox(width: 10),
                        Expanded(child: installmentsField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _isRefundMode
                        ? 'Categoria abatida pelo estorno'
                        : 'Categoria de despesa',
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
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() => _selectedCategoryId = value);
                        },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    '${_isRefundMode ? 'Data do estorno' : 'Data da compra'}: ${DateFormatter.shortDate(_purchaseDate)}',
                  ),
                ),
                const SizedBox(height: 12),
                if (cyclePreview != null ||
                    splitSlices.isNotEmpty ||
                    (_isRefundMode && parsedCents > 0))
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bannerAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: bannerAccent.withOpacity(0.24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isRefundMode) ...[
                          if (cyclePreview != null)
                            Text(
                              'Crédito na fatura ${cyclePreview.referenceMonth.toString().padLeft(2, '0')}/${cyclePreview.referenceYear} (venc. ${DateFormatter.shortDate(cyclePreview.dueDate)})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.income,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            parsedCents > 0
                                ? 'Abate ${CurrencyFormatter.formatCents(parsedCents, locale: locale, currencyCode: currency)} da fatura e recompõe o limite disponível do cartão, sem exigir vínculo com uma compra específica.'
                                : 'Abate o valor informado diretamente na fatura e recompõe o limite disponível do cartão.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ] else ...[
                          if (cyclePreview != null)
                            Text(
                              _installments > 1
                                  ? '1ª parcela na fatura ${cyclePreview.referenceMonth.toString().padLeft(2, '0')}/${cyclePreview.referenceYear} (venc. ${DateFormatter.shortDate(cyclePreview.dueDate)})'
                                  : 'Entra na fatura ${cyclePreview.referenceMonth.toString().padLeft(2, '0')}/${cyclePreview.referenceYear} (fech. ${DateFormatter.shortDate(cyclePreview.closingDate)} • venc. ${DateFormatter.shortDate(cyclePreview.dueDate)})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          if (splitSlices.isNotEmpty) ...[
                            if (cyclePreview != null) const SizedBox(height: 4),
                            Text(
                              _installments == 1
                                  ? 'À vista: ${CurrencyFormatter.formatCents(splitSlices.first.cents, locale: locale, currencyCode: currency)}'
                                  : splitSlices.first.cents ==
                                          splitSlices.last.cents
                                      ? '$_installments parcelas de ${CurrencyFormatter.formatCents(splitSlices.first.cents, locale: locale, currencyCode: currency)}'
                                      : '1ª parcela de ${CurrencyFormatter.formatCents(splitSlices.first.cents, locale: locale, currencyCode: currency)} + ${_installments - 1}x de ${CurrencyFormatter.formatCents(splitSlices.last.cents, locale: locale, currencyCode: currency)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ],
                    ),
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
          onPressed: isLoading ? null : _submit,
          child: Text(
            isLoading
                ? 'Registrando...'
                : (_isRefundMode ? 'Registrar estorno' : 'Registrar'),
          ),
        ),
      ],
    );
  }
}

class _CompactLaunchModeButton extends StatelessWidget {
  const _CompactLaunchModeButton({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = selected
        ? accentColor
        : theme.colorScheme.onSurface.withOpacity(0.85);
    final backgroundColor = selected
        ? accentColor.withOpacity(0.16)
        : theme.colorScheme.surfaceVariant.withOpacity(0.22);
    final borderColor = selected
        ? accentColor.withOpacity(0.75)
        : theme.colorScheme.outline.withOpacity(0.4);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor, width: selected ? 1.3 : 1),
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
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
