import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/attachment_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/date_time_picker_row.dart';
import '../../../accounts/application/providers/account_providers.dart';
import '../../../accounts/presentation/widgets/account_form_dialog.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../application/controllers/transaction_controller.dart';
import '../../application/providers/transaction_providers.dart';
import '../../domain/entities/transaction_attachment.dart';
import '../../domain/entities/transaction_entity.dart';

/// Formulário modal rápido e completo para receitas e despesas (novo, edição ou duplicação).
Future<bool?> showTransactionFormDialog(
  BuildContext context, {
  TransactionEntity? existing,
  TransactionEntity? duplicateFrom,
  TransactionKind initialKind = TransactionKind.expense,
  String? initialAccountId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => TransactionFormDialog(
      existing: existing,
      duplicateFrom: duplicateFrom,
      initialKind: initialKind,
      initialAccountId: initialAccountId,
    ),
  );
}

class TransactionFormDialog extends ConsumerStatefulWidget {
  const TransactionFormDialog({
    super.key,
    this.existing,
    this.duplicateFrom,
    this.initialKind = TransactionKind.expense,
    this.initialAccountId,
  });

  final TransactionEntity? existing;
  final TransactionEntity? duplicateFrom;
  final TransactionKind initialKind;
  final String? initialAccountId;

  @override
  ConsumerState<TransactionFormDialog> createState() =>
      _TransactionFormDialogState();
}

