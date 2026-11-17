import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

/// Implementação do repositório de perfil sincronizada com Firestore e Hive.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required ProfileRemoteDatasource datasource,
    required LocalStorageService localStorage,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource,
        _localStorage = localStorage;

  final FirebaseBootstrapState _bootstrapState;
  final ProfileRemoteDatasource _datasource;
  final LocalStorageService _localStorage;

  void _ensureFirebaseReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure(
        'Firebase ainda não conectado. Execute "flutterfire configure" para salvar perfil na nuvem.',
      );
    }
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    if (!_bootstrapState.isReady) {
      return Stream<UserProfile?>.value(null);
    }
    return _datasource.watchProfile(uid);
  }

  @override
  Future<UserProfile> ensureProfile({required AuthUser user}) async {
    _ensureFirebaseReady();
    final profile = await _datasource.ensureProfile(user: user);
    await _localStorage.saveLocaleCode(profile.localeCode);
    return profile;
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _ensureFirebaseReady();
    await _datasource.updateProfile(profile);
    await _localStorage.saveLocaleCode(profile.localeCode);
  }

  @override
  Future<void> deleteUserData(String uid) async {
    _ensureFirebaseReady();
    await _datasource.deleteUserData(uid);
  }
}
