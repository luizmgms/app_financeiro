import 'package:flutter/material.dart';
import '../../core/utils/date_formatter.dart';

/// Campo compacto e reutilizável para selecionar data e horário preservando precisão cronológica.
class DateTimePickerField extends StatelessWidget {
  const DateTimePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.icon = Icons.calendar_today_outlined,
    this.timeIcon = Icons.schedule_rounded,
    this.firstDate,
    this.lastDate,
    this.onClear,
    this.clearTooltip = 'Limpar',
  });

  final String label;
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;
  final IconData icon;
  final IconData timeIcon;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final VoidCallback? onClear;
  final String clearTooltip;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) {
      onChanged(DateFormatter.preserveTime(picked, value));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      onChanged(DateFormatter.withTimeOfDay(value, picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: enabled ? () => _pickDate(context) : null,
          icon: Icon(icon, size: 17),
          label: Text('$label: ${DateFormatter.shortDate(value)}'),
        ),
        OutlinedButton.icon(
          onPressed: enabled ? () => _pickTime(context) : null,
          icon: Icon(timeIcon, size: 17),
          label: Text('Hora: ${DateFormatter.shortTime(value)}'),
        ),
        if (onClear != null)
          IconButton(
            tooltip: clearTooltip,
            onPressed: enabled ? onClear : null,
            icon: const Icon(Icons.clear_rounded, size: 18),
          ),
      ],
    );
  }
}