class _TransactionFormDialogState extends ConsumerState<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late TransactionKind _kind;
  late TransactionStatus _status;
  String? _categoryId;
  String? _accountId;
  late DateTime _competencyDate;
  DateTime? _dueDate;
  DateTime? _paymentDate;

  late List<TransactionAttachment> _keptAttachments;
  final List<TransactionAttachment> _removedAttachments = [];
  final List<PickedAttachment> _newAttachments = [];
  String? _localError;

  @override
  void initState() {
    super.initState();
    final source = widget.existing ?? widget.duplicateFrom;
    final isDuplicating = widget.duplicateFrom != null;

    _kind = source?.kind == TransactionKind.income
        ? TransactionKind.income
        : (source?.kind == TransactionKind.expense
            ? TransactionKind.expense
            : widget.initialKind);

    _descriptionController =
        TextEditingController(text: source?.description ?? '');

    final initialCents = source?.amountCents ?? 0;
    _amountController = TextEditingController(
      text: initialCents > 0
          ? (initialCents / 100.0).toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _notesController = TextEditingController(text: source?.notes ?? '');

    _categoryId = source?.categoryId;
    _accountId = source?.accountId ?? widget.initialAccountId;

    if (widget.existing != null) {
      _competencyDate = widget.existing!.competencyDate;
      _dueDate = widget.existing!.dueDate;
      _paymentDate = widget.existing!.paymentDate;
      _status = widget.existing!.status;
      _keptAttachments = List.of(widget.existing!.attachments);
    } else {
      final now = DateTime.now();
      _competencyDate = now;
      _dueDate = _kind == TransactionKind.expense ? now : null;
      _status = isDuplicating
          ? TransactionStatus.pending
          : (_kind == TransactionKind.income
              ? TransactionStatus.received
              : TransactionStatus.paid);
      _paymentDate = _status.isSettled ? now : null;
      _keptAttachments = <TransactionAttachment>[];
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<TransactionStatus> _statusOptionsForKind(TransactionKind kind) {
    if (kind == TransactionKind.income) {
      return const [TransactionStatus.received, TransactionStatus.pending];
    }
    return const [
      TransactionStatus.paid,
      TransactionStatus.pending,
      TransactionStatus.overdue,
    ];
  }

  Future<void> _pickAttachment() async {
    setState(() => _localError = null);
    try {
      final picked =
          await ref.read(attachmentStorageServiceProvider).pickAttachment();
      if (picked != null && mounted) {
        setState(() => _newAttachments.add(picked));
      }
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _localError = failure.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _localError = formatUnexpectedFailureMessage(
            error,
            fallbackMessage: 'Não foi possível selecionar o arquivo.',
          );
        });
      }
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onPicked(picked);
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

    final ok =
        await ref.read(transactionControllerProvider.notifier).saveTransaction(
              existing: widget.existing,
              kind: _kind,
              description: _descriptionController.text,
              amountCents: amountCents,
              categoryId: _categoryId,
              accountId: _accountId,
              competencyDate: _competencyDate,
              dueDate: _dueDate,
              paymentDate: _status.isSettled ? (_paymentDate ?? _competencyDate) : null,
              status: _status,
              notes: _notesController.text,
              newAttachments: _newAttachments,
              removedAttachments: _removedAttachments,
            );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _localError = ref.read(transactionControllerProvider).errorMessage ??
            'Não foi possível salvar a movimentação.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider);
    final categories = ref.watch(activeCategoriesProvider);
    final isLoading = ref.watch(transactionControllerProvider).isLoading;
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    final targetCategoryType = _kind == TransactionKind.income
        ? CategoryType.income
        : CategoryType.expense;
    final matchingCategories = categories
        .where((c) => c.type == targetCategoryType)
        .toList(growable: false);

    if (_accountId != null && !accounts.any((a) => a.id == _accountId)) {
      _accountId = accounts.isNotEmpty ? accounts.first.id : null;
    } else if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

    if (_categoryId != null &&
        !matchingCategories.any((c) => c.id == _categoryId)) {
      _categoryId =
          matchingCategories.isNotEmpty ? matchingCategories.first.id : null;
    } else if (_categoryId == null && matchingCategories.isNotEmpty) {
      _categoryId = matchingCategories.first.id;
    }

    final statusOptions = _statusOptionsForKind(_kind);
    if (!statusOptions.contains(_status)) {
      _status = statusOptions.first;
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      title: Text(
        isEditing
            ? 'Editar movimentação'
            : (widget.duplicateFrom != null
                ? 'Duplicar movimentação'
                : 'Nova movimentação'),
      ),
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
                SegmentedButton<TransactionKind>(
                  segments: const [
                    ButtonSegment<TransactionKind>(
                      value: TransactionKind.expense,
                      label: Text('Despesa'),
                      icon: Icon(Icons.trending_down_rounded),
                    ),
                    ButtonSegment<TransactionKind>(
                      value: TransactionKind.income,
                      label: Text('Receita'),
                      icon: Icon(Icons.trending_up_rounded),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: isEditing || isLoading
                      ? null
                      : (selection) {
                          setState(() {
                            _kind = selection.first;
                            _status = _kind == TransactionKind.income
                                ? TransactionStatus.received
                                : TransactionStatus.paid;
                            _categoryId = null;
                          });
                        },
                ),
                const SizedBox(height: 14),
                if (accounts.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.warning),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Cadastre uma conta antes de registrar lançamentos.',
                          ),
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => showAccountFormDialog(context),
                          child: const Text('Criar conta'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _descriptionController,
                  enabled: !isLoading,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    hintText: _kind == TransactionKind.income
                        ? 'Ex.: Salário, Projeto freelance'
                        : 'Ex.: Supermercado, Aluguel, Farmácia',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a descrição.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  enabled: !isLoading,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    final cents = CurrencyFormatter.parseToCents(value ?? '');
                    if (cents == null || cents <= 0) {
                      return 'Informe um valor maior que zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final category in matchingCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Selecione uma categoria.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _accountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _kind == TransactionKind.income
                        ? 'Conta de destino'
                        : 'Conta de pagamento',
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
                      : (value) => setState(() => _accountId = value),
                  validator: (value) =>
                      value == null ? 'Selecione uma conta.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TransactionStatus>(
                  value: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final item in statusOptions)
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
                          if (value == null) return;
                          setState(() {
                            _status = value;
                            if (value.isSettled && _paymentDate == null) {
                              _paymentDate = _competencyDate;
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                DateTimePickerField(
                  label: _kind == TransactionKind.income
                      ? 'Competência'
                      : 'Lançamento',
                  icon: Icons.event_note_outlined,
                  value: _competencyDate,
                  enabled: !isLoading,
                  onChanged: (date) => setState(() => _competencyDate = date),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _pickDate(
                                initial: _dueDate ?? _competencyDate,
                                onPicked: (date) =>
                                    setState(() => _dueDate = date),
                              ),
                      icon:
                          const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        _dueDate != null
                            ? 'Vencimento: ${DateFormatter.shortDate(_dueDate!)}'
                            : 'Definir vencimento',
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        tooltip: 'Remover vencimento',
                        onPressed: isLoading
                            ? null
                            : () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.clear_rounded, size: 18),
                      ),
                  ],
                ),
                if (_status.isSettled) ...[
                  const SizedBox(height: 10),
                  DateTimePickerField(
                    label: _kind == TransactionKind.income
                        ? 'Recebido em'
                        : 'Pago em',
                    icon: Icons.event_available_outlined,
                    value: _paymentDate ?? _competencyDate,
                    enabled: !isLoading,
                    onChanged: (date) => setState(() => _paymentDate = date),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  enabled: !isLoading,
                  maxLines: 2,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comprovantes e anexos',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isLoading ? null : _pickAttachment,
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: const Text('Anexar'),
                    ),
                  ],
                ),
                for (final att in _keptAttachments)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      att.isImage
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                    ),
                    title: Text(att.name, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                _keptAttachments.remove(att);
                                _removedAttachments.add(att);
                              });
                            },
                    ),
                  ),
                for (final picked in _newAttachments)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: picked.isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              picked.bytes,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image_outlined),
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(picked.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      'Pronto para envio (${(picked.sizeBytes / 1024).toStringAsFixed(1)} KB)',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _newAttachments.remove(picked)),
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
          onPressed: isLoading || accounts.isEmpty ? null : _submit,
          child: Text(isLoading ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}
