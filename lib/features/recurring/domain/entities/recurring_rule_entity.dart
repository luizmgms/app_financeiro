import 'package:equatable/equatable.dart';

/// Tipo financeiro de uma regra recorrente.
enum RecurringKind {
  income('income', 'Receita'),
  expense('expense', 'Despesa');

  const RecurringKind(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static RecurringKind fromStorage(String? value) {
    return RecurringKind.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => RecurringKind.expense,
    );
  }
}

/// Frequências suportadas pelo motor de recorrências.
enum RecurringFrequency {
  daily('daily', 'Diária'),
  weekly('weekly', 'Semanal'),
  biweekly('biweekly', 'Quinzenal'),
  monthly('monthly', 'Mensal'),
  bimonthly('bimonthly', 'Bimestral'),
  quarterly('quarterly', 'Trimestral'),
  semiannual('semiannual', 'Semestral'),
  annual('annual', 'Anual'),
  custom('custom', 'Personalizada');

  const RecurringFrequency(this.storageValue, this.label);

  final String storageValue;
  final String label;

  /// Equivalência aproximada mensal para estimativas de compromisso fixo.
  double monthlyMultiplier([int? customDays]) {
    return switch (this) {
      RecurringFrequency.daily => 30.0,
      RecurringFrequency.weekly => 4.333,
      RecurringFrequency.biweekly => 2.167,
      RecurringFrequency.monthly => 1.0,
      RecurringFrequency.bimonthly => 0.5,
      RecurringFrequency.quarterly => 1 / 3,
      RecurringFrequency.semiannual => 1 / 6,
      RecurringFrequency.annual => 1 / 12,
      RecurringFrequency.custom =>
        (customDays != null && customDays > 0) ? (30.0 / customDays) : 1.0,
    };
  }

  static RecurringFrequency fromStorage(String? value) {
    return RecurringFrequency.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}

/// Ciclo de vida de uma recorrência.
enum RecurringStatus {
  active('active', 'Ativa'),
  paused('paused', 'Pausada'),
  canceled('canceled', 'Cancelada');

  const RecurringStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static RecurringStatus fromStorage(String? value) {
    return RecurringStatus.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => RecurringStatus.active,
    );
  }
}

/// Regra de receita ou despesa recorrente armazenada em `users/{uid}/recurring/{id}`.
class RecurringRuleEntity extends Equatable {
  const RecurringRuleEntity({
    required this.id,
    required this.description,
    required this.kind,
    required this.amountCents,
    this.isVariableAmount = false,
    required this.categoryId,
    this.accountId,
    this.cardId,
    required this.frequency,
    this.customIntervalDays,
    required this.startDate,
    this.endDate,
    this.status = RecurringStatus.active,
    this.lastGeneratedKey,
    this.skippedOccurrenceKeys = const <String>[],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String description;
  final RecurringKind kind;
  final int amountCents;
  final bool isVariableAmount;
  final String categoryId;
  final String? accountId;
  final String? cardId;
  final RecurringFrequency frequency;
  final int? customIntervalDays;
  final DateTime startDate;
  final DateTime? endDate;
  final RecurringStatus status;
  final String? lastGeneratedKey;
  final List<String> skippedOccurrenceKeys;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCardTarget =>
      kind == RecurringKind.expense && cardId != null && cardId!.isNotEmpty;

  String get frequencySummary {
    if (frequency == RecurringFrequency.custom &&
        customIntervalDays != null &&
        customIntervalDays! > 0) {
      return 'A cada $customIntervalDays dia(s)';
    }
    return frequency.label;
  }

  RecurringRuleEntity copyWith({
    String? id,
    String? description,
    RecurringKind? kind,
    int? amountCents,
    bool? isVariableAmount,
    String? categoryId,
    String? accountId,
    bool clearAccountId = false,
    String? cardId,
    bool clearCardId = false,
    RecurringFrequency? frequency,
    int? customIntervalDays,
    bool clearCustomIntervalDays = false,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    RecurringStatus? status,
    String? lastGeneratedKey,
    List<String>? skippedOccurrenceKeys,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringRuleEntity(
      id: id ?? this.id,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      isVariableAmount: isVariableAmount ?? this.isVariableAmount,
      categoryId: categoryId ?? this.categoryId,
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      cardId: clearCardId ? null : (cardId ?? this.cardId),
      frequency: frequency ?? this.frequency,
      customIntervalDays: clearCustomIntervalDays
          ? null
          : (customIntervalDays ?? this.customIntervalDays),
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: status ?? this.status,
      lastGeneratedKey: lastGeneratedKey ?? this.lastGeneratedKey,
      skippedOccurrenceKeys:
          skippedOccurrenceKeys ?? this.skippedOccurrenceKeys,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        kind,
        amountCents,
        isVariableAmount,
        categoryId,
        accountId,
        cardId,
        frequency,
        customIntervalDays,
        startDate,
        endDate,
        status,
        lastGeneratedKey,
        skippedOccurrenceKeys,
        notes,
        createdAt,
        updatedAt,
      ];
}
