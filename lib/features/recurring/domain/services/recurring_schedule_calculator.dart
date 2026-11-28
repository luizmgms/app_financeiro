import 'package:equatable/equatable.dart';
import '../../../../core/utils/date_formatter.dart';
import '../entities/recurring_rule_entity.dart';

/// Especificação determinística de uma ocorrência gerada por uma regra recorrente.
class RecurringOccurrenceSpec extends Equatable {
  const RecurringOccurrenceSpec({
    required this.recurringId,
    required this.occurrenceKey,
    required this.transactionDocId,
    required this.scheduledDate,
    required this.dateKey,
  });

  final String recurringId;
  final String occurrenceKey;
  final String transactionDocId;
  final DateTime scheduledDate;
  final String dateKey;

  @override
  List<Object?> get props => [
        recurringId,
        occurrenceKey,
        transactionDocId,
        scheduledDate,
        dateKey,
      ];
}

/// Serviço puro para cálculo de calendário, chaves idempotentes e janela futura
/// das regras de recorrência sem dependência de Firebase.
abstract final class RecurringScheduleCalculator {
  static String dateKeyFor(DateTime date) => DateFormatter.isoDateKey(date);

  static String occurrenceKeyFor(String recurringId, DateTime date) =>
      '${recurringId}_${dateKeyFor(date)}';

  /// ID determinístico no Firestore para garantir idempotência entre cliente e backend.
  static String transactionDocIdFor(String recurringId, DateTime date) =>
      'rec_${recurringId}_${dateKeyFor(date)}';

  /// Calcula a [occurrenceIndex]-ésima data da série a partir de [anchorStartDate],
  /// preservando sempre o dia âncora (ex.: 31/01 -> 28/02 -> 31/03).
  static DateTime dateAtOccurrenceIndex({
    required DateTime anchorStartDate,
    required int occurrenceIndex,
    required RecurringFrequency frequency,
    int? customIntervalDays,
  }) {
    final anchor = DateFormatter.dateOnly(anchorStartDate);
    if (occurrenceIndex <= 0) return anchor;

    return switch (frequency) {
      RecurringFrequency.daily => anchor.add(Duration(days: occurrenceIndex)),
      RecurringFrequency.weekly =>
        anchor.add(Duration(days: occurrenceIndex * 7)),
      RecurringFrequency.biweekly =>
        anchor.add(Duration(days: occurrenceIndex * 14)),
      RecurringFrequency.monthly =>
        DateFormatter.addMonthsClampingDay(anchor, occurrenceIndex),
      RecurringFrequency.bimonthly =>
        DateFormatter.addMonthsClampingDay(anchor, occurrenceIndex * 2),
      RecurringFrequency.quarterly =>
        DateFormatter.addMonthsClampingDay(anchor, occurrenceIndex * 3),
      RecurringFrequency.semiannual =>
        DateFormatter.addMonthsClampingDay(anchor, occurrenceIndex * 6),
      RecurringFrequency.annual =>
        DateFormatter.addMonthsClampingDay(anchor, occurrenceIndex * 12),
      RecurringFrequency.custom => anchor.add(
          Duration(
            days: occurrenceIndex *
                ((customIntervalDays != null && customIntervalDays > 0)
                    ? customIntervalDays
                    : 1),
          ),
        ),
    };
  }

  /// Define o horizonte padrão de pré-geração conforme a cadência da recorrência.
  static DateTime defaultHorizonEnd(
    DateTime referenceDate,
    RecurringFrequency frequency, {
    int? customIntervalDays,
  }) {
    final ref = DateFormatter.dateOnly(referenceDate);
    final daysAhead = switch (frequency) {
      RecurringFrequency.daily => 14,
      RecurringFrequency.weekly || RecurringFrequency.biweekly => 45,
      RecurringFrequency.custom
          when customIntervalDays != null && customIntervalDays < 7 =>
        21,
      _ => 90,
    };
    return ref.add(Duration(days: daysAhead));
  }

