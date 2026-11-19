import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../../credit_cards/data/models/credit_card_model.dart';
import '../../../credit_cards/data/models/invoice_model.dart';
import '../../../credit_cards/domain/entities/invoice_entity.dart';
import '../../../credit_cards/domain/services/credit_card_cycle_calculator.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../../domain/services/recurring_schedule_calculator.dart';
import '../models/recurring_rule_model.dart';

/// Datasource Cloud Firestore para regras de contas recorrentes e geração
/// idempotente das ocorrências futuras em `transactions` e `invoices`.
class RecurringRemoteDatasource {
  RecurringRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _recurringCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.recurring);
  }

  CollectionReference<Map<String, dynamic>> _transactionsCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.transactions);
  }

  Stream<List<RecurringRuleEntity>> watchRules(String userId) {
    if (_firestore == null && Firebase.apps.isEmpty) {
      return Stream.value(const <RecurringRuleEntity>[]);
    }
    return _recurringCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RecurringRuleModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<RecurringRuleEntity> createRule({
    required String userId,
    required RecurringRuleEntity rule,
    DateTime? referenceDate,
  }) async {
    final now = DateTime.now();
    final docRef = _recurringCollection(userId).doc();
    final toSave = rule.copyWith(
      id: docRef.id,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(RecurringRuleModel.toFirestore(toSave));
    await _generateMissingOccurrencesForRule(
      userId: userId,
      rule: toSave,
      referenceDate: referenceDate ?? now,
    );
    return toSave;
  }

  Future<void> updateRule({
    required String userId,
    required RecurringRuleEntity rule,
  }) async {
    final now = DateTime.now();
    final updated = rule.copyWith(updatedAt: now);
    final payload = FirestoreUtils.withoutCreatedAt(
      RecurringRuleModel.toFirestore(updated),
    );
    await _recurringCollection(userId).doc(rule.id).update(payload);
    if (updated.status == RecurringStatus.active) {
      await _generateMissingOccurrencesForRule(
        userId: userId,
        rule: updated,
        referenceDate: now,
      );
    }
  }

  Future<void> setStatus({
    required String userId,
    required String ruleId,
    required RecurringStatus status,
  }) async {
    final now = DateTime.now();
    final docRef = _recurringCollection(userId).doc(ruleId);
    await docRef.update(<String, dynamic>{
      'status': status.storageValue,
      'updatedAt': FirestoreUtils.toMillisTimestamp(now),
    });

    if (status == RecurringStatus.active) {
      final snap = await docRef.get();
      if (snap.exists) {
        final rule = RecurringRuleModel.fromFirestore(snap);
        await _generateMissingOccurrencesForRule(
          userId: userId,
          rule: rule,
          referenceDate: now,
        );
      }
    }
  }

  Future<void> deleteRule({
    required String userId,
    required String ruleId,
  }) async {
    await _recurringCollection(userId).doc(ruleId).delete();
  }

  Future<int> syncOccurrences({
    required String userId,
    DateTime? referenceDate,
  }) async {
    final ref = referenceDate ?? DateTime.now();
    final activeRulesSnap = await _recurringCollection(userId)
        .where('status', isEqualTo: RecurringStatus.active.storageValue)
        .get();

    var createdTotal = 0;
    for (final doc in activeRulesSnap.docs) {
      final rule = RecurringRuleModel.fromFirestore(doc);
      createdTotal += await _generateMissingOccurrencesForRule(
        userId: userId,
        rule: rule,
        referenceDate: ref,
      );
    }
    return createdTotal;
  }

  Future<int> _generateMissingOccurrencesForRule({
    required String userId,
    required RecurringRuleEntity rule,
    required DateTime referenceDate,
  }) async {
    final specs = RecurringScheduleCalculator.computeOccurrencesInWindow(
      rule: rule,
      referenceDate: referenceDate,
    );
    if (specs.isEmpty) return 0;

    final ruleRef = _recurringCollection(userId).doc(rule.id);

    return _db.runTransaction<int>((tx) async {
      // 1. TODAS AS LEITURAS ANTES DE QUALQUER ESCRITA.
      final freshRuleSnap = await tx.get(ruleRef);
      if (!freshRuleSnap.exists) return 0;
      final freshRule = RecurringRuleModel.fromFirestore(freshRuleSnap);
      if (freshRule.status != RecurringStatus.active) return 0;

      final skipped = freshRule.skippedOccurrenceKeys.toSet();
      final missingSpecs = <RecurringOccurrenceSpec>[];
      for (final spec in specs) {
        if (skipped.contains(spec.occurrenceKey)) continue;
        final txRef = _transactionsCollection(userId).doc(spec.transactionDocId);
        final txSnap = await tx.get(txRef);
        if (!txSnap.exists) {
          missingSpecs.add(spec);
        }
      }
      if (missingSpecs.isEmpty) return 0;

      final now = DateTime.now();

      if (freshRule.isCardTarget) {
        final cardRef = _userDoc(userId)
            .collection(FirestoreCollections.creditCards)
            .doc(freshRule.cardId!);
        final cardSnap = await tx.get(cardRef);
        if (!cardSnap.exists) return 0;
        final card = CreditCardModel.fromFirestore(cardSnap);

        final specCycles = <String, InvoiceCycleTarget>{};
        final uniqueInvoiceIds = <String, InvoiceCycleTarget>{};
        for (final spec in missingSpecs) {
          final cycle = CreditCardCycleCalculator.resolveInvoiceForPurchase(
            cardId: card.id,
            purchaseDate: spec.scheduledDate,
            closingDay: card.closingDay,
            dueDay: card.dueDay,
          );
          specCycles[spec.transactionDocId] = cycle;
          uniqueInvoiceIds[cycle.invoiceId] = cycle;
        }

        final invoiceSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        final invoiceRefs = <String, DocumentReference<Map<String, dynamic>>>{};
        for (final invoiceId in uniqueInvoiceIds.keys) {
          final invRef = _userDoc(userId)
              .collection(FirestoreCollections.invoices)
              .doc(invoiceId);
          invoiceRefs[invoiceId] = invRef;
          invoiceSnaps[invoiceId] = await tx.get(invRef);
        }

        // 2. ESCRITAS ATÔMICAS PARA CARTÃO DE CRÉDITO.
        final addedByInvoice = <String, int>{};
        for (final spec in missingSpecs) {
          final cycle = specCycles[spec.transactionDocId]!;
          final txRef =
              _transactionsCollection(userId).doc(spec.transactionDocId);
          final txEntity = TransactionEntity(
            id: spec.transactionDocId,
            kind: TransactionKind.cardPurchase,
            description: freshRule.description,
            amountCents: freshRule.amountCents,
            categoryId: freshRule.categoryId,
            cardId: card.id,
            invoiceId: cycle.invoiceId,
            recurringId: freshRule.id,
            occurrenceKey: spec.occurrenceKey,
            competencyDate: spec.scheduledDate,
            dueDate: cycle.dueDate,
            status: TransactionStatus.pending,
            notes: freshRule.notes,
            createdAt: now,
            updatedAt: now,
          );
          tx.set(txRef, TransactionModel.toFirestore(txEntity));
          addedByInvoice[cycle.invoiceId] =
              (addedByInvoice[cycle.invoiceId] ?? 0) + freshRule.amountCents;
        }

        for (final entry in addedByInvoice.entries) {
          final invId = entry.key;
          final addedCents = entry.value;
          final invRef = invoiceRefs[invId]!;
          final invSnap = invoiceSnaps[invId]!;
          final cycle = uniqueInvoiceIds[invId]!;

          if (invSnap.exists) {
            final existingInv = InvoiceModel.fromFirestore(invSnap);
            tx.update(invRef, <String, dynamic>{
              'totalAmountCents': existingInv.totalAmountCents + addedCents,
              'updatedAt': FirestoreUtils.toMillisTimestamp(now),
            });
          } else {
            final newInv = InvoiceEntity(
              id: invId,
              cardId: card.id,
              referenceYear: cycle.referenceYear,
              referenceMonth: cycle.referenceMonth,
              closingDate: cycle.closingDate,
              dueDate: cycle.dueDate,
              totalAmountCents: addedCents,
              paidAmountCents: 0,
              status: InvoiceStatus.open,
              createdAt: now,
              updatedAt: now,
            );
            tx.set(invRef, InvoiceModel.toFirestore(newInv));
          }
        }

        tx.update(cardRef, <String, dynamic>{
          'usedLimitCents': card.usedLimitCents +
              (freshRule.amountCents * missingSpecs.length),
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      } else {
        if (freshRule.accountId == null || freshRule.accountId!.isEmpty) {
          return 0;
        }
        final accountRef = _userDoc(userId)
            .collection(FirestoreCollections.accounts)
            .doc(freshRule.accountId!);
        final accountSnap = await tx.get(accountRef);
        if (!accountSnap.exists) return 0;

        // 2. ESCRITAS ATÔMICAS PARA CONTA (RECEITA/DESPESA PREVISTA).
        final txKind = freshRule.kind == RecurringKind.income
            ? TransactionKind.income
            : TransactionKind.expense;

        for (final spec in missingSpecs) {
          final txRef =
              _transactionsCollection(userId).doc(spec.transactionDocId);
          final txEntity = TransactionEntity(
            id: spec.transactionDocId,
            kind: txKind,
            description: freshRule.description,
            amountCents: freshRule.amountCents,
            categoryId: freshRule.categoryId,
            accountId: freshRule.accountId,
            recurringId: freshRule.id,
            occurrenceKey: spec.occurrenceKey,
            competencyDate: spec.scheduledDate,
            dueDate: spec.scheduledDate,
            status: TransactionStatus.pending,
            notes: freshRule.notes,
            createdAt: now,
            updatedAt: now,
          );
          tx.set(txRef, TransactionModel.toFirestore(txEntity));
        }
      }

      tx.update(ruleRef, <String, dynamic>{
        'lastGeneratedKey': missingSpecs.last.occurrenceKey,
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });

      return missingSpecs.length;
    });
  }

  Future<void> updateSingleCardOccurrence({
    required String userId,
    required String transactionId,
    required String description,
    required int amountCents,
    String? notes,
  }) async {
    final txRef = _transactionsCollection(userId).doc(transactionId);
    final now = DateTime.now();

    await _db.runTransaction<void>((tx) async {
      final txSnap = await tx.get(txRef);
      if (!txSnap.exists) {
        throw const ValidationFailure('Ocorrência não encontrada.');
      }
      final existing = TransactionModel.fromFirestore(txSnap);
      if (existing.kind != TransactionKind.cardPurchase ||
          existing.status.isSettled) {
        throw const ValidationFailure(
          'Somente ocorrências em aberto no cartão podem ser ajustadas por aqui.',
        );
      }

      DocumentReference<Map<String, dynamic>>? cardRef;
      DocumentSnapshot<Map<String, dynamic>>? cardSnap;
      if (existing.cardId != null && existing.cardId!.isNotEmpty) {
        cardRef = _userDoc(userId)
            .collection(FirestoreCollections.creditCards)
            .doc(existing.cardId!);
        cardSnap = await tx.get(cardRef);
      }

      DocumentReference<Map<String, dynamic>>? invoiceRef;
      DocumentSnapshot<Map<String, dynamic>>? invoiceSnap;
      if (existing.invoiceId != null && existing.invoiceId!.isNotEmpty) {
        invoiceRef = _userDoc(userId)
            .collection(FirestoreCollections.invoices)
            .doc(existing.invoiceId!);
        invoiceSnap = await tx.get(invoiceRef);
      }

      if (invoiceSnap != null && invoiceSnap.exists) {
        final invoice = InvoiceModel.fromFirestore(invoiceSnap);
        if (invoice.status == InvoiceStatus.paid) {
          throw const ValidationFailure(
            'Não é possível editar ocorrência de uma fatura já paga.',
          );
        }
      }

      final delta = amountCents - existing.amountCents;
      tx.update(txRef, <String, dynamic>{
        'description': description.trim(),
        'amountCents': amountCents,
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });

      if (delta != 0 && invoiceRef != null && invoiceSnap != null && invoiceSnap.exists) {
        final invoice = InvoiceModel.fromFirestore(invoiceSnap);
        final nextTotal = invoice.totalAmountCents + delta;
        tx.update(invoiceRef, <String, dynamic>{
          'totalAmountCents': nextTotal < 0 ? 0 : nextTotal,
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      }

      if (delta != 0 && cardRef != null && cardSnap != null && cardSnap.exists) {
        final card = CreditCardModel.fromFirestore(cardSnap);
        final nextUsed = card.usedLimitCents + delta;
        tx.update(cardRef, <String, dynamic>{
          'usedLimitCents': nextUsed < 0 ? 0 : nextUsed,
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      }
    });
  }
}
