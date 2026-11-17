import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap_service.dart';
import 'core/services/local_storage_service.dart';
import 'shared/providers/app_bootstrap_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('pt_BR');
  await initializeDateFormatting('en_US');

  final localStorageService = LocalStorageService();
  await localStorageService.initialize();

  final firebaseBootstrapService = FirebaseBootstrapService();
  final firebaseState = await firebaseBootstrapService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorageService),
        firebaseBootstrapServiceProvider
            .overrideWithValue(firebaseBootstrapService),
        appBootstrapStateProvider.overrideWithValue(
          AppBootstrapState(
            firebase: firebaseState,
            localStorageInitialized: localStorageService.isInitialized,
          ),
        ),
      ],
      child: const FinanceControlApp(),
    ),
  );
}
