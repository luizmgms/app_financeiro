import 'package:equatable/equatable.dart';

/// Meta mensal de limite de gastos por categoria armazenada em `users/{uid}/budgets/{id}`.
class BudgetEntity extends Equatable {
  const BudgetEntity({
    required this.id,
    required this.categoryId,
    required this.year,
    required this.month,
    required this.limitCents,
    this.alertThresholdPercent = 80,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final int year;
  final int month;
  final int limitCents;
  final int alertThresholdPercent;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String deterministicId({
    required String categoryId,
    required int year,
    required int month,
  }) {
    final mm = month.toString().padLeft(2, '0');
    return '${categoryId}_${year}_$mm';
  }

  String get monthLabel => '${month.toString().padLeft(2, '0')}/$year';

  BudgetEntity copyWith({
    String? id,
    String? categoryId,
    int? year,
    int? month,
    int? limitCents,
    int? alertThresholdPercent,
    String? notes,
    bool clearNotes = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetEntity(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      year: year ?? this.year,
      month: month ?? this.month,
      limitCents: limitCents ?? this.limitCents,
      alertThresholdPercent:
          alertThresholdPercent ?? this.alertThresholdPercent,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        year,
        month,
        limitCents,
        alertThresholdPercent,
        notes,
        createdAt,
        updatedAt,
      ];
}
