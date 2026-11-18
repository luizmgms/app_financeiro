import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../application/controllers/credit_card_controller.dart';
import '../../domain/entities/credit_card_entity.dart';
import '../../domain/entities/invoice_entity.dart';

/// Modal para quitação consolidada de fatura de cartão de crédito.
Future<bool?> showPayInvoiceDialog(
  BuildContext context, {
  required InvoiceEntity invoice,
  required CreditCardEntity card,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => PayInvoiceDialog(
      invoice: invoice,
      card: card,
    ),
  );
}

class PayInvoiceDialog extends ConsumerStatefulWidget {
  const PayInvoiceDialog({
    super.key,
    required this.invoice,
    required this.card,
  });

  final InvoiceEntity invoice;
  final CreditCardEntity card;

  @override
  ConsumerState<PayInvoiceDialog> createState() => _PayInvoiceDialogState();
}

class _PayInvoiceDialogState extends ConsumerState<PayInvoiceDialog> {
  String? _selectedAccountId;
  DateTime _paymentDate = DateTime.now();
  String? _localError;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.card.paymentAccountId;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      setState(() => _localError = 'Selecione a conta de onde sairá o pagamento.');
      return;
    }

    final ok = await ref.read(creditCardControllerProvider.notifier).payInvoice(
          invoiceId: widget.invoice.id,
          paymentAccountId: _selectedAccountId!,
          paymentDate: _paymentDate,
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
    final accounts = ref.watch(activeAccountsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final locale = profile?.localeCode ?? 'pt_BR';
    final currency = profile?.defaultCurrency ?? 'BRL';
    final theme = Theme.of(context);

    if ((_selectedAccountId == null ||
            !accounts.any((acc) => acc.id == _selectedAccountId)) &&
        accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final formattedRemaining = CurrencyFormatter.formatCents(
      widget.invoice.remainingAmountCents,
      locale: locale,
      currencyCode: currency,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      title: Text('Pagar fatura ${widget.invoice.referenceLabel}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 6),
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.card.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vencimento: ${DateFormatter.shortDate(widget.invoice.dueDate)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Valor a quitar:'),
                        Text(
                          formattedRemaining,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Debitar da conta',
                ),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        '${account.name} (${CurrencyFormatter.formatCents(account.currentBalanceCents, locale: locale, currencyCode: currency)})',
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  'Data do pagamento: ${DateFormatter.shortDate(_paymentDate)}',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'O pagamento debita o saldo da conta selecionada, quita os lançamentos desta fatura e recompõe o limite disponível do cartão sem duplicar despesas nos relatórios.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: isLoading || accounts.isEmpty ? null : _submit,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(isLoading ? 'Pagando...' : 'Confirmar pagamento'),
        ),
      ],
    );
  }
}
