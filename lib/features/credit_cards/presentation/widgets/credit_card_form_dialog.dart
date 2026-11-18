import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/color_and_icon_picker.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../application/controllers/credit_card_controller.dart';
import '../../domain/entities/credit_card_entity.dart';

/// Formulário modal para cadastro e edição de cartões de crédito.
Future<bool?> showCreditCardFormDialog(
  BuildContext context, {
  CreditCardEntity? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CreditCardFormDialog(existing: existing),
  );
}

class CreditCardFormDialog extends ConsumerStatefulWidget {
  const CreditCardFormDialog({super.key, this.existing});

  final CreditCardEntity? existing;

  @override
  ConsumerState<CreditCardFormDialog> createState() =>
      _CreditCardFormDialogState();
}

class _CreditCardFormDialogState extends ConsumerState<CreditCardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _institutionController;
  late final TextEditingController _limitController;
  late CardBrand _brand;
  late int _closingDay;
  late int _dueDay;
  String? _paymentAccountId;
  late String _colorHex;
  late int _defaultInstallments;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _institutionController =
        TextEditingController(text: existing?.institution ?? '');

    final limitCents = existing?.totalLimitCents ?? 0;
    final formattedLimit =
        (limitCents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
    _limitController = TextEditingController(
      text: existing != null ? formattedLimit : '2500,00',
    );

    _brand = existing?.brand ?? CardBrand.mastercard;
    _closingDay = existing?.closingDay ?? 5;
    _dueDay = existing?.dueDay ?? 12;
    _paymentAccountId = existing?.paymentAccountId;
    _colorHex = existing?.colorHex ?? '#7C3AED';
    _defaultInstallments = existing?.defaultInstallments ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsedLimitCents =
        CurrencyFormatter.parseToCents(_limitController.text);
    if (parsedLimitCents == null || parsedLimitCents < 0) {
      setState(() => _localError = 'Informe um limite total válido.');
      return;
    }

    final ok =
        await ref.read(creditCardControllerProvider.notifier).saveCard(
              existing: widget.existing,
              name: _nameController.text,
              institution: _institutionController.text,
              brand: _brand,
              totalLimitCents: parsedLimitCents,
              closingDay: _closingDay,
              dueDay: _dueDay,
              paymentAccountId: _paymentAccountId,
              colorHex: _colorHex,
              defaultInstallments: _defaultInstallments,
            );

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
    final activeAccounts = ref.watch(activeAccountsProvider);
    final isEditing = widget.existing != null;
    final theme = Theme.of(context);

    final validPaymentAccountId = activeAccounts
            .any((acc) => acc.id == _paymentAccountId)
        ? _paymentAccountId
        : null;

    final nameField = TextFormField(
      controller: _nameController,
      enabled: !isLoading,
      maxLength: 60,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Nome do cartão',
        hintText: 'Ex.: Nubank Ultravioleta, Itaú Click',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Informe o nome do cartão.';
        }
        return null;
      },
    );

    final institutionField = TextFormField(
      controller: _institutionController,
      enabled: !isLoading,
      maxLength: 60,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Instituição (opcional)',
        hintText: 'Ex.: Nubank, Itaú',
      ),
    );

    final brandField = DropdownButtonFormField<CardBrand>(
      value: _brand,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Bandeira',
      ),
      items: [
        for (final item in CardBrand.values)
          DropdownMenuItem(
            value: item,
            child: Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
      onChanged: isLoading
          ? null
          : (value) {
              if (value != null) {
                setState(() => _brand = value);
              }
            },
    );

    final limitField = TextFormField(
      controller: _limitController,
      enabled: !isLoading,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Limite total (R\$)',
        hintText: '0,00',
        prefixText: 'R\$ ',
      ),
      validator: (value) {
        final parsed = CurrencyFormatter.parseToCents(value ?? '');
        if (parsed == null || parsed < 0) {
          return 'Informe um limite válido.';
        }
        return null;
      },
    );

    DropdownButtonFormField<int> buildDayField({
      required int value,
      required String labelText,
      required ValueChanged<int> onPicked,
    }) {
      return DropdownButtonFormField<int>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: labelText),
        items: [
          for (var day = 1; day <= 31; day++)
            DropdownMenuItem(
              value: day,
              child: Text(
                'Dia $day',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
        onChanged: isLoading
            ? null
            : (picked) {
                if (picked != null) onPicked(picked);
              },
      );
    }

    final paymentAccountField = DropdownButtonFormField<String?>(
      value: validPaymentAccountId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Conta padrão para fatura',
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Nenhuma selecionada',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        for (final account in activeAccounts)
          DropdownMenuItem<String?>(
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
              setState(() => _paymentAccountId = value);
            },
    );

    final defaultInstallmentsField = DropdownButtonFormField<int>(
      value: _defaultInstallments,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Parcelas padrão',
      ),
      items: [
        for (var i = 1; i <= 12; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
              '${i}x',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
      onChanged: isLoading
          ? null
          : (value) {
              if (value != null) {
                setState(() => _defaultInstallments = value);
              }
            },
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      title: Text(isEditing ? 'Editar cartão de crédito' : 'Novo cartão'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final closingField = buildDayField(
                value: _closingDay,
                labelText: isNarrow ? 'Dia fechamento' : 'Dia de fechamento',
                onPicked: (day) => setState(() => _closingDay = day),
              );
              final dueField = buildDayField(
                value: _dueDay,
                labelText: isNarrow ? 'Dia vencimento' : 'Dia de vencimento',
                onPicked: (day) => setState(() => _dueDay = day),
              );

              return Form(
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
                    nameField,
                    const SizedBox(height: 10),
                    if (isNarrow) ...[
                      institutionField,
                      const SizedBox(height: 10),
                      brandField,
                    ] else
                      Row(
                        children: [
                          Expanded(child: institutionField),
                          const SizedBox(width: 12),
                          Expanded(child: brandField),
                        ],
                      ),
                    const SizedBox(height: 12),
                    limitField,
                    const SizedBox(height: 12),
                    if (constraints.maxWidth < 250) ...[
                      closingField,
                      const SizedBox(height: 12),
                      dueField,
                    ] else
                      Row(
                        children: [
                          Expanded(child: closingField),
                          const SizedBox(width: 10),
                          Expanded(child: dueField),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (isNarrow) ...[
                      paymentAccountField,
                      const SizedBox(height: 12),
                      defaultInstallmentsField,
                    ] else
                      Row(
                        children: [
                          Expanded(flex: 2, child: paymentAccountField),
                          const SizedBox(width: 12),
                          Expanded(child: defaultInstallmentsField),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'Cor do cartão',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ColorPickerRow(
                      selectedHex: _colorHex,
                      onSelected: (hex) => setState(() => _colorHex = hex),
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
