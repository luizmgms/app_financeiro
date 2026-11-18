import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/firebase_error_mapper.dart';
import '../../../authentication/application/providers/auth_providers.dart';
import '../../domain/entities/credit_card_entity.dart';
import '../providers/credit_card_providers.dart';

class CreditCardActionState extends Equatable {
  const CreditCardActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  @override
  List<Object?> get props => [isLoading, errorMessage, successMessage];
}

/// Controller para gestão de cartões de crédito, faturas, compras parceladas e estornos.
class CreditCardController extends Notifier<CreditCardActionState> {
  @override
  CreditCardActionState build() => const CreditCardActionState();

  Future<bool> saveCard({
    CreditCardEntity? existing,
    required String name,
    required String institution,
    required CardBrand brand,
    required int totalLimitCents,
    required int closingDay,
    required int dueDay,
    String? paymentAccountId,
    required String colorHex,
    int defaultInstallments = 1,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const CreditCardActionState(
        errorMessage: 'Faça login para gerenciar cartões de crédito.',
      );
      return false;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Informe o nome do cartão.',
      );
      return false;
    }
    if (totalLimitCents < 0) {
      state = const CreditCardActionState(
        errorMessage: 'O limite do cartão não pode ser negativo.',
      );
      return false;
    }
    if (closingDay < 1 || closingDay > 31 || dueDay < 1 || dueDay > 31) {
      state = const CreditCardActionState(
        errorMessage:
            'Os dias de fechamento e vencimento devem estar entre 1 e 31.',
      );
      return false;
    }

    final safeDefaultInstallments =
        defaultInstallments < 1 ? 1 : defaultInstallments;

