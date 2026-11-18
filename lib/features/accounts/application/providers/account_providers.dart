import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../data/datasources/account_remote_datasource.dart';
import '../../data/repositories/account_repository_impl.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/services/account_balance_calculator.dart';

final accountRemoteDatasourceProvider =
    Provider<AccountRemoteDatasource>((ref) {
  return AccountRemoteDatasource();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(accountRemoteDatasourceProvider);
  return AccountRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
  );
});

final accountsStreamProvider = StreamProvider<List<AccountEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <AccountEntity>[]);
  }

  return ref.watch(accountRepositoryProvider).watchAccounts(authUser.uid);
});

final activeAccountsProvider = Provider<List<AccountEntity>>((ref) {
  final all = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
  return all.where((account) => account.isActive).toList(growable: false);
});

final accountsByIdProvider = Provider<Map<String, AccountEntity>>((ref) {
  final all = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
  return <String, AccountEntity>{
    for (final account in all) account.id: account,
  };
});

final totalAvailableBalanceCentsProvider = Provider<int>((ref) {
  final active = ref.watch(activeAccountsProvider);
  return AccountBalanceCalculator.totalActiveBalance(
    active.map((account) => account.currentBalanceCents),
  );
});
