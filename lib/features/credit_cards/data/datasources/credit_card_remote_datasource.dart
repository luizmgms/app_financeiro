import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../installments/data/models/installment_plan_model.dart';
import '../../../installments/domain/entities/installment_plan_entity.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/credit_card_entity.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../domain/services/credit_card_cycle_calculator.dart';
import '../models/credit_card_model.dart';
import '../models/invoice_model.dart';

/// Fonte de dados Firestore para Cartões de Crédito, Faturas e Parcelamentos.
class CreditCardRemoteDatasource {
  CreditCardRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _cardsCollection(String userId) {
    return _userDoc(userId).collection(FirestoreCollections.creditCards);
  }

  CollectionReference<Map<String, dynamic>> _invoicesCollection(String userId) {
    return _userDoc(userId).collection(FirestoreCollections.invoices);
  }

  CollectionReference<Map<String, dynamic>> _installmentsCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.installments);
  }

  CollectionReference<Map<String, dynamic>> _transactionsCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.transactions);
  }

  CollectionReference<Map<String, dynamic>> _accountsCollection(String userId) {
    return _userDoc(userId).collection(FirestoreCollections.accounts);
  }

  Stream<List<CreditCardEntity>> watchCards(String userId) {
    if (_firestore == null && Firebase.apps.isEmpty) {
      return Stream.value(const <CreditCardEntity>[]);
    }
    return _cardsCollection(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map(CreditCardModel.fromFirestore)
          .toList(growable: false);
      final sorted = List<CreditCardEntity>.of(list)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    });
  }

  Stream<List<InvoiceEntity>> watchInvoices(String userId) {
    if (_firestore == null && Firebase.apps.isEmpty) {
      return Stream.value(const <InvoiceEntity>[]);
    }
    return _invoicesCollection(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map(InvoiceModel.fromFirestore)
          .toList(growable: false);
      final sorted = List<InvoiceEntity>.of(list)
        ..sort((a, b) {
          final byYear = a.referenceYear.compareTo(b.referenceYear);
          if (byYear != 0) return byYear;
          return a.referenceMonth.compareTo(b.referenceMonth);
        });
      return sorted;
    });
  }

  Stream<List<InstallmentPlanEntity>> watchInstallmentPlans(String userId) {
    if (_firestore == null && Firebase.apps.isEmpty) {
      return Stream.value(const <InstallmentPlanEntity>[]);
    }
    return _installmentsCollection(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map(InstallmentPlanModel.fromFirestore)
          .toList(growable: false);
      final sorted = List<InstallmentPlanEntity>.of(list)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    });
  }

  Future<CreditCardEntity> createCard({
    required String userId,
    required CreditCardEntity card,
  }) async {
    final docRef = _cardsCollection(userId).doc();
    final now = DateTime.now();
    final toSave = card.copyWith(
      id: docRef.id,
      usedLimitCents: 0,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(CreditCardModel.toFirestore(toSave));
    return toSave;
  }

  Future<void> updateCard({
    required String userId,
    required CreditCardEntity card,
  }) async {
    final docRef = _cardsCollection(userId).doc(card.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw const ValidationFailure('Cartão de crédito não encontrado.');
      }
      final existing = CreditCardModel.fromFirestore(snap);
      final updated = card.copyWith(
        usedLimitCents: existing.usedLimitCents,
        updatedAt: DateTime.now(),
      );
      tx.update(
        docRef,
        FirestoreUtils.withoutCreatedAt(CreditCardModel.toFirestore(updated)),
      );
    });
  }

  Future<void> setArchived({
    required String userId,
    required String cardId,
    required bool archived,
  }) async {
    await _cardsCollection(userId).doc(cardId).update(<String, dynamic>{
      'isActive': !archived,
      'updatedAt': FirestoreUtils.toMillisTimestamp(DateTime.now()),
    });
  }

  Future<void> deleteCard({
    required String userId,
    required String cardId,
  }) async {
    final hasTx = await _transactionsCollection(userId)
        .where('cardId', isEqualTo: cardId)
        .limit(1)
        .get();
    final hasInv = await _invoicesCollection(userId)
        .where('cardId', isEqualTo: cardId)
        .limit(1)
        .get();

    if (hasTx.docs.isNotEmpty || hasInv.docs.isNotEmpty) {
      throw const ValidationFailure(
        'Este cartão possui faturas ou compras registradas. Arquive-o para preservar o histórico financeiro.',
      );
    }

    await _cardsCollection(userId).doc(cardId).delete();
  }

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
    final trimmedDesc = description.trim();
    if (trimmedDesc.isEmpty) {
      throw const ValidationFailure('Informe a descrição da compra.');
    }
    if (totalAmountCents <= 0) {
      throw const ValidationFailure('Informe um valor maior que zero.');
    }
    if (installmentCount < 1 || installmentCount > 48) {
      throw const ValidationFailure(
        'A quantidade de parcelas deve estar entre 1 e 48.',
      );
    }

    final cardRef = _cardsCollection(userId).doc(cardId);
    final planRef =
        installmentCount > 1 ? _installmentsCollection(userId).doc() : null;

    await _db.runTransaction((tx) async {
      // Fase 1: Leituras
      final cardSnap = await tx.get(cardRef);
      if (!cardSnap.exists) {
        throw const ValidationFailure('Cartão selecionado não encontrado.');
      }
      final card = CreditCardModel.fromFirestore(cardSnap);
      if (!card.isActive) {
        throw const ValidationFailure(
          'Apenas cartões ativos podem registrar novas compras.',
        );
      }

      final schedule = CreditCardCycleCalculator.buildCardInstallmentSchedule(
        cardId: card.id,
        totalAmountCents: totalAmountCents,
        installmentCount: installmentCount,
        purchaseDate: purchaseDate,
        closingDay: card.closingDay,
        dueDay: card.dueDay,
      );

      final invoiceRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final invoiceSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final slice in schedule) {
        final target = slice.invoiceTarget!;
        if (!invoiceRefs.containsKey(target.invoiceId)) {
          final ref = _invoicesCollection(userId).doc(target.invoiceId);
          invoiceRefs[target.invoiceId] = ref;
          invoiceSnaps[target.invoiceId] = await tx.get(ref);
        }
      }

      // Fase 2: Escritas
      final now = DateTime.now();
      if (planRef != null) {
        final firstSlice = schedule.first;
        final plan = InstallmentPlanEntity(
          id: planRef.id,
          description: trimmedDesc,
          totalAmountCents: totalAmountCents,
          installmentCount: installmentCount,
          firstCompetencyDate: firstSlice.competencyDate,
          firstDueDate: firstSlice.dueDate,
          cardId: card.id,
          categoryId: categoryId,
          notes: notes,
          status: InstallmentPlanStatus.active,
          createdAt: now,
          updatedAt: now,
        );
        tx.set(planRef, InstallmentPlanModel.toFirestore(plan));
      }

      final addedByInvoice = <String, int>{};
      final targetByInvoice = <String, InvoiceCycleTarget>{};

      for (final slice in schedule) {
        final target = slice.invoiceTarget!;
        final txRef = _transactionsCollection(userId).doc();
        final sliceDesc = installmentCount > 1
            ? '$trimmedDesc (${slice.installmentNumber}/$installmentCount)'
            : trimmedDesc;

        final purchaseTx = TransactionEntity(
          id: txRef.id,
          kind: TransactionKind.cardPurchase,
          description: sliceDesc,
          amountCents: slice.amountCents,
          categoryId: categoryId,
          cardId: card.id,
          invoiceId: target.invoiceId,
          installmentPlanId: planRef?.id,
          installmentNumber: slice.installmentNumber,
          totalInstallments: installmentCount,
          competencyDate: slice.competencyDate,
          dueDate: slice.dueDate,
          status: TransactionStatus.pending,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        );

        tx.set(txRef, TransactionModel.toFirestore(purchaseTx));
        addedByInvoice[target.invoiceId] =
            (addedByInvoice[target.invoiceId] ?? 0) + slice.amountCents;
        targetByInvoice[target.invoiceId] = target;
      }

      for (final entry in addedByInvoice.entries) {
        final invoiceId = entry.key;
        final addedCents = entry.value;
        final target = targetByInvoice[invoiceId]!;
        final invRef = invoiceRefs[invoiceId]!;
        final invSnap = invoiceSnaps[invoiceId]!;

        if (invSnap.exists) {
          final existingInv = InvoiceModel.fromFirestore(invSnap);
          final newTotal = existingInv.totalAmountCents + addedCents;
          final nextStatus = existingInv.paidAmountCents >= newTotal
              ? InvoiceStatus.paid
              : InvoiceStatus.open;
          final updatedInv = existingInv.copyWith(
            totalAmountCents: newTotal,
            status: nextStatus,
            updatedAt: now,
          );
          tx.update(
            invRef,
            FirestoreUtils.withoutCreatedAt(InvoiceModel.toFirestore(updatedInv)),
          );
        } else {
          final createdInv = InvoiceEntity(
            id: invoiceId,
            cardId: card.id,
            referenceYear: target.referenceYear,
            referenceMonth: target.referenceMonth,
            closingDate: target.closingDate,
            dueDate: target.dueDate,
            totalAmountCents: addedCents,
            paidAmountCents: 0,
            status: InvoiceStatus.open,
            createdAt: now,
            updatedAt: now,
          );
          tx.set(invRef, InvoiceModel.toFirestore(createdInv));
        }
      }

      tx.update(cardRef, <String, dynamic>{
        'usedLimitCents': card.usedLimitCents + totalAmountCents,
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });
    });
  }

  Future<void> recordCardStandaloneRefund({
    required String userId,
    required String cardId,
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime refundDate,
    String? notes,
  }) async {
    final trimmedDesc = description.trim();
    if (trimmedDesc.isEmpty) {
      throw const ValidationFailure('Informe a descrição do estorno.');
    }
    if (amountCents <= 0) {
      throw const ValidationFailure('Informe um valor de estorno maior que zero.');
    }

    final cardRef = _cardsCollection(userId).doc(cardId);
    final txRef = _transactionsCollection(userId).doc();

    await _db.runTransaction((tx) async {
      final cardSnap = await tx.get(cardRef);
      if (!cardSnap.exists) {
        throw const ValidationFailure('Cartão selecionado não encontrado.');
      }
      final card = CreditCardModel.fromFirestore(cardSnap);
      if (!card.isActive) {
        throw const ValidationFailure(
          'Apenas cartões ativos podem registrar novos estornos.',
        );
      }

      var target = CreditCardCycleCalculator.resolveInvoiceForPurchase(
        cardId: card.id,
        purchaseDate: refundDate,
        closingDay: card.closingDay,
        dueDay: card.dueDay,
      );
      var invRef = _invoicesCollection(userId).doc(target.invoiceId);
      var invSnap = await tx.get(invRef);

      if (invSnap.exists &&
          InvoiceModel.fromFirestore(invSnap).status == InvoiceStatus.paid) {
        target = CreditCardCycleCalculator.resolveInvoiceForPurchase(
          cardId: card.id,
          purchaseDate: refundDate,
          closingDay: card.closingDay,
          dueDay: card.dueDay,
          installmentOffset: 1,
        );
        invRef = _invoicesCollection(userId).doc(target.invoiceId);
        invSnap = await tx.get(invRef);
      }

      final now = DateTime.now();
      final refundTx = TransactionEntity(
        id: txRef.id,
        kind: TransactionKind.cardRefund,
        description: trimmedDesc,
        amountCents: amountCents,
        categoryId: categoryId,
        cardId: card.id,
        invoiceId: target.invoiceId,
        competencyDate: refundDate,
        dueDate: target.dueDate,
        status: TransactionStatus.pending,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(txRef, TransactionModel.toFirestore(refundTx));

      if (invSnap.exists) {
        final existingInv = InvoiceModel.fromFirestore(invSnap);
        final nextTotal =
            math.max(0, existingInv.totalAmountCents - amountCents);
        final updatedInv = existingInv.copyWith(
          totalAmountCents: nextTotal,
          updatedAt: now,
        );
        tx.update(
          invRef,
          FirestoreUtils.withoutCreatedAt(InvoiceModel.toFirestore(updatedInv)),
        );
      } else {
        final createdInv = InvoiceEntity(
          id: target.invoiceId,
          cardId: card.id,
          referenceYear: target.referenceYear,
          referenceMonth: target.referenceMonth,
          closingDate: target.closingDate,
          dueDate: target.dueDate,
          totalAmountCents: 0,
          paidAmountCents: 0,
          status: InvoiceStatus.open,
          createdAt: now,
          updatedAt: now,
        );
        tx.set(invRef, InvoiceModel.toFirestore(createdInv));
      }

      tx.update(cardRef, <String, dynamic>{
        'usedLimitCents': math.max(0, card.usedLimitCents - amountCents),
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });
    });
  }

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
    final trimmedDesc = description.trim();
    if (trimmedDesc.isEmpty) {
      throw const ValidationFailure('Informe a descrição do parcelamento.');
    }
    if (totalAmountCents <= 0) {
      throw const ValidationFailure('Informe um valor maior que zero.');
    }
    if (installmentCount < 2 || installmentCount > 48) {
      throw const ValidationFailure(
        'O parcelamento em conta deve ter entre 2 e 48 parcelas.',
      );
    }

    final accountRef = _accountsCollection(userId).doc(accountId);
    final planRef = _installmentsCollection(userId).doc();

    await _db.runTransaction((tx) async {
      final accountSnap = await tx.get(accountRef);
      if (!accountSnap.exists) {
        throw const ValidationFailure('Conta selecionada não encontrada.');
      }
      final account = AccountModel.fromFirestore(accountSnap);
      if (!account.isActive) {
        throw const ValidationFailure(
          'Selecione uma conta ativa para o parcelamento.',
        );
      }

      final schedule =
          CreditCardCycleCalculator.buildAccountInstallmentSchedule(
        totalAmountCents: totalAmountCents,
        installmentCount: installmentCount,
        purchaseDate: purchaseDate,
        firstDueDate: firstDueDate,
      );

      final now = DateTime.now();
      final plan = InstallmentPlanEntity(
        id: planRef.id,
        description: trimmedDesc,
        totalAmountCents: totalAmountCents,
        installmentCount: installmentCount,
        firstCompetencyDate: schedule.first.competencyDate,
        firstDueDate: schedule.first.dueDate,
        accountId: account.id,
        categoryId: categoryId,
        notes: notes,
        status: InstallmentPlanStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(planRef, InstallmentPlanModel.toFirestore(plan));

      for (final slice in schedule) {
        final txRef = _transactionsCollection(userId).doc();
        final installmentTx = TransactionEntity(
          id: txRef.id,
          kind: TransactionKind.expense,
          description:
              '$trimmedDesc (${slice.installmentNumber}/$installmentCount)',
          amountCents: slice.amountCents,
          categoryId: categoryId,
          accountId: account.id,
          installmentPlanId: planRef.id,
          installmentNumber: slice.installmentNumber,
          totalInstallments: installmentCount,
          competencyDate: slice.competencyDate,
          dueDate: slice.dueDate,
          status: TransactionStatus.pending,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        );
        tx.set(txRef, TransactionModel.toFirestore(installmentTx));
      }
    });
  }

  Future<void> payInvoice({
    required String userId,
    required String invoiceId,
    required String paymentAccountId,
    required DateTime paymentDate,
  }) async {
    final invoicePurchasesQuery = await _transactionsCollection(userId)
        .where('invoiceId', isEqualTo: invoiceId)
        .get();

    final invRef = _invoicesCollection(userId).doc(invoiceId);
    final accRef = _accountsCollection(userId).doc(paymentAccountId);
    final paymentTxRef = _transactionsCollection(userId).doc();

    await _db.runTransaction((tx) async {
      // Fase 1: Leituras
      final invSnap = await tx.get(invRef);
      if (!invSnap.exists) {
        throw const ValidationFailure('Fatura não encontrada.');
      }
      final invoice = InvoiceModel.fromFirestore(invSnap);
      final remainingCents = invoice.remainingAmountCents;
      if (remainingCents <= 0 || invoice.status == InvoiceStatus.paid) {
        throw const ValidationFailure('Esta fatura já está quitada.');
      }

      final cardRef = _cardsCollection(userId).doc(invoice.cardId);
      final cardSnap = await tx.get(cardRef);
      if (!cardSnap.exists) {
        throw const ValidationFailure('Cartão da fatura não encontrado.');
      }
      final card = CreditCardModel.fromFirestore(cardSnap);

      final accSnap = await tx.get(accRef);
      if (!accSnap.exists) {
        throw const ValidationFailure('Conta pagadora não encontrada.');
      }
      final account = AccountModel.fromFirestore(accSnap);
      if (!account.isActive) {
        throw const ValidationFailure(
          'Selecione uma conta ativa para pagar a fatura.',
        );
      }

      final purchaseSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in invoicePurchasesQuery.docs) {
        final snap = await tx.get(doc.reference);
        if (snap.exists) {
          purchaseSnaps.add(snap);
        }
      }

      // Fase 2: Escritas
      final now = DateTime.now();
      final paymentTx = TransactionEntity(
        id: paymentTxRef.id,
        kind: TransactionKind.invoicePayment,
        description: 'Pagamento fatura ${card.name} (${invoice.referenceLabel})',
        amountCents: remainingCents,
        accountId: account.id,
        cardId: card.id,
        invoiceId: invoice.id,
        competencyDate: paymentDate,
        dueDate: invoice.dueDate,
        paymentDate: paymentDate,
        status: TransactionStatus.paid,
        createdAt: now,
        updatedAt: now,
      );

      tx.set(paymentTxRef, TransactionModel.toFirestore(paymentTx));

      tx.update(accRef, <String, dynamic>{
        'currentBalanceCents': account.currentBalanceCents - remainingCents,
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });

      final updatedInvoice = invoice.copyWith(
        paidAmountCents: invoice.totalAmountCents,
        status: InvoiceStatus.paid,
        paymentTransactionId: paymentTxRef.id,
        paidAt: paymentDate,
        updatedAt: now,
      );
      tx.update(
        invRef,
        FirestoreUtils.withoutCreatedAt(InvoiceModel.toFirestore(updatedInvoice)),
      );

      tx.update(cardRef, <String, dynamic>{
        'usedLimitCents': math.max(0, card.usedLimitCents - remainingCents),
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });

      for (final snap in purchaseSnaps) {
        final purchase = TransactionModel.fromFirestore(snap);
        if ((purchase.kind == TransactionKind.cardPurchase ||
                purchase.kind == TransactionKind.cardRefund) &&
            !purchase.status.isSettled) {
          tx.update(snap.reference, <String, dynamic>{
            'status': TransactionStatus.paid.storageValue,
            'paymentDate': FirestoreUtils.toMillisTimestamp(paymentDate),
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }
      }
    });
  }

  Future<void> refundOrCancelCardPurchase({
    required String userId,
    required String transactionId,
    bool cancelAllPlanInstallments = true,
  }) async {
    final targetDocRef = _transactionsCollection(userId).doc(transactionId);
    final initialSnap = await targetDocRef.get();
    if (!initialSnap.exists) {
      throw const ValidationFailure('Compra não encontrada.');
    }
    final initialTx = TransactionModel.fromFirestore(initialSnap);
    if (initialTx.kind == TransactionKind.cardRefund) {
      await _removeStandaloneRefund(userId: userId, refundRef: targetDocRef);
      return;
    }
    if (initialTx.kind != TransactionKind.cardPurchase) {
      throw const ValidationFailure(
        'Apenas compras ou estornos no cartão podem ser revertidos por este fluxo.',
      );
    }

    final planId = initialTx.installmentPlanId;
    List<DocumentReference<Map<String, dynamic>>> txRefsToCancel;
    if (cancelAllPlanInstallments && planId != null && planId.isNotEmpty) {
      final planQuery = await _transactionsCollection(userId)
          .where('installmentPlanId', isEqualTo: planId)
          .get();
      txRefsToCancel = planQuery.docs
          .map((d) => d.reference)
          .toList(growable: false);
    } else {
      txRefsToCancel = <DocumentReference<Map<String, dynamic>>>[targetDocRef];
    }

    await _db.runTransaction((tx) async {
      // Fase 1: Leituras
      final txSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in txRefsToCancel) {
        final snap = await tx.get(ref);
        if (snap.exists) {
          txSnaps.add(snap);
        }
      }
      if (txSnaps.isEmpty) return;

      final purchases = txSnaps
          .map(TransactionModel.fromFirestore)
          .where((item) =>
              item.kind == TransactionKind.cardPurchase &&
              !item.status.isSettled)
          .toList(growable: false);

      if (purchases.isEmpty) {
        throw const ValidationFailure(
          'Esta compra já pertence a uma fatura paga e não possui parcelas em aberto para estorno.',
        );
      }

      final cardId = purchases.first.cardId;
      DocumentReference<Map<String, dynamic>>? cardRef;
      DocumentSnapshot<Map<String, dynamic>>? cardSnap;
      if (cardId != null && cardId.isNotEmpty) {
        cardRef = _cardsCollection(userId).doc(cardId);
        cardSnap = await tx.get(cardRef);
      }

      final invoiceRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      final invoiceSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final item in purchases) {
        final invId = item.invoiceId;
        if (invId != null &&
            invId.isNotEmpty &&
            !invoiceRefs.containsKey(invId)) {
          final ref = _invoicesCollection(userId).doc(invId);
          invoiceRefs[invId] = ref;
          invoiceSnaps[invId] = await tx.get(ref);
        }
      }

      DocumentReference<Map<String, dynamic>>? planRef;
      DocumentSnapshot<Map<String, dynamic>>? planSnap;
      if (planId != null && planId.isNotEmpty) {
        planRef = _installmentsCollection(userId).doc(planId);
        planSnap = await tx.get(planRef);
      }

      // Fase 2: Escritas
      final now = DateTime.now();
      var totalRefundedCents = 0;
      final deductionByInvoice = <String, int>{};

      for (final item in purchases) {
        totalRefundedCents += item.amountCents;
        if (item.invoiceId != null && item.invoiceId!.isNotEmpty) {
          deductionByInvoice[item.invoiceId!] =
              (deductionByInvoice[item.invoiceId!] ?? 0) + item.amountCents;
        }
        tx.delete(_transactionsCollection(userId).doc(item.id));
      }

      for (final entry in deductionByInvoice.entries) {
        final invId = entry.key;
        final deductedCents = entry.value;
        final invSnap = invoiceSnaps[invId];
        final invRef = invoiceRefs[invId];
        if (invSnap != null && invSnap.exists && invRef != null) {
          final inv = InvoiceModel.fromFirestore(invSnap);
          final nextTotal = math.max(0, inv.totalAmountCents - deductedCents);
          if (nextTotal == 0 && inv.paidAmountCents == 0) {
            tx.delete(invRef);
          } else {
            final nextStatus = inv.paidAmountCents >= nextTotal && nextTotal > 0
                ? InvoiceStatus.paid
                : inv.status;
            final updatedInv = inv.copyWith(
              totalAmountCents: nextTotal,
              status: nextStatus,
              updatedAt: now,
            );
            tx.update(
              invRef,
              FirestoreUtils.withoutCreatedAt(
                InvoiceModel.toFirestore(updatedInv),
              ),
            );
          }
        }
      }

      if (cardRef != null && cardSnap != null && cardSnap.exists) {
        final card = CreditCardModel.fromFirestore(cardSnap);
        tx.update(cardRef, <String, dynamic>{
          'usedLimitCents': math.max(0, card.usedLimitCents - totalRefundedCents),
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      }

      if (planRef != null && planSnap != null && planSnap.exists) {
        if (cancelAllPlanInstallments &&
            purchases.length == txSnaps.length) {
          tx.delete(planRef);
        } else {
          tx.update(planRef, <String, dynamic>{
            'status': InstallmentPlanStatus.canceled.storageValue,
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }
      }
    });
  }

  Future<void> _removeStandaloneRefund({
    required String userId,
    required DocumentReference<Map<String, dynamic>> refundRef,
  }) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(refundRef);
      if (!snap.exists) return;
      final refundTx = TransactionModel.fromFirestore(snap);
      if (refundTx.status.isSettled) {
        throw const ValidationFailure(
          'Não é possível excluir um estorno de uma fatura já paga.',
        );
      }

      DocumentReference<Map<String, dynamic>>? invRef;
      DocumentSnapshot<Map<String, dynamic>>? invSnap;
      if (refundTx.invoiceId != null && refundTx.invoiceId!.isNotEmpty) {
        invRef = _invoicesCollection(userId).doc(refundTx.invoiceId!);
        invSnap = await tx.get(invRef);
      }

      DocumentReference<Map<String, dynamic>>? cardRef;
      DocumentSnapshot<Map<String, dynamic>>? cardSnap;
      if (refundTx.cardId != null && refundTx.cardId!.isNotEmpty) {
        cardRef = _cardsCollection(userId).doc(refundTx.cardId!);
        cardSnap = await tx.get(cardRef);
      }

      final now = DateTime.now();
      tx.delete(refundRef);

      if (invRef != null && invSnap != null && invSnap.exists) {
        final inv = InvoiceModel.fromFirestore(invSnap);
        final updatedInv = inv.copyWith(
          totalAmountCents: inv.totalAmountCents + refundTx.amountCents,
          updatedAt: now,
        );
        tx.update(
          invRef,
          FirestoreUtils.withoutCreatedAt(InvoiceModel.toFirestore(updatedInv)),
        );
      }

      if (cardRef != null && cardSnap != null && cardSnap.exists) {
        final card = CreditCardModel.fromFirestore(cardSnap);
        tx.update(cardRef, <String, dynamic>{
          'usedLimitCents': card.usedLimitCents + refundTx.amountCents,
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      }
    });
  }
}
