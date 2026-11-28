import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/attachment_storage_service.dart';
import '../../../../shared/models/date_period.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/repositories/transaction_repository.dart';

final attachmentStorageServiceProvider =
    Provider<AttachmentStorageService>((ref) {
  return FirebaseAttachmentStorageService();
});

final transactionRemoteDatasourceProvider =
    Provider<TransactionRemoteDatasource>((ref) {
  return TransactionRemoteDatasource(
    attachmentStorage: ref.watch(attachmentStorageServiceProvider),
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(transactionRemoteDatasourceProvider);
  return TransactionRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
  );
});

final transactionsStreamProvider =
    StreamProvider<List<TransactionEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <TransactionEntity>[]);
  }

  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactions(authUser.uid);
});

class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => TransactionFilter.initial();

  void setPeriod(DatePeriod period) {
    state = state.copyWith(period: period);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setKind(TransactionKind? kind) {
    state = kind == null
        ? state.copyWith(clearKind: true)
        : state.copyWith(kind: kind);
  }

  void setCategoryId(String? categoryId) {
    state = categoryId == null
        ? state.copyWith(clearCategoryId: true)
        : state.copyWith(categoryId: categoryId);
  }

  void setAccountId(String? accountId) {
    state = accountId == null
        ? state.copyWith(clearAccountId: true)
        : state.copyWith(accountId: accountId);
  }

  void setStatusFilter(TransactionStatusFilter statusFilter) {
    state = state.copyWith(statusFilter: statusFilter);
  }

  void resetSecondaryFilters() {
    state = TransactionFilter(period: state.period);
  }
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilter>(
  TransactionFilterNotifier.new,
);

final filteredTransactionsProvider = Provider<List<TransactionEntity>>((ref) {
  final all = ref.watch(transactionsStreamProvider).valueOrNull ?? const [];
  final filter = ref.watch(transactionFilterProvider);
  final filtered = all.where(filter.matches).toList()
    ..sort(TransactionEntity.compareByRecencyDesc);
  return filtered;
});

final filteredTransactionsSummaryProvider =
    Provider<TransactionPeriodSummary>((ref) {
  final filtered = ref.watch(filteredTransactionsProvider);
  return TransactionPeriodSummary.fromTransactions(filtered);
});
