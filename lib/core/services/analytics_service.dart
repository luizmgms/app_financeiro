import 'package:firebase_analytics/firebase_analytics.dart';
import '../utils/platform_info.dart';
import 'firebase_bootstrap_service.dart';

/// Encapsula eventos do Firebase Analytics com guarda por plataforma.
class AnalyticsService {
  AnalyticsService(this._bootstrapState);

  final FirebaseBootstrapState _bootstrapState;

  bool get isAvailable =>
      _bootstrapState.isReady && PlatformInfo.supportsNativeAnalytics;

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    if (!isAvailable) return;
    await FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}
