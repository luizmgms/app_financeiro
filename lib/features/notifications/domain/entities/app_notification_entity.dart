import 'package:equatable/equatable.dart';

/// Tipos de notificações e alertas financeiros (Seção 13 do plano).
enum NotificationType {
  upcomingPayable('upcoming_payable', 'Conta a vencer'),
  overduePayable('overdue_payable', 'Conta vencida'),
  invoiceDue('invoice_due', 'Fatura de cartão'),
  budgetWarning('budget_warning', 'Orçamento no limite'),
  budgetExceeded('budget_exceeded', 'Orçamento ultrapassado'),
  expectedIncome('expected_income', 'Receita prevista'),
  customReminder('custom_reminder', 'Lembrete personalizado');

  const NotificationType(this.storageValue, this.label);

  final String storageValue;
  final String label;

  bool get isUrgent =>
      this == NotificationType.overduePayable ||
      this == NotificationType.budgetExceeded;

  static NotificationType fromStorage(String? value) {
    return NotificationType.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => NotificationType.customReminder,
    );
  }
}

/// Notificação financeira ou lembrete armazenado em `users/{uid}/notifications/{id}`.
class AppNotificationEntity extends Equatable {
  const AppNotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    required this.scheduledFor,
    this.isRead = false,
    this.isCustom = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? referenceId;
  final DateTime scheduledFor;
  final bool isRead;
  final bool isCustom;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppNotificationEntity copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    String? referenceId,
    DateTime? scheduledFor,
    bool? isRead,
    bool? isCustom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      isRead: isRead ?? this.isRead,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        type,
        referenceId,
        scheduledFor,
        isRead,
        isCustom,
        createdAt,
        updatedAt,
      ];
}
