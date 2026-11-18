import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../application/controllers/account_controller.dart';
import '../../application/providers/account_providers.dart';

/// Formulário modal para transferência atômica entre duas contas ativas.
Future<bool?> showTransferFormDialog(
  BuildContext context, {
  String? initialSourceAccountId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => TransferFormDialog(
      initialSourceAccountId: initialSourceAccountId,
    ),
  );
}

class TransferFormDialog extends ConsumerStatefulWidget {
  const TransferFormDialog({super.key, this.initialSourceAccountId});

  final String? initialSourceAccountId;

  @override
  ConsumerState<TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends ConsumerState<TransferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String? _sourceId;
  String? _destinationId;
  DateTime _transferDate = DateTime.now();
  String? _localError;

  @override
  void initState() {
    super.initState();
    final active = ref.read(activeAccountsProvider);
    if (active.isNotEmpty) {
      _sourceId = widget.initialSourceAccountId ?? active.first.id;
      final alternative = active.where((a) => a.id != _sourceId);
      if (alternative.isNotEmpty) {
        _destinationId = alternative.first.id;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _transferDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amountCents = CurrencyFormatter.parseToCents(_amountController.text);
    if (amountCents == null || amountCents <= 0) {
      setState(() => _localError = 'Informe um valor maior que zero.');
      return;
    }
    if (_sourceId == null || _destinationId == null) {
      setState(() => _localError = 'Selecione as contas de origem e destino.');
      return;
    }

    final ok = await ref
        .read(accountControllerProvider.notifier)
        .transferBetweenAccounts(
          sourceAccountId: _sourceId!,
          destinationAccountId: _destinationId!,
          amountCents: amountCents,
          transferDate: _transferDate,
          description: _descriptionController.text,
          notes: _notesController.text,
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
    final accounts = ref.watch(activeAccountsProvider);
    final isLoading = ref.watch(accountControllerProvider).isLoading;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Transferência entre contas'),
      content: SizedBox(
        width: 460,
        child: accounts.length < 2
            ? const Text(
                'Cadastre pelo menos duas contas ativas para registrar uma transferência.',
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.transfer.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Transferências atualizam os saldos das duas contas atomicamente e não entram em receitas ou despesas.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.transfer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                        value: _sourceId,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Conta de origem'),
                        items: [
                          for (final acc in accounts)
                            DropdownMenuItem(
                              value: acc.id,
                              child: Text(
                                '${acc.name} (${CurrencyFormatter.formatCents(acc.currentBalanceCents)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _sourceId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _destinationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Conta de destino',
                        ),
                        items: [
                          for (final acc in accounts)
                            DropdownMenuItem(
                              value: acc.id,
                              child: Text(
                                '${acc.name} (${CurrencyFormatter.formatCents(acc.currentBalanceCents)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _destinationId = value),
                        validator: (value) {
                          if (value == null) return 'Selecione o destino.';
                          if (value == _sourceId) {
                            return 'O destino deve ser diferente da origem.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        enabled: !isLoading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor (R\$)',
                          hintText: '0,00',
                          prefixText: 'R\$ ',
                        ),
                        validator: (value) {
                          final cents =
                              CurrencyFormatter.parseToCents(value ?? '');
                          if (cents == null || cents <= 0) {
                            return 'Informe um valor maior que zero.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _pickDate,
                        icon:
                            const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(
                          'Data da transferência: ${DateFormatter.shortDate(_transferDate)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !isLoading,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Descrição (opcional)',
                          hintText: 'Ex.: Reserva mensal, PIX entre contas',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        enabled: !isLoading,
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
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        if (accounts.length >= 2)
          FilledButton(
            onPressed: isLoading ? null : _submit,
            child: Text(isLoading ? 'Transferindo...' : 'Transferir'),
          ),
      ],
    );
  }
}
