import '../../../installments/domain/entities/installment_plan_entity.dart';
import '../entities/credit_card_entity.dart';
import '../entities/invoice_entity.dart';

/// Contrato de persistência para Cartões de Crédito, Faturas e Compras Parceladas.
abstract class CreditCardRepository {
  Stream<List<CreditCardEntity>> watchCards(String userId);

  Stream<List<InvoiceEntity>> watchInvoices(String userId);

  Stream<List<InstallmentPlanEntity>> watchInstallmentPlans(String userId);

  Future<CreditCardEntity> createCard({
    required String userId,
    required CreditCardEntity card,
  });

  Future<void> updateCard({
    required String userId,
    required CreditCardEntity card,
  });

  Future<void> setArchived({
    required String userId,
    required String cardId,
    required bool archived,
  });

  Future<void> deleteCard({
    required String userId,
    required String cardId,
  });

  /// Registra compra no cartão (à vista ou parcelada), atualizando/criando as
  /// faturas de destino, o plano de parcelamento (se `installmentCount > 1`)
  /// e o `usedLimitCents` do cartão de forma atômica.
  Future<void> recordCardPurchase({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int totalAmountCents,
    required int installmentCount,
    required DateTime purchaseDate,
    String? notes,
  });

  /// Registra um estorno ou crédito avulso diretamente na fatura do cartão
  /// (sem vínculo obrigatório com uma compra específica), abatendo o valor da
  /// fatura e recompondo o limite utilizado do cartão.
  Future<void> recordCardStandaloneRefund({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime refundDate,
    String? notes,
  });

  /// Registra um parcelamento de despesa direta em conta/boleto (sem cartão).
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
  });

  /// Paga uma fatura de cartão de crédito gerando uma movimentação `invoice_payment`
  /// na conta bancária selecionada, recompondo o limite do cartão e quitando
  /// os lançamentos da fatura sem duplicar despesa nos relatórios.
  Future<void> payInvoice({
    required String userId,
    required String invoiceId,
    required String paymentAccountId,
    required DateTime paymentDate,
  });

  /// Estorna ou exclui uma compra de cartão (ou todas as parcelas pendentes de um
  /// plano de parcelamento), recompondo o total das faturas e o limite do cartão.
  Future<void> refundOrCancelCardPurchase({
    required String userId,
    required String transactionId,
    bool cancelAllPlanInstallments = true,
  });
}
