import '../entities/app_notification_entity.dart';

/// Contrato de persistência da central de notificações e dispositivos FCM.
abstract interface class NotificationRepository {
  Stream<List<AppNotificationEntity>> watchNotifications(String userId);

  /// Grava apenas alertas que ainda não existem no Firestore (idempotente),
  /// preservando o status `isRead` dos alertas já visualizados. Retorna quantos foram criados.
  Future<int> syncSystemAlerts({
    required String userId,
    required List<AppNotificationEntity> candidates,
  });

  Future<AppNotificationEntity> createCustomReminder({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? referenceId,
  });

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
    required bool isRead,
  });

  Future<void> markAllAsRead(String userId);

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  });

  Future<void> registerDeviceToken({
    required String userId,
    required String token,
    required String platform,
  });
}
