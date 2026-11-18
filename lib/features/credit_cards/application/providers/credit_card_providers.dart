import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/app_bootstrap_provider.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../../installments/domain/entities/installment_plan_entity.dart';
import '../../data/datasources/credit_card_remote_datasource.dart';
import '../../data/repositories/credit_card_repository_impl.dart';
import '../../domain/entities/credit_card_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/repositories/credit_card_repository.dart';

final creditCardRemoteDatasourceProvider =
    Provider<CreditCardRemoteDatasource>((ref) {
  return CreditCardRemoteDatasource();
});

final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final datasource = ref.watch(creditCardRemoteDatasourceProvider);
  return CreditCardRepositoryImpl(
    bootstrapState: bootstrap.firebase,
    datasource: datasource,
  );
});

final creditCardsStreamProvider =
    StreamProvider<List<CreditCardEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <CreditCardEntity>[]);
  }

  return ref.watch(creditCardRepositoryProvider).watchCards(authUser.uid);
});

final activeCreditCardsProvider = Provider<List<CreditCardEntity>>((ref) {
  final all = ref.watch(creditCardsStreamProvider).valueOrNull ?? const [];
  return all.where((card) => card.isActive).toList(growable: false);
});

final archivedCreditCardsProvider = Provider<List<CreditCardEntity>>((ref) {
  final all = ref.watch(creditCardsStreamProvider).valueOrNull ?? const [];
  return all.where((card) => !card.isActive).toList(growable: false);
});

final creditCardsByIdProvider =
    Provider<Map<String, CreditCardEntity>>((ref) {
  final all = ref.watch(creditCardsStreamProvider).valueOrNull ?? const [];
  return <String, CreditCardEntity>{
    for (final card in all) card.id: card,
  };
});

final invoicesStreamProvider = StreamProvider<List<InvoiceEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <InvoiceEntity>[]);
  }

  return ref.watch(creditCardRepositoryProvider).watchInvoices(authUser.uid);
});

final invoicesByCardProvider =
    Provider<Map<String, List<InvoiceEntity>>>((ref) {
  final all = ref.watch(invoicesStreamProvider).valueOrNull ?? const [];
  final grouped = <String, List<InvoiceEntity>>{};
  for (final invoice in all) {
    grouped.putIfAbsent(invoice.cardId, () => <InvoiceEntity>[]).add(invoice);
  }
  return grouped;
});

final openInvoicesProvider = Provider<List<InvoiceEntity>>((ref) {
  final all = ref.watch(invoicesStreamProvider).valueOrNull ?? const [];
  return all
      .where(
        (invoice) =>
            invoice.status != InvoiceStatus.paid &&
            invoice.remainingAmountCents > 0,
      )
      .toList(growable: false);
});

final totalCreditLimitCentsProvider = Provider<int>((ref) {
  final active = ref.watch(activeCreditCardsProvider);
  return active.fold<int>(0, (sum, card) => sum + card.totalLimitCents);
});

final totalUsedLimitCentsProvider = Provider<int>((ref) {
  final active = ref.watch(activeCreditCardsProvider);
  return active.fold<int>(0, (sum, card) => sum + card.usedLimitCents);
});

final totalAvailableLimitCentsProvider = Provider<int>((ref) {
  final active = ref.watch(activeCreditCardsProvider);
  return active.fold<int>(0, (sum, card) => sum + card.availableLimitCents);
});

final totalOpenInvoicesAmountCentsProvider = Provider<int>((ref) {
  final open = ref.watch(openInvoicesProvider);
  return open.fold<int>(0, (sum, inv) => sum + inv.remainingAmountCents);
});

final installmentPlansStreamProvider =
    StreamProvider<List<InstallmentPlanEntity>>((ref) {
  final bootstrap = ref.watch(appBootstrapStateProvider);
  final authUser = ref.watch(currentAuthUserProvider);
  if (!bootstrap.firebase.isReady || authUser == null) {
    return Stream.value(const <InstallmentPlanEntity>[]);
  }

  return ref
      .watch(creditCardRepositoryProvider)
      .watchInstallmentPlans(authUser.uid);
});
