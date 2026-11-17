import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRemoteDatasourceProvider =
    Provider<ProfileRemoteDatasource>((ref) {
  return ProfileRemoteDatasource();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(profileRemoteDatasourceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);

  return ProfileRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
    localStorage: localStorage,
  );
});

/// Observa em tempo real o perfil do usuário autenticado no Firestore,
/// garantindo criação idempotente no primeiro acesso.
final userProfileProvider = StreamProvider<UserProfile?>((ref) async* {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    yield null;
    return;
  }

  final repository = ref.watch(profileRepositoryProvider);
  await repository.ensureProfile(user: authUser);
  yield* repository.watchProfile(authUser.uid);
});
