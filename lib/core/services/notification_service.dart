import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/platform_info.dart';
import 'firebase_bootstrap_service.dart';

/// Encapsula Firebase Cloud Messaging com guarda por plataforma
/// (Windows e Linux não possuem suporte nativo a FCM no FlutterFire).
class NotificationService {
  NotificationService(this._bootstrapState);

  final FirebaseBootstrapState _bootstrapState;

  bool get supportsPushNotifications =>
      _bootstrapState.isReady && PlatformInfo.supportsNativeFcm;

  Future<String?> requestPermissionAndToken() async {
    if (!supportsPushNotifications) return null;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    return messaging.getToken();
  }
}
