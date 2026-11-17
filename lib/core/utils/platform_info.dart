import 'package:flutter/foundation.dart';

/// Informações seguras de plataforma sem dependência direta de `dart:io`,
/// garantindo compilação limpa em Web, Desktop e Mobile.
abstract final class PlatformInfo {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop => isWindows || isLinux || isMacOS;

  /// Firebase Core, Auth, Firestore e Storage possuem suporte nativo
  /// em Android, iOS, macOS, Web e Windows nesta stack FlutterFire.
  static bool get supportsCoreFirebase => !isLinux;

  /// Messaging, Analytics e App Check não possuem suporte nativo no Windows/Linux.
  static bool get supportsNativeFcm => isAndroid || isIOS || isMacOS || isWeb;

  static bool get supportsNativeAnalytics =>
      isAndroid || isIOS || isMacOS || isWeb;

  static bool get supportsNativeAppCheck =>
      isAndroid || isIOS || isMacOS || isWeb;

  static bool get supportsNativeCloudFunctions =>
      isAndroid || isIOS || isMacOS || isWeb;

  static bool get supportsNativeGoogleSignIn =>
      isAndroid || isIOS || isMacOS || isWeb;

  static String get platformLabel {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.windows => 'Windows Desktop',
      TargetPlatform.linux => 'Linux Desktop',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }
}
