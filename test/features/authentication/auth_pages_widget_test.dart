import 'dart:async';

import 'package:finance_control/app/app.dart';
import 'package:finance_control/core/services/firebase_bootstrap_service.dart';
import 'package:finance_control/core/services/local_storage_service.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _WidgetFakeAuthRepository implements AuthRepository {
  _WidgetFakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _user = AuthUser(
      uid: 'u1',
      email: email,
      displayName: 'Usuário Teste',
      providerIds: const ['password'],
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _user = AuthUser(
      uid: 'u1',
      email: email,
      displayName: name,
      providerIds: const ['password'],
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> reauthenticateWithPassword(String currentPassword) async {}

  @override
  Future<void> deleteCurrentAuthUser() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

class _WidgetFakeProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(_profile);

  @override
  Future<UserProfile> ensureProfile({required AuthUser user}) async {
    final now = DateTime(2026, 11, 16);
    _profile ??= UserProfile(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      createdAt: now,
      updatedAt: now,
    );
    return _profile!;
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> deleteUserData(String uid) async {
    _profile = null;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });

  testWidgets(
      'Redirects unauthenticated user to LoginPage when Firebase is connected and allows login',
      (tester) async {
    final authRepo = _WidgetFakeAuthRepository();
    final profileRepo = _WidgetFakeProfileRepository();
    addTearDown(authRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(LocalStorageService()),
          appBootstrapStateProvider.overrideWithValue(
            const AppBootstrapState(
              firebase: FirebaseBootstrapState(
                status: FirebaseConnectionStatus.connected,
                message: 'Firebase conectado.',
                projectId: 'finance-test',
              ),
              localStorageInitialized: true,
            ),
          ),
          authRepositoryProvider.overrideWithValue(authRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
        ],
        child: const FinanceControlApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrar na conta'), findsOneWidget);

    // Testa validação de formulário vazio.
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);

    // Preenche credenciais válidas e entra no Dashboard.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'luiz@financecontrol.app',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      '123456',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Usuário Teste'), findsOneWidget);
  });

  testWidgets('Authenticated user can open ProfilePage and edit profile',
      (tester) async {
    const initialUser = AuthUser(
      uid: 'u1',
      email: 'luiz@financecontrol.app',
      displayName: 'Luiz',
      providerIds: ['password'],
    );
    final authRepo = _WidgetFakeAuthRepository(initialUser: initialUser);
    final profileRepo = _WidgetFakeProfileRepository();
    addTearDown(authRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(LocalStorageService()),
          appBootstrapStateProvider.overrideWithValue(
            const AppBootstrapState(
              firebase: FirebaseBootstrapState(
                status: FirebaseConnectionStatus.connected,
                message: 'Firebase conectado.',
                projectId: 'finance-test',
              ),
              localStorageInitialized: true,
            ),
          ),
          authRepositoryProvider.overrideWithValue(authRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
        ],
        child: const FinanceControlApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil do Usuário'), findsOneWidget);
    expect(find.text('luiz@financecontrol.app'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo'),
      'Luiz Fernando',
    );
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(
      find.text('Perfil e preferências atualizados com sucesso.'),
      findsOneWidget,
    );
  });
}
