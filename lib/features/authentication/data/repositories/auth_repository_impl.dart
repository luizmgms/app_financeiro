import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_datasource.dart';

/// Implementação real de autenticação com guarda segura caso o Firebase ainda
/// não tenha sido conectado via `flutterfire configure`.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required FirebaseAuthDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final FirebaseAuthDatasource _datasource;

  void _ensureFirebaseReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure(
        'Firebase ainda não conectado. Execute "flutterfire configure" para autenticar.',
      );
    }
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    if (!_bootstrapState.isReady) {
      return Stream<AuthUser?>.value(null);
    }
    return _datasource.authStateChanges();
  }

  @override
  AuthUser? get currentUser {
    if (!_bootstrapState.isReady) return null;
    return _datasource.currentUser;
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) {
    _ensureFirebaseReady();
    return _datasource.signInWithEmail(email: email, password: password);
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) {
    _ensureFirebaseReady();
    return _datasource.registerWithEmail(
      name: name,
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    _ensureFirebaseReady();
    return _datasource.signInWithGoogle();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    _ensureFirebaseReady();
    return _datasource.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> updateDisplayName(String displayName) {
    _ensureFirebaseReady();
    return _datasource.updateDisplayName(displayName);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    _ensureFirebaseReady();
    return _datasource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> reauthenticateWithPassword(String currentPassword) {
    _ensureFirebaseReady();
    return _datasource.reauthenticateWithPassword(currentPassword);
  }

  @override
  Future<void> deleteCurrentAuthUser() {
    _ensureFirebaseReady();
    return _datasource.deleteCurrentAuthUser();
  }

  @override
  Future<void> signOut() async {
    if (!_bootstrapState.isReady) return;
    await _datasource.signOut();
  }
}
