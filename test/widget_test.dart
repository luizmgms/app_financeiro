import 'package:finance_control/app/app.dart';
import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/core/services/local_storage_service.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  Widget buildTestApp() {
    final storage = LocalStorageService();
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        appBootstrapStateProvider.overrideWithValue(
          const AppBootstrapState(
            firebase: FirebaseBootstrapState.awaitingConfiguration(),
            localStorageInitialized: false,
          ),
        ),
      ],
      child: const FinanceControlApp(),
    );
  }

  testWidgets('Desktop layout boots skeleton dashboard and navigates cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Finance Control'), findsWidgets);
    expect(find.text('Esqueleto Etapa 0'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Assistente IA'), findsWidgets);

    // Navega para a aba Contas pelo NavigationRail.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Contas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Etapa 2 • Contas e Transferências'), findsOneWidget);

    // Navega para Configurações e altera o tema.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Configurações'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aparência (Material Design 3)'), findsOneWidget);

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile layout renders NavigationBar without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Esqueleto Etapa 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