    state = const CreditCardActionState(isLoading: true);
    try {
      final repo = ref.read(creditCardRepositoryProvider);
      final now = DateTime.now();

      if (existing == null) {
        final created = CreditCardEntity(
          id: '',
          name: trimmedName,
          institution: institution.trim(),
          brand: brand,
          totalLimitCents: totalLimitCents,
          usedLimitCents: 0,
          closingDay: closingDay,
          dueDay: dueDay,
          paymentAccountId: paymentAccountId,
          colorHex: colorHex,
          defaultInstallments: safeDefaultInstallments,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createCard(userId: user.uid, card: created);
        state = const CreditCardActionState(
          successMessage: 'Cartão criado com sucesso.',
        );
      } else {
        final updated = existing.copyWith(
          name: trimmedName,
          institution: institution.trim(),
          brand: brand,
          totalLimitCents: totalLimitCents,
          closingDay: closingDay,
          dueDay: dueDay,
          paymentAccountId: paymentAccountId,
          clearPaymentAccountId: paymentAccountId == null,
          colorHex: colorHex,
          defaultInstallments: safeDefaultInstallments,
          updatedAt: now,
        );
        await repo.updateCard(userId: user.uid, card: updated);
        state = const CreditCardActionState(
          successMessage: 'Cartão atualizado com sucesso.',
        );
      }
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível salvar o cartão.',
        ),
      );
      return false;
    }
  }

  Future<bool> setArchived({
    required String cardId,
    required bool archived,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const CreditCardActionState(isLoading: true);
    try {
      await ref.read(creditCardRepositoryProvider).setArchived(
            userId: user.uid,
            cardId: cardId,
            archived: archived,
          );
      state = CreditCardActionState(
        successMessage: archived
            ? 'Cartão arquivado com sucesso.'
            : 'Cartão reativado com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível atualizar o status do cartão.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteCard(String cardId) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const CreditCardActionState(isLoading: true);
    try {
      await ref.read(creditCardRepositoryProvider).deleteCard(
            userId: user.uid,
            cardId: cardId,
          );
      state = const CreditCardActionState(
        successMessage: 'Cartão excluído com sucesso.',
      );
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível excluir o cartão.',
        ),
      );
      return false;
    }
  }

  Future<bool> recordCardPurchase({
    required String cardId,
    required String categoryId,
    required String description,
    required int totalAmountCents,
    required DateTime purchaseDate,
    int totalInstallments = 1,
    String? notes,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const CreditCardActionState(
        errorMessage: 'Faça login para registrar compras no cartão.',
      );
      return false;
    }

    if (description.trim().isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Informe a descrição da compra.',
      );
      return false;
    }
    if (totalAmountCents <= 0) {
      state = const CreditCardActionState(
        errorMessage: 'Informe um valor maior que zero.',
      );
      return false;
    }
    if (categoryId.isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Selecione uma categoria.',
      );
      return false;
    }
    if (totalInstallments < 1 || totalInstallments > 48) {
      state = const CreditCardActionState(
        errorMessage: 'O número de parcelas deve estar entre 1 e 48.',
      );
      return false;
    }

    state = const CreditCardActionState(isLoading: true);
    try {
      await ref.read(creditCardRepositoryProvider).recordCardPurchase(
            userId: user.uid,
            cardId: cardId,
            categoryId: categoryId,
            description: description.trim(),
            totalAmountCents: totalAmountCents,
            purchaseDate: purchaseDate,
            installmentCount: totalInstallments,
            notes: notes,
          );
      state = CreditCardActionState(
        successMessage: totalInstallments > 1
            ? 'Compra parcelada ($totalInstallments parcelas) registrada no cartão.'
            : 'Compra registrada na fatura do cartão.',
      );
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível registrar a compra no cartão.',
        ),
      );
      return false;
    }
  }

  Future<bool> recordCardStandaloneRefund({
    required String cardId,
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime refundDate,
    String? notes,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const CreditCardActionState(
        errorMessage: 'Faça login para registrar estornos no cartão.',
      );
      return false;
    }

    if (description.trim().isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Informe a descrição do estorno.',
      );
      return false;
    }
    if (amountCents <= 0) {
      state = const CreditCardActionState(
        errorMessage: 'Informe um valor maior que zero.',
      );
      return false;
    }
    if (categoryId.isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Selecione uma categoria.',
      );
      return false;
    }

    state = const CreditCardActionState(isLoading: true);
    try {
      await ref.read(creditCardRepositoryProvider).recordCardStandaloneRefund(
            userId: user.uid,
            cardId: cardId,
            categoryId: categoryId,
            description: description.trim(),
            amountCents: amountCents,
            refundDate: refundDate,
            notes: notes,
          );
      state = const CreditCardActionState(
        successMessage:
            'Estorno avulso registrado na fatura e limite recomposto.',
      );
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível registrar o estorno avulso.',
        ),
      );
      return false;
    }
  }

  Future<bool> recordAccountInstallmentPurchase({
    required String accountId,
    required String categoryId,
    required String description,
    required int totalAmountCents,
    required DateTime purchaseDate,
    required int totalInstallments,
    String? notes,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const CreditCardActionState(
        errorMessage: 'Faça login para registrar parcelamentos.',
      );
      return false;
    }

    if (description.trim().isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Informe a descrição do parcelamento.',
      );
      return false;
    }
    if (totalAmountCents <= 0) {
      state = const CreditCardActionState(
        errorMessage: 'Informe um valor maior que zero.',
      );
      return false;
    }
    if (categoryId.isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Selecione uma categoria.',
      );
      return false;
    }
    if (totalInstallments < 2 || totalInstallments > 48) {
      state = const CreditCardActionState(
        errorMessage: 'O parcelamento em conta deve ter entre 2 e 48 parcelas.',
      );
      return false;
    }

    state = const CreditCardActionState(isLoading: true);
    try {
      await ref
          .read(creditCardRepositoryProvider)
          .recordAccountInstallmentPurchase(
            userId: user.uid,
            accountId: accountId,
            categoryId: categoryId,
            description: description.trim(),
            totalAmountCents: totalAmountCents,
            purchaseDate: purchaseDate,
            firstDueDate: purchaseDate,
            installmentCount: totalInstallments,
            notes: notes,
          );
      state = CreditCardActionState(
        successMessage:
            'Parcelamento em conta ($totalInstallments parcelas) registrado.',
      );
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível registrar o parcelamento.',
        ),
      );
      return false;
    }
  }

  Future<bool> payInvoice({
    required String invoiceId,
    required String paymentAccountId,
    required DateTime paymentDate,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) {
      state = const CreditCardActionState(
        errorMessage: 'Faça login para pagar faturas.',
      );
      return false;
    }
    if (paymentAccountId.isEmpty) {
      state = const CreditCardActionState(
        errorMessage: 'Selecione a conta de pagamento.',
      );
      return false;
    }

    state = const CreditCardActionState(isLoading: true);
    try {
      await ref.read(creditCardRepositoryProvider).payInvoice(
            userId: user.uid,
            invoiceId: invoiceId,
            paymentAccountId: paymentAccountId,
            paymentDate: paymentDate,
          );
      state = const CreditCardActionState(
        successMessage: 'Fatura paga com sucesso e limite recomposto.',
      );
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível pagar a fatura.',
        ),
      );
      return false;
    }
  }

  Future<bool> refundOrCancelCardPurchase({
    required String transactionId,
    bool cancelEntirePlan = false,
  }) async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return false;

    state = const CreditCardActionState(isLoading: true);
    try {
      await ref.read(creditCardRepositoryProvider).refundOrCancelCardPurchase(
            userId: user.uid,
            transactionId: transactionId,
            cancelAllPlanInstallments: cancelEntirePlan,
          );
      state = CreditCardActionState(
        successMessage: cancelEntirePlan
            ? 'Parcelamento estornado e parcelas futuras canceladas.'
            : 'Compra estornada e limite recomposto.',
      );
      return true;
    } on Failure catch (failure) {
      state = CreditCardActionState(errorMessage: failure.message);
      return false;
    } catch (error) {
      state = CreditCardActionState(
        errorMessage: formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível estornar a compra.',
        ),
      );
      return false;
    }
  }
}

final creditCardControllerProvider =
    NotifierProvider<CreditCardController, CreditCardActionState>(
  CreditCardController.new,
);
