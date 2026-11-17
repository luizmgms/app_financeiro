import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_bootstrap_service.dart';
import '../../core/services/local_storage_service.dart';

/// Resultado imutável da inicialização do aplicativo.
class AppBootstrapState {
  const AppBootstrapState({
    required this.firebase,
    required this.localStorageInitialized,
  });

  final FirebaseBootstrapState firebase;
  final bool localStorageInitialized;
}

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final firebaseBootstrapServiceProvider =
    Provider<FirebaseBootstrapService>((ref) {
  return FirebaseBootstrapService();
});

final appBootstrapStateProvider = Provider<AppBootstrapState>((ref) {
  return const AppBootstrapState(
    firebase: FirebaseBootstrapState.awaitingConfiguration(),
    localStorageInitialized: false,
  );
});
