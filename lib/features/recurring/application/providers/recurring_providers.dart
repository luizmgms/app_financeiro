import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../data/datasources/recurring_remote_datasource.dart';
import '../../data/repositories/recurring_repository_impl.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../../domain/repositories/recurring_repository.dart';

final recurringRemoteDatasourceProvider =
    Provider<RecurringRemoteDatasource>((ref) {
  return RecurringRemoteDatasource();
});

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(recurringRemoteDatasourceProvider);
  return RecurringRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
  );
});

final recurringRulesStreamProvider =
    StreamProvider<List<RecurringRuleEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <RecurringRuleEntity>[]);
  }
  return ref.watch(recurringRepositoryProvider).watchRules(authUser.uid);
});

final activeRecurringRulesProvider =
    Provider<List<RecurringRuleEntity>>((ref) {
  final all = ref.watch(recurringRulesStreamProvider).valueOrNull ?? const [];
  return all
      .where((rule) => rule.status == RecurringStatus.active)
      .toList(growable: false);
});

final monthlyEstimatedRecurringIncomeCentsProvider = Provider<int>((ref) {
  final active = ref.watch(activeRecurringRulesProvider);
  return active
      .where((r) => r.kind == RecurringKind.income)
      .fold<int>(
        0,
        (sum, r) =>
            sum +
            (r.amountCents * r.frequency.monthlyMultiplier(r.customIntervalDays))
                .round(),
      );
});

final monthlyEstimatedRecurringExpenseCentsProvider = Provider<int>((ref) {
  final active = ref.watch(activeRecurringRulesProvider);
  return active
      .where((r) => r.kind == RecurringKind.expense)
      .fold<int>(
        0,
        (sum, r) =>
            sum +
            (r.amountCents * r.frequency.monthlyMultiplier(r.customIntervalDays))
                .round(),
      );
});
