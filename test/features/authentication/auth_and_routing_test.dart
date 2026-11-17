import 'dart:async';

import 'package:finance_control/core/errors/failures.dart';
import 'package:finance_control/core/routes/app_router.dart';
import 'package:finance_control/core/routes/app_routes.dart';
import 'package:finance_control/core/services/local_storage_service.dart';
import 'package:finance_control/features/authentication/application/controllers/auth_controller.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/profile/application/controllers/profile_controller.dart';
import 'package:finance_control/features/profile/application/providers/profile_providers.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/profile/domain/repositories/profile_repository.dart';
import 'package:finance_control/shared/providers/app_bootstrap_provider.dart';
import 'package:finance_control/shared/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  final List<String> callLog = [];
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  bool shouldFailLogin = false;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    callLog.add('signInWithEmail');
    if (shouldFailLogin) {
      throw const AuthFailure('E-mail ou senha incorretos.');
    }
    _user = AuthUser(
      uid: 'uid-1',
      email: email,
      displayName: 'Maria Silva',
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
    callLog.add('registerWithEmail');
    _user = AuthUser(
      uid: 'uid-2',
      email: email,
      displayName: name,
      providerIds: const ['password'],
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    callLog.add('signInWithGoogle');
    _user = const AuthUser(
      uid: 'uid-google',
      email: 'google@teste.com',
      displayName: 'Conta Google',
      providerIds: ['google.com'],
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    callLog.add('sendPasswordResetEmail');
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    callLog.add('updateDisplayName');
    if (_user != null) {
      _user = AuthUser(
        uid: _user!.uid,
        email: _user!.email,
        displayName: displayName,
        providerIds: _user!.providerIds,
      );
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    callLog.add('changePassword');
  }

  @override
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    callLog.add('reauthenticateWithPassword');
  }

  @override
  Future<void> deleteCurrentAuthUser() async {
    callLog.add('deleteCurrentAuthUser');
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> signOut() async {
    callLog.add('signOut');
    _user = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.sharedLog);

  final List<String> sharedLog;
  UserProfile? savedProfile;

  @override
  Stream<UserProfile?> watchProfile(String uid) => Stream.value(savedProfile);

  @override
  Future<UserProfile> ensureProfile({required AuthUser user}) async {
    sharedLog.add('ensureProfile');
    final now = DateTime(2026, 11, 16);
    savedProfile ??= UserProfile(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      createdAt: now,
      updatedAt: now,
    );
    return savedProfile!;
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    sharedLog.add('updateProfile');
    savedProfile = profile;
  }

  @override
  Future<void> deleteUserData(String uid) async {
    sharedLog.add('deleteUserData');
    savedProfile = null;
  }
}

void main() {
  group('resolveAuthRedirect', () {
    test('does not redirect when Firebase is not configured yet', () {
      expect(
        resolveAuthRedirect(
          firebaseReady: false,
          isAuthenticated: false,
          isAuthLoading: false,
          currentLocation: AppRoutes.dashboard,
        ),
        isNull,
      );
    });

    test('redirects unauthenticated users to /login when Firebase is ready', () {
      expect(
        resolveAuthRedirect(
          firebaseReady: true,
          isAuthenticated: false,
          isAuthLoading: false,
          currentLocation: AppRoutes.dashboard,
        ),
        AppRoutes.login,
      );

      expect(
        resolveAuthRedirect(
          firebaseReady: true,
          isAuthenticated: false,
          isAuthLoading: false,
          currentLocation: AppRoutes.register,
        ),
        isNull,
      );
    });

    test('redirects authenticated users away from public auth routes', () {
      expect(
        resolveAuthRedirect(
          firebaseReady: true,
          isAuthenticated: true,
          isAuthLoading: false,
          currentLocation: AppRoutes.login,
        ),
        AppRoutes.dashboard,
      );
    });
  });

  group('AuthController & ProfileController', () {
    late _FakeAuthRepository authRepo;
    late _FakeProfileRepository profileRepo;
    late ProviderContainer container;

    setUp(() {
      authRepo = _FakeAuthRepository();
      profileRepo = _FakeProfileRepository(authRepo.callLog);
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(LocalStorageService()),
          authRepositoryProvider.overrideWithValue(authRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      authRepo.dispose();
    });

    test('registerWithEmail creates auth user and ensures Firestore profile',
        () async {
      final ok = await container
          .read(authControllerProvider.notifier)
          .registerWithEmail(
            name: 'Carlos Souza',
            email: 'carlos@teste.com',
            password: 'password123',
          );

      expect(ok, isTrue);
      expect(authRepo.callLog, ['registerWithEmail', 'ensureProfile']);
      expect(profileRepo.savedProfile?.displayName, 'Carlos Souza');
    });

    test('signInWithEmail surfaces AuthFailure message cleanly', () async {
      authRepo.shouldFailLogin = true;
      final ok = await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(
            email: 'err@teste.com',
            password: 'wrong',
          );

      expect(ok, isFalse);
      expect(
        container.read(authControllerProvider).errorMessage,
        'E-mail ou senha incorretos.',
      );
    });

    test('updateProfile saves preferences and updates localeProvider',
        () async {
      await container.read(authControllerProvider.notifier).signInWithEmail(
            email: 'maria@teste.com',
            password: 'password123',
          );

      final initialProfile = profileRepo.savedProfile!;
      final updatedOk = await container
          .read(profileControllerProvider.notifier)
          .updateProfile(
            currentProfile: initialProfile,
            displayName: 'Maria Atualizada',
            defaultCurrency: 'USD',
            localeCode: 'en_US',
            monthStartDay: 15,
          );

      expect(updatedOk, isTrue);
      expect(profileRepo.savedProfile?.defaultCurrency, 'USD');
      expect(profileRepo.savedProfile?.monthStartDay, 15);
      expect(container.read(localeProvider), const Locale('en', 'US'));
    });

    test('deleteAccount removes Firestore data BEFORE deleting Auth user',
        () async {
      await container.read(authControllerProvider.notifier).signInWithEmail(
            email: 'maria@teste.com',
            password: 'password123',
          );
      authRepo.callLog.clear();

      final deleted = await container
          .read(profileControllerProvider.notifier)
          .deleteAccount(currentPassword: 'password123');

      expect(deleted, isTrue);
      expect(authRepo.callLog, [
        'reauthenticateWithPassword',
        'deleteUserData',
        'deleteCurrentAuthUser',
      ]);
      expect(profileRepo.savedProfile, isNull);
    });
  });
}
