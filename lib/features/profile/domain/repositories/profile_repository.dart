import '../../../authentication/domain/entities/auth_user.dart';
import '../entities/user_profile.dart';

/// Contrato de persistência do perfil do usuário no Firestore.
abstract interface class ProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);

  Future<UserProfile> ensureProfile({required AuthUser user});

  Future<void> updateProfile(UserProfile profile);

  Future<void> deleteUserData(String uid);
}
