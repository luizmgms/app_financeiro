import 'package:intl/intl.dart';

/// Formatadores de data padronizados com suporte a `pt_BR`.
abstract final class DateFormatter {
  static String shortDate(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('dd/MM/yyyy', locale).format(date);
  }

  static String dayMonth(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('dd MMM', locale).format(date);
  }

  static String monthYear(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('MMMM yyyy', locale).format(date);
  }
}
