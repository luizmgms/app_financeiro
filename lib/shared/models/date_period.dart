import 'package:equatable/equatable.dart';

enum DatePeriodType {
  today('Hoje'),
  thisWeek('Esta semana'),
  thisMonth('Este mês'),
  previousMonth('Mês anterior'),
  custom('Personalizado');

  const DatePeriodType(this.label);

  final String label;
}

/// Filtro de período financeiro utilizado no dashboard, movimentações e relatórios.
class DatePeriod extends Equatable {
  const DatePeriod({
    required this.type,
    required this.start,
    required this.end,
  });

  factory DatePeriod.fromType(DatePeriodType type, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return switch (type) {
      DatePeriodType.today => DatePeriod(
          type: type,
          start: todayStart,
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        ),
      DatePeriodType.thisWeek => () {
          final startOfWeek =
              todayStart.subtract(Duration(days: todayStart.weekday - 1));
          final endOfWeek = startOfWeek.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          );
          return DatePeriod(type: type, start: startOfWeek, end: endOfWeek);
        }(),
      DatePeriodType.thisMonth => DatePeriod(
          type: type,
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
        ),
      DatePeriodType.previousMonth => DatePeriod(
          type: type,
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59, 999),
        ),
      DatePeriodType.custom => DatePeriod(
          type: type,
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        ),
    };
  }

  final DatePeriodType type;
  final DateTime start;
  final DateTime end;

  @override
  List<Object?> get props => [type, start, end];
}
