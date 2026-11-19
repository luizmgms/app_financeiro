import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../application/controllers/notification_controller.dart';

/// Modal para criação de lembretes financeiros personalizados.
Future<bool?> showCustomReminderDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const CustomReminderDialog(),
  );
}

class CustomReminderDialog extends ConsumerStatefulWidget {
  const CustomReminderDialog({super.key});

  @override
  ConsumerState<CustomReminderDialog> createState() =>
      _CustomReminderDialogState();
}

class _CustomReminderDialogState extends ConsumerState<CustomReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
  String? _localError;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final scheduled = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );

    final ok = await ref
        .read(notificationControllerProvider.notifier)
        .createCustomReminder(
          title: _titleController.text,
          body: _bodyController.text,
          scheduledFor: scheduled,
        );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _localError = ref.read(notificationControllerProvider).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(notificationControllerProvider).isLoading;
    final theme = Theme.of(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      title: const Text('Novo lembrete personalizado'),
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
                TextFormField(
                  controller: _titleController,
                  enabled: !isLoading,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Título do lembrete',
                    hintText: 'Ex.: Revisar faturas, Pagar IPVA, Transferir reserva',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe o título.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bodyController,
                  enabled: !isLoading,
                  maxLength: 240,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Detalhes (opcional)',
                    hintText: 'Observações ou instrução do lembrete',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        'Data: ${DateFormatter.shortDate(_scheduledDate)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                        'Horário: ${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
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
          child: Text(isLoading ? 'Salvando...' : 'Criar lembrete'),
        ),
      ],
    );
  }
}
