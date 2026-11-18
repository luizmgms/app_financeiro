import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_catalog.dart';
import '../../../../shared/widgets/color_and_icon_picker.dart';
import '../../application/controllers/account_controller.dart';
import '../../domain/entities/account_entity.dart';

/// Formulário modal para cadastro e edição de contas financeiras.
Future<bool?> showAccountFormDialog(
  BuildContext context, {
  AccountEntity? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AccountFormDialog(existing: existing),
  );
}

class AccountFormDialog extends ConsumerStatefulWidget {
  const AccountFormDialog({super.key, this.existing});

  final AccountEntity? existing;

  @override
  ConsumerState<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _institutionController;
  late final TextEditingController _initialBalanceController;
  late AccountType _type;
  late String _colorHex;
  late String _iconName;
  late DateTime _openedAt;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _institutionController =
        TextEditingController(text: existing?.institution ?? '');

    final initialCents = existing?.initialBalanceCents ?? 0;
    final formattedInitial =
        (initialCents / 100.0).toStringAsFixed(2).replaceAll('.', ',');
    _initialBalanceController = TextEditingController(
      text: existing != null ? formattedInitial : '0,00',
    );

    _type = existing?.type ?? AccountType.checking;
    _colorHex = existing?.colorHex ?? '#0F766E';
    _iconName = existing?.iconName ?? _type.defaultIconName;
    _openedAt = existing?.openedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openedAt,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _openedAt = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsedCents =
        CurrencyFormatter.parseToCents(_initialBalanceController.text);
    if (parsedCents == null) {
      setState(() => _localError = 'Informe um saldo inicial válido.');
      return;
    }

    final ok = await ref.read(accountControllerProvider.notifier).saveAccount(
          existing: widget.existing,
          name: _nameController.text,
          institution: _institutionController.text,
          type: _type,
          initialBalanceCents: parsedCents,
          colorHex: _colorHex,
          iconName: _iconName,
          openedAt: _openedAt,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _localError = ref.read(accountControllerProvider).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(accountControllerProvider).isLoading;
    final isEditing = widget.existing != null;
    final theme = Theme.of(context);
    final accent = ColorUtils.fromHex(_colorHex);

    return AlertDialog(
      title: Text(isEditing ? 'Editar conta' : 'Nova conta'),
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
                TextFormField(
                  controller: _nameController,
                  enabled: !isLoading,
                  maxLength: 60,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nome da conta',
                    hintText: 'Ex.: Nubank Principal, Carteira, Reserva',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da conta.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _institutionController,
                  enabled: !isLoading,
                  maxLength: 60,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Instituição financeira (opcional)',
                    hintText: 'Ex.: Nubank, Itaú, Inter, Dinheiro',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AccountType>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Tipo de conta'),
                  items: [
                    for (final item in AccountType.values)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _type = value;
                            if (!isEditing) {
                              _iconName = value.defaultIconName;
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _initialBalanceController,
                  enabled: !isLoading,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Saldo inicial (R\$)',
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    if (CurrencyFormatter.parseToCents(value ?? '') == null) {
                      return 'Informe um valor monetário válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    'Data de abertura: ${DateFormatter.shortDate(_openedAt)}',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Cor de identificação',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ColorPickerRow(
                  selectedHex: _colorHex,
                  onSelected: (hex) => setState(() => _colorHex = hex),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ícone',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                IconPickerGrid(
                  options: IconCatalog.accountOptions,
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
