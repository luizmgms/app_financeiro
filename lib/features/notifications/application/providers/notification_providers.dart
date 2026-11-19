import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  return NotificationService(bootstrap.firebase);
});

final notificationRemoteDatasourceProvider =
    Provider<NotificationRemoteDatasource>((ref) {
  return NotificationRemoteDatasource();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(notificationRemoteDatasourceProvider);
  return NotificationRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
  );
});

final notificationsStreamProvider =
    StreamProvider<List<AppNotificationEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <AppNotificationEntity>[]);
  }
  return ref.watch(notificationRepositoryProvider).watchNotifications(authUser.uid);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final all = ref.watch(notificationsStreamProvider).valueOrNull ?? const [];
  return all.where((item) => !item.isRead).length;
});
