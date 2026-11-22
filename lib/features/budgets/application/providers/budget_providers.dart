import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/date_period.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../categories/application/providers/category_providers.dart';
import '../../../notifications/domain/services/notification_evaluation_service.dart';
import '../../../profile/application/providers/profile_providers.dart';
import '../../../transactions/application/providers/transaction_providers.dart';
import '../../data/datasources/budget_remote_datasource.dart';
import '../../data/repositories/budget_repository_impl.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/services/budget_calculator.dart';

final budgetRemoteDatasourceProvider = Provider<BudgetRemoteDatasource>((ref) {
  return BudgetRemoteDatasource();
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(budgetRemoteDatasourceProvider);
  return BudgetRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
  );
});

final budgetsStreamProvider = StreamProvider<List<BudgetEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <BudgetEntity>[]);
  }
  return ref.watch(budgetRepositoryProvider).watchBudgets(authUser.uid);
});

/// Orçamentos avaliados para o mês contábil vigente do usuário.
final currentMonthBudgetUsagesProvider =
    Provider<List<BudgetUsageItem>>((ref) {
  final budgets = ref.watch(budgetsStreamProvider).valueOrNull ?? const [];
  final transactions =
      ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
  final monthStartDay =
      ref.watch(userProfileProvider).valueOrNull?.monthStartDay ?? 1;
  final currentYm = DatePeriod.resolveAccountingYearMonth(
    DateTime.now(),
    monthStartDay: monthStartDay,
  );

  return BudgetCalculator.evaluateMonth(
    budgets: budgets,
    transactions: transactions,
    year: currentYm.year,
    month: currentYm.month,
    monthStartDay: monthStartDay,
  );
});

/// Converte os orçamentos do mês atual em entradas para o motor de notificações.
final currentMonthBudgetAlertInputsProvider =
    Provider<List<BudgetAlertEvaluationInput>>((ref) {
  final usages = ref.watch(currentMonthBudgetUsagesProvider);
  final categoriesById = ref.watch(categoriesByIdProvider);
  return usages
      .map(
        (u) => BudgetAlertEvaluationInput(
          budgetId: u.budget.id,
          categoryName:
              categoriesById[u.budget.categoryId]?.name ?? 'Categoria',
          year: u.budget.year,
          month: u.budget.month,
          limitCents: u.limitCents,
          spentCents: u.spentCents,
          alertThresholdPercent: u.budget.alertThresholdPercent,
        ),
      )
      .toList(growable: false);
});
