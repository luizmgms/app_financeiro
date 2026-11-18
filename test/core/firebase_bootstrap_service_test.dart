import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FirebaseBootstrapService stays in awaitingConfiguration when placeholder',
      () async {
    final service = FirebaseBootstrapService(
      optionsResolver: () => const FirebaseOptions(
        apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
        appId: '1:000000000000:android:placeholder',
        messagingSenderId: '000000000000',
        projectId: 'finance-control-placeholder',
      ),
    );
    final state = await service.initialize();

    expect(state.status, FirebaseConnectionStatus.awaitingConfiguration);
    expect(state.isReady, isFalse);
  });

  test('DefaultFirebaseOptions has real project configuration', () {
    final options = DefaultFirebaseOptions.currentPlatform;

    expect(options.projectId, 'finance-control-luizmgms');
    expect(options.apiKey.startsWith('REPLACE_WITH_'), isFalse);
    expect(options.apiKey, isNotEmpty);
    expect(options.appId, isNotEmpty);
    expect(options.storageBucket, 'finance-control-luizmgms.firebasestorage.app');
  });
}
