import 'package:firebase_core/firebase_core.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../../core/services/firebase_bootstrap_service.dart';
import '../../../installments/domain/entities/installment_plan_entity.dart';
import '../../domain/entities/credit_card_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/repositories/credit_card_repository.dart';
import '../datasources/credit_card_remote_datasource.dart';

class CreditCardRepositoryImpl implements CreditCardRepository {
  CreditCardRepositoryImpl({
    required FirebaseBootstrapState bootstrapState,
    required CreditCardRemoteDatasource datasource,
  })  : _bootstrapState = bootstrapState,
        _datasource = datasource;

  final FirebaseBootstrapState _bootstrapState;
  final CreditCardRemoteDatasource _datasource;

  void _ensureReady() {
    if (!_bootstrapState.isReady) {
      throw const NotConfiguredFailure();
    }
  }

  @override
  Stream<List<CreditCardEntity>> watchCards(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <CreditCardEntity>[]);
    }
    return _datasource.watchCards(userId);
  }

  @override
  Stream<List<InvoiceEntity>> watchInvoices(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <InvoiceEntity>[]);
    }
    return _datasource.watchInvoices(userId);
  }

  @override
  Stream<List<InstallmentPlanEntity>> watchInstallmentPlans(String userId) {
    if (!_bootstrapState.isReady) {
      return Stream.value(const <InstallmentPlanEntity>[]);
    }
    return _datasource.watchInstallmentPlans(userId);
  }

  @override
  Future<CreditCardEntity> createCard({
    required String userId,
    required CreditCardEntity card,
  }) async {
    _ensureReady();
    try {
      return await _datasource.createCard(userId: userId, card: card);
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> updateCard({
    required String userId,
    required CreditCardEntity card,
  }) async {
    _ensureReady();
    try {
      await _datasource.updateCard(userId: userId, card: card);
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> setArchived({
    required String userId,
    required String cardId,
    required bool archived,
  }) async {
    _ensureReady();
    try {
      await _datasource.setArchived(
        userId: userId,
        cardId: cardId,
        archived: archived,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> deleteCard({
    required String userId,
    required String cardId,
  }) async {
    _ensureReady();
    try {
      await _datasource.deleteCard(userId: userId, cardId: cardId);
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> recordCardPurchase({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int totalAmountCents,
    required int installmentCount,
    required DateTime purchaseDate,
    String? notes,
  }) async {
    _ensureReady();
    try {
      await _datasource.recordCardPurchase(
        userId: userId,
        cardId: cardId,
        categoryId: categoryId,
        description: description,
        totalAmountCents: totalAmountCents,
        installmentCount: installmentCount,
        purchaseDate: purchaseDate,
        notes: notes,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> recordCardStandaloneRefund({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime refundDate,
    String? notes,
  }) async {
    _ensureReady();
    try {
      await _datasource.recordCardStandaloneRefund(
        userId: userId,
        cardId: cardId,
        categoryId: categoryId,
        description: description,
        amountCents: amountCents,
        refundDate: refundDate,
        notes: notes,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> recordAccountInstallmentPurchase({
    required String userId,
    required String accountId,
    required String categoryId,
    required String description,
    required int totalAmountCents,
    required int installmentCount,
    required DateTime purchaseDate,
    required DateTime firstDueDate,
    String? notes,
  }) async {
    _ensureReady();
    try {
      await _datasource.recordAccountInstallmentPurchase(
        userId: userId,
        accountId: accountId,
        categoryId: categoryId,
        description: description,
        totalAmountCents: totalAmountCents,
        installmentCount: installmentCount,
        purchaseDate: purchaseDate,
        firstDueDate: firstDueDate,
        notes: notes,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> payInvoice({
    required String userId,
    required String invoiceId,
    required String paymentAccountId,
    required DateTime paymentDate,
  }) async {
    _ensureReady();
    try {
      await _datasource.payInvoice(
        userId: userId,
        invoiceId: invoiceId,
        paymentAccountId: paymentAccountId,
        paymentDate: paymentDate,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> refundOrCancelCardPurchase({
    required String userId,
    required String transactionId,
    bool cancelAllPlanInstallments = true,
  }) async {
    _ensureReady();
    try {
      await _datasource.refundOrCancelCardPurchase(
        userId: userId,
        transactionId: transactionId,
        cancelAllPlanInstallments: cancelAllPlanInstallments,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapException(e);
    }
  }

  Failure _mapException(FirebaseException error) {
    return mapFirebaseFailure(
      error,
      fallbackMessage: 'Não foi possível processar a operação do cartão.',
    );
  }
}
