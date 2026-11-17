import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FirebaseBootstrapService stays in awaitingConfiguration when placeholder',
      () async {
    final service = FirebaseBootstrapService();
    final state = await service.initialize();

    expect(state.status, FirebaseConnectionStatus.awaitingConfiguration);
    expect(state.isReady, isFalse);
  });
}
