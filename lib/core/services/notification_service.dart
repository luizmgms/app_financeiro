import 'dart:async';
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

  String get platformKey => PlatformInfo.platformLabel;

  Future<({String? token, String? statusMessage})>
      requestPermissionAndToken() async {
    if (!_bootstrapState.isReady) {
      return (
        token: null,
        statusMessage: 'Firebase ainda não está conectado nesta sessão.',
      );
    }
    if (!PlatformInfo.supportsNativeFcm) {
      return (
        token: null,
        statusMessage:
            'Push nativo não está disponível em ${PlatformInfo.platformLabel}. Alertas internos continuam ativos.',
      );
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final authorized = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        return (
          token: null,
          statusMessage: 'Permissão de notificações recusada no navegador/sistema.',
        );
      }

      // Em Web sem service worker/VAPID configurado, getToken pode lançar erro controlado.
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return (
          token: null,
          statusMessage:
              'Permissão concedida, porém nenhum token FCM foi retornado neste dispositivo.',
        );
      }
      return (token: token, statusMessage: null);
    } catch (error) {
      return (
        token: null,
        statusMessage:
            'Push FCM indisponível neste navegador/ambiente ($error). Alertas no app seguem operando normalmente.',
      );
    }
  }

  Stream<String> watchTokenRefresh() {
    if (!supportsPushNotifications) {
      return const Stream<String>.empty();
    }
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream<String>.empty();
    }
  }

  Stream<RemoteMessage> watchForegroundMessages() {
    if (!supportsPushNotifications) {
      return const Stream<RemoteMessage>.empty();
    }
    try {
      return FirebaseMessaging.onMessage;
    } catch (_) {
      return const Stream<RemoteMessage>.empty();
    }
  }
}
