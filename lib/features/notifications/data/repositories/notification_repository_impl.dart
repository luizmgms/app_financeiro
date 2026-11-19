import 'package:firebase_core/firebase_core.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required NotificationRemoteDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final NotificationRemoteDatasource _datasource;

  void _ensureReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure();
    }
  }

  @override
  Stream<List<AppNotificationEntity>> watchNotifications(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <AppNotificationEntity>[]);
    }
    return _datasource.watchNotifications(userId);
  }

  @override
  Future<int> syncSystemAlerts({
    required String userId,
    required List<AppNotificationEntity> candidates,
  }) async {
    _ensureReady();
    try {
      return await _datasource.syncSystemAlerts(
        userId: userId,
        candidates: candidates,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível sincronizar notificações.',
      );
    }
  }

  @override
  Future<AppNotificationEntity> createCustomReminder({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? referenceId,
  }) async {
    _ensureReady();
    try {
      return await _datasource.createCustomReminder(
        userId: userId,
        title: title,
        body: body,
        scheduledFor: scheduledFor,
        referenceId: referenceId,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível salvar o lembrete personalizado.',
      );
    }
  }

  @override
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
    required bool isRead,
  }) async {
    _ensureReady();
    try {
      await _datasource.markAsRead(
        userId: userId,
        notificationId: notificationId,
        isRead: isRead,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível atualizar a notificação.',
      );
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    _ensureReady();
    try {
      await _datasource.markAllAsRead(userId);
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível marcar notificações como lidas.',
      );
    }
  }

  @override
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    _ensureReady();
    try {
      await _datasource.deleteNotification(
        userId: userId,
        notificationId: notificationId,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível excluir a notificação.',
      );
    }
  }

  @override
  Future<void> registerDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    _ensureReady();
    try {
      await _datasource.registerDeviceToken(
        userId: userId,
        token: token,
        platform: platform,
      );
    } on FirebaseException catch (error) {
      throw mapFirebaseFailure(
        error,
        fallbackMessage: 'Não foi possível registrar dispositivo FCM.',
      );
    }
  }
}
