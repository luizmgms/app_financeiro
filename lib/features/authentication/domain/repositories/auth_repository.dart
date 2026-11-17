import '../entities/auth_user.dart';

/// Contrato de autenticação e gestão de sessão.
abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> updateDisplayName(String displayName);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> reauthenticateWithPassword(String currentPassword);

  Future<void> deleteCurrentAuthUser();

  Future<void> signOut();
}