  /// Retorna a lista ordenada de ocorrências ativas elegíveis para existir até o horizonte,
  /// omitindo chaves em `rule.skippedOccurrenceKeys` e respeitando `rule.endDate`.
  static List<RecurringOccurrenceSpec> computeOccurrencesInWindow({
    required RecurringRuleEntity rule,
    required DateTime referenceDate,
    DateTime? windowStartOverride,
    DateTime? horizonEndOverride,
    int maxOccurrences = 30,
  }) {
    if (rule.status != RecurringStatus.active || rule.id.isEmpty) {
      return const <RecurringOccurrenceSpec>[];
    }

    final anchor = DateFormatter.dateOnly(rule.startDate);
    final refDay = DateFormatter.dateOnly(referenceDate);
    final defaultLookbackStart = refDay.subtract(const Duration(days: 60));
    final lowerBound = windowStartOverride != null
        ? DateFormatter.dateOnly(windowStartOverride)
        : (anchor.isAfter(defaultLookbackStart) ? anchor : defaultLookbackStart);

    var upperBound = horizonEndOverride != null
        ? DateFormatter.dateOnly(horizonEndOverride)
        : defaultHorizonEnd(
            refDay,
            rule.frequency,
            customIntervalDays: rule.customIntervalDays,
          );

    if (rule.endDate != null) {
      final endDay = DateFormatter.dateOnly(rule.endDate!);
      if (endDay.isBefore(anchor)) {
        return const <RecurringOccurrenceSpec>[];
      }
      if (endDay.isBefore(upperBound)) {
        upperBound = endDay;
      }
    }

    if (upperBound.isBefore(anchor)) {
      return const <RecurringOccurrenceSpec>[];
    }

    final skipped = rule.skippedOccurrenceKeys.toSet();
    final specs = <RecurringOccurrenceSpec>[];

    // Limite seguro de iterações mesmo para regras antigas diárias.
    const maxSteps = 5000;
    for (var idx = 0; idx < maxSteps; idx++) {
      final candidate = dateAtOccurrenceIndex(
        anchorStartDate: anchor,
        occurrenceIndex: idx,
        frequency: rule.frequency,
        customIntervalDays: rule.customIntervalDays,
      );

      if (candidate.isAfter(upperBound)) break;
      if (candidate.isBefore(lowerBound)) continue;

      final dKey = dateKeyFor(candidate);
      final occKey = '${rule.id}_$dKey';
      if (skipped.contains(occKey)) continue;

      specs.add(
        RecurringOccurrenceSpec(
          recurringId: rule.id,
          occurrenceKey: occKey,
          transactionDocId: 'rec_$occKey',
          scheduledDate: DateFormatter.preserveTime(candidate, rule.startDate),
          dateKey: dKey,
        ),
      );

      if (specs.length >= maxOccurrences) break;
    }

    return specs;
  }

  /// Calcula a próxima data programada em ou após [referenceDate], ou `null` se encerrada.
  static DateTime? nextScheduledDateFrom(
    RecurringRuleEntity rule,
    DateTime referenceDate,
  ) {
    if (rule.status != RecurringStatus.active) return null;
    final anchor = DateFormatter.dateOnly(rule.startDate);
    final refDay = DateFormatter.dateOnly(referenceDate);
    final endDay =
        rule.endDate != null ? DateFormatter.dateOnly(rule.endDate!) : null;
    final skipped = rule.skippedOccurrenceKeys.toSet();

    for (var idx = 0; idx < 2000; idx++) {
      final candidate = dateAtOccurrenceIndex(
        anchorStartDate: anchor,
        occurrenceIndex: idx,
        frequency: rule.frequency,
        customIntervalDays: rule.customIntervalDays,
      );
      if (endDay != null && candidate.isAfter(endDay)) return null;
      if (candidate.isBefore(refDay)) continue;
      if (skipped.contains(occurrenceKeyFor(rule.id, candidate))) continue;
      return candidate;
    }
    return null;
  }
}
