import 'package:equatable/equatable.dart';

/// Status de um plano de parcelamento.
enum InstallmentPlanStatus {
  active('active', 'Ativo'),
  completed('completed', 'Concluído'),
  canceled('canceled', 'Cancelado');

  const InstallmentPlanStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static InstallmentPlanStatus fromStorage(String? value) {
    return switch (value) {
      'completed' => InstallmentPlanStatus.completed,
      'canceled' => InstallmentPlanStatus.canceled,
      _ => InstallmentPlanStatus.active,
    };
  }
}

/// Plano de compra parcelada (`users/{userId}/installments/{installmentId}`).
class InstallmentPlanEntity extends Equatable {
  const InstallmentPlanEntity({
    required this.id,
    required this.description,
    required this.totalAmountCents,
    required this.installmentCount,
    required this.firstCompetencyDate,
    required this.firstDueDate,
    this.cardId,
    this.accountId,
    required this.categoryId,
    this.notes,
    this.status = InstallmentPlanStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String description;
  final int totalAmountCents;
  final int installmentCount;
  final DateTime firstCompetencyDate;
  final DateTime firstDueDate;
  final String? cardId;
  final String? accountId;
  final String categoryId;
  final String? notes;
  final InstallmentPlanStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCardInstallment => cardId != null && cardId!.isNotEmpty;

  InstallmentPlanEntity copyWith({
    String? id,
    String? description,
    int? totalAmountCents,
    int? installmentCount,
    DateTime? firstCompetencyDate,
    DateTime? firstDueDate,
    String? cardId,
    String? accountId,
    String? categoryId,
    String? notes,
    InstallmentPlanStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InstallmentPlanEntity(
      id: id ?? this.id,
      description: description ?? this.description,
      totalAmountCents: totalAmountCents ?? this.totalAmountCents,
      installmentCount: installmentCount ?? this.installmentCount,
      firstCompetencyDate: firstCompetencyDate ?? this.firstCompetencyDate,
      firstDueDate: firstDueDate ?? this.firstDueDate,
      cardId: cardId ?? this.cardId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        description,
        totalAmountCents,
        installmentCount,
        firstCompetencyDate,
        firstDueDate,
        cardId,
        accountId,
        categoryId,
        notes,
        status,
        createdAt,
        updatedAt,
      ];
}
