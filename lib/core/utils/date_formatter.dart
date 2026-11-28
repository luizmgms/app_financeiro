import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formatadores e utilitários de data padronizados com suporte a `pt_BR`.
abstract final class DateFormatter {
  static String shortDate(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('dd/MM/yyyy', locale).format(date);
  }

  static String shortTime(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('HH:mm', locale).format(date);
  }

  static String shortDateTime(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('dd/MM/yyyy HH:mm', locale).format(date);
  }

  static String dayMonth(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('dd MMM', locale).format(date);
  }

  static String monthYear(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('MMMM yyyy', locale).format(date);
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Combina ano/mês/dia de [date] mantendo hora/minuto/segundo/ms de [timeSource].
  static DateTime preserveTime(DateTime date, DateTime timeSource) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      timeSource.hour,
      timeSource.minute,
      timeSource.second,
      timeSource.millisecond,
    );
  }

  /// Combina ano/mês/dia de [date] com [time] escolhido no relógio.
  static DateTime withTimeOfDay(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static String isoDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Soma [monthsToAdd] mantendo o dia âncora original ou o último dia válido do mês.
  static DateTime addMonthsClampingDay(DateTime anchor, int monthsToAdd) {
    final totalMonths = (anchor.year * 12) + (anchor.month - 1) + monthsToAdd;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = math.min(anchor.day, daysInTargetMonth);
    return DateTime(targetYear, targetMonth, clampedDay);
  }

  /// Soma [monthsToAdd] mantendo dia âncora (clamped) e preservando o horário de [anchor].
  static DateTime addMonthsPreservingTime(DateTime anchor, int monthsToAdd) {
    return preserveTime(addMonthsClampingDay(anchor, monthsToAdd), anchor);
  }
}
