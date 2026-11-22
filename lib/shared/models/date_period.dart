import 'dart:math' as math;
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

  /// Calcula o intervalo de um mês contábil (`year`/`month`) respeitando [monthStartDay] (`1..28`).
  /// Ex.: para `monthStartDay = 5` e `11/2026`, o período vai de `05/11/2026` a `04/12/2026 23:59:59.999`.
  factory DatePeriod.accountingMonth(
    int year,
    int month, {
    int monthStartDay = 1,
    DatePeriodType type = DatePeriodType.custom,
  }) {
    final safeStartDay = monthStartDay.clamp(1, 28);
    if (safeStartDay == 1) {
      return DatePeriod(
        type: type,
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 0, 23, 59, 59, 999),
      );
    }

    final maxInStart = DateTime(year, month + 1, 0).day;
    final start = DateTime(year, month, math.min(safeStartDay, maxInStart));
    final nextMonthAnchor = DateTime(year, month + 1, 1);
    final maxInNext =
        DateTime(nextMonthAnchor.year, nextMonthAnchor.month + 1, 0).day;
    final nextCycleStart = DateTime(
      nextMonthAnchor.year,
      nextMonthAnchor.month,
      math.min(safeStartDay, maxInNext),
    );
    final endDay = nextCycleStart.subtract(const Duration(days: 1));
    return DatePeriod(
      type: type,
      start: start,
      end: DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59, 999),
    );
  }

  /// Determina a referência `(year, month)` contábil de uma data conforme [monthStartDay].
  static ({int year, int month}) resolveAccountingYearMonth(
    DateTime date, {
    int monthStartDay = 1,
  }) {
    final safeStartDay = monthStartDay.clamp(1, 28);
    if (safeStartDay <= 1 || date.day >= safeStartDay) {
      return (year: date.year, month: date.month);
    }
    final prev = DateTime(date.year, date.month - 1, 1);
    return (year: prev.year, month: prev.month);
  }

  factory DatePeriod.fromType(
    DatePeriodType type, {
    DateTime? reference,
    int monthStartDay = 1,
  }) {
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
      DatePeriodType.thisMonth => () {
          final ym = resolveAccountingYearMonth(
            now,
            monthStartDay: monthStartDay,
          );
          return DatePeriod.accountingMonth(
            ym.year,
            ym.month,
            monthStartDay: monthStartDay,
            type: type,
          );
        }(),
      DatePeriodType.previousMonth => () {
          final ym = resolveAccountingYearMonth(
            now,
            monthStartDay: monthStartDay,
          );
          final prevAnchor = DateTime(ym.year, ym.month - 1, 1);
          return DatePeriod.accountingMonth(
            prevAnchor.year,
            prevAnchor.month,
            monthStartDay: monthStartDay,
            type: type,
          );
        }(),
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

  bool contains(DateTime date) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  @override
  List<Object?> get props => [type, start, end];
}
