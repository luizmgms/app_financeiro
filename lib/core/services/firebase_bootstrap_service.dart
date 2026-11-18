import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  FirebaseBootstrapService({
    FirebaseOptions Function()? optionsResolver,
  }) : _optionsResolver = optionsResolver;

  static const bool _useEmulator =
      bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
  static const String _customEmulatorHost =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '');

  final FirebaseOptions Function()? _optionsResolver;

  Future<FirebaseBootstrapState> initialize() async {
    if (!PlatformInfo.supportsCoreFirebase) {
      return FirebaseBootstrapState(
        status: FirebaseConnectionStatus.unsupportedPlatform,
        message:
            '${PlatformInfo.platformLabel} não possui SDK nativo FlutterFire nesta versão.',
      );
    }

    try {
      final options =
          _optionsResolver?.call() ?? DefaultFirebaseOptions.currentPlatform;
      final isPlaceholder = options.apiKey.startsWith('REPLACE_WITH_');
      if (isPlaceholder && !_useEmulator) {
        return const FirebaseBootstrapState.awaitingConfiguration();
      }

      final app = await _initializeOrReuseApp(options);

      if (_useEmulator) {
        final host = _resolveEmulatorHost();
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      }

      await _configureFirestorePersistence();

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

  Future<FirebaseApp> _initializeOrReuseApp(FirebaseOptions options) async {
    try {
      return await Firebase.initializeApp(options: options);
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app') {
        return Firebase.app();
      }
      rethrow;
    }
  }

  Future<void> _configureFirestorePersistence() async {
    if (kIsWeb) {
      try {
        await FirebaseFirestore.instance.enablePersistence(
          const PersistenceSettings(synchronizeTabs: true),
        );
      } catch (_) {
        // Navegadores em aba anônima ou múltiplas abas incompatíveis seguem
        // normalmente com cache em memória sem interromper o Firebase.
      }
      return;
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  String _resolveEmulatorHost() {
    if (_customEmulatorHost.isNotEmpty) {
      return _customEmulatorHost;
    }
    return PlatformInfo.isAndroid ? '10.0.2.2' : '127.0.0.1';
  }
}
