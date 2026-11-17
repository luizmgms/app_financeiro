import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../firebase_options.dart';
import '../utils/platform_info.dart';

enum FirebaseConnectionStatus {
  awaitingConfiguration,
  connected,
  unsupportedPlatform,
  error,
}

/// Estado atual da inicialização do Firebase no dispositivo.
class FirebaseBootstrapState extends Equatable {
  const FirebaseBootstrapState({
    required this.status,
    required this.message,
    this.projectId,
    this.usingEmulator = false,
    this.errorDetails,
  });

  const FirebaseBootstrapState.awaitingConfiguration()
      : status = FirebaseConnectionStatus.awaitingConfiguration,
        message =
            'Modo Esqueleto: execute "flutterfire configure" para conectar ao Firebase.',
        projectId = null,
        usingEmulator = false,
        errorDetails = null;

  final FirebaseConnectionStatus status;
  final String message;
  final String? projectId;
  final bool usingEmulator;
  final String? errorDetails;

  bool get isReady => status == FirebaseConnectionStatus.connected;

  @override
  List<Object?> get props =>
      [status, message, projectId, usingEmulator, errorDetails];
}

/// Inicializa o Firebase com segurança por plataforma, cache offline no Firestore
/// e suporte opcional ao Firebase Emulator Suite via `--dart-define`.
class FirebaseBootstrapService {
  static const bool _useEmulator =
      bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
  static const String _customEmulatorHost =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '');

  Future<FirebaseBootstrapState> initialize() async {
    if (!PlatformInfo.supportsCoreFirebase) {
      return FirebaseBootstrapState(
        status: FirebaseConnectionStatus.unsupportedPlatform,
        message:
            '${PlatformInfo.platformLabel} não possui SDK nativo FlutterFire nesta versão.',
      );
    }

    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      final isPlaceholder = options.apiKey.startsWith('REPLACE_WITH_');
      if (isPlaceholder && !_useEmulator) {
        return const FirebaseBootstrapState.awaitingConfiguration();
      }

      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: options)
          : Firebase.app();

      if (_useEmulator) {
        final host = _resolveEmulatorHost();
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      }

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );

      return FirebaseBootstrapState(
        status: FirebaseConnectionStatus.connected,
        message: _useEmulator
            ? 'Firebase Emulator ativo (${PlatformInfo.platformLabel}).'
            : 'Firebase conectado (${PlatformInfo.platformLabel}).',
        projectId: app.options.projectId,
        usingEmulator: _useEmulator,
      );
    } catch (error) {
      return FirebaseBootstrapState(
        status: FirebaseConnectionStatus.error,
        message: 'Falha ao inicializar Firebase. Executando em modo local.',
        errorDetails: error.toString(),
      );
    }
  }

  String _resolveEmulatorHost() {
    if (_customEmulatorHost.isNotEmpty) {
      return _customEmulatorHost;
    }
    return PlatformInfo.isAndroid ? '10.0.2.2' : '127.0.0.1';
  }
}
