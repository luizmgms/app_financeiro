import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/attachment_storage_service.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../../accounts/data/models/account_model.dart';
import '../../../credit_cards/data/models/credit_card_model.dart';
import '../../../credit_cards/data/models/invoice_model.dart';
import '../../../credit_cards/domain/entities/invoice_entity.dart';
import '../../domain/entities/transaction_attachment.dart';
import '../../domain/entities/transaction_entity.dart';
import '../models/transaction_model.dart';

/// Fonte de dados Firestore/Storage para movimentações com atualizações atômicas de saldo.
class TransactionRemoteDatasource {
  TransactionRemoteDatasource({
    FirebaseFirestore? firestore,
    required AttachmentStorageService attachmentStorage,
  })  : _firestore = firestore,
        _attachmentStorage = attachmentStorage;

  final FirebaseFirestore? _firestore;
  final AttachmentStorageService _attachmentStorage;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _transactionsCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.transactions);
  }

  DocumentReference<Map<String, dynamic>> _accountDoc(
    String userId,
    String accountId,
  ) {
    return _userDoc(userId)
        .collection(FirestoreCollections.accounts)
        .doc(accountId);
  }

  Stream<List<TransactionEntity>> watchTransactions(String userId) {
    return _transactionsCollection(userId)
        .orderBy('competencyDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map(TransactionModel.fromFirestore)
          .toList(growable: false);
      final sorted = List<TransactionEntity>.of(list)
        ..sort((a, b) {
          final byDate = b.competencyDate.compareTo(a.competencyDate);
          if (byDate != 0) return byDate;
          return b.createdAt.compareTo(a.createdAt);
        });
      return sorted;
    });
  }

  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  }) async {
    final docRef = _transactionsCollection(userId).doc();
    final uploaded = await _uploadAttachments(
      userId: userId,
      transactionId: docRef.id,
      files: newAttachments,
    );

    final now = DateTime.now();
    final toSave = transaction.copyWith(
      id: docRef.id,
      attachments: <TransactionAttachment>[
        ...transaction.attachments,
        ...uploaded,
      ],
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _db.runTransaction((tx) async {
        final accountId = toSave.accountId;
        final delta = accountId == null
            ? 0
            : toSave.signedBalanceDeltaForAccount(accountId);

        DocumentSnapshot<Map<String, dynamic>>? accountSnap;
        DocumentReference<Map<String, dynamic>>? accountRef;
        if (accountId != null && delta != 0) {
          accountRef = _accountDoc(userId, accountId);
          accountSnap = await tx.get(accountRef);
          if (!accountSnap.exists) {
            throw const ValidationFailure('Conta selecionada não encontrada.');
          }
        }

        tx.set(docRef, TransactionModel.toFirestore(toSave));
        if (accountRef != null && accountSnap != null) {
          final account = AccountModel.fromFirestore(accountSnap);
          tx.update(accountRef, <String, dynamic>{
            'currentBalanceCents': account.currentBalanceCents + delta,
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }
      });
      return toSave;
    } catch (_) {
      await _cleanupUploaded(uploaded);
      rethrow;
    }
  }

  Future<TransactionEntity> updateTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
    List<TransactionAttachment> removedAttachments =
        const <TransactionAttachment>[],
  }) async {
    final uploaded = await _uploadAttachments(
      userId: userId,
      transactionId: transaction.id,
      files: newAttachments,
    );

    final removedIds = removedAttachments.map((item) => item.id).toSet();
    final mergedAttachments = <TransactionAttachment>[
      for (final existing in transaction.attachments)
        if (!removedIds.contains(existing.id)) existing,
      ...uploaded,
    ];

    final now = DateTime.now();
    final toSave = transaction.copyWith(
      attachments: mergedAttachments,
      updatedAt: now,
    );
    final docRef = _transactionsCollection(userId).doc(transaction.id);

    try {
      await _db.runTransaction((tx) async {
        final existingSnap = await tx.get(docRef);
        if (!existingSnap.exists) {
          throw const ValidationFailure('Movimentação não encontrada.');
        }

        final oldTx = TransactionModel.fromFirestore(existingSnap);
        final oldAccountId = oldTx.accountId;
        final newAccountId = toSave.accountId;

        final oldDelta = oldAccountId == null
            ? 0
            : oldTx.signedBalanceDeltaForAccount(oldAccountId);
        final newDelta = newAccountId == null
            ? 0
            : toSave.signedBalanceDeltaForAccount(newAccountId);

        if (oldAccountId != null && oldAccountId == newAccountId) {
          final netDelta = newDelta - oldDelta;
          DocumentReference<Map<String, dynamic>>? accountRef;
          DocumentSnapshot<Map<String, dynamic>>? accountSnap;
          if (netDelta != 0) {
            accountRef = _accountDoc(userId, oldAccountId);
            accountSnap = await tx.get(accountRef);
            if (!accountSnap.exists) {
              throw const ValidationFailure('Conta vinculada não encontrada.');
            }
          }

          final updatePayload = FirestoreUtils.withoutCreatedAt(
            TransactionModel.toFirestore(toSave),
          );
          tx.update(docRef, updatePayload);
          if (accountRef != null && accountSnap != null) {
            final account = AccountModel.fromFirestore(accountSnap);
            tx.update(accountRef, <String, dynamic>{
              'currentBalanceCents': account.currentBalanceCents + netDelta,
              'updatedAt': FirestoreUtils.toMillisTimestamp(now),
            });
          }
          return;
        }

        DocumentReference<Map<String, dynamic>>? oldRef;
        DocumentSnapshot<Map<String, dynamic>>? oldSnap;
        if (oldAccountId != null && oldDelta != 0) {
          oldRef = _accountDoc(userId, oldAccountId);
          oldSnap = await tx.get(oldRef);
        }

        DocumentReference<Map<String, dynamic>>? newRef;
        DocumentSnapshot<Map<String, dynamic>>? newSnap;
        if (newAccountId != null && newDelta != 0) {
          newRef = _accountDoc(userId, newAccountId);
          newSnap = await tx.get(newRef);
          if (!newSnap.exists) {
            throw const ValidationFailure('Nova conta selecionada não encontrada.');
          }
        }

        final updatePayload = FirestoreUtils.withoutCreatedAt(
          TransactionModel.toFirestore(toSave),
        );
        tx.update(docRef, updatePayload);

        if (oldRef != null && oldSnap != null && oldSnap.exists) {
          final oldAccount = AccountModel.fromFirestore(oldSnap);
          tx.update(oldRef, <String, dynamic>{
            'currentBalanceCents': oldAccount.currentBalanceCents - oldDelta,
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }
        if (newRef != null && newSnap != null && newSnap.exists) {
          final newAccount = AccountModel.fromFirestore(newSnap);
          tx.update(newRef, <String, dynamic>{
            'currentBalanceCents': newAccount.currentBalanceCents + newDelta,
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }
      });

      await _cleanupUploaded(removedAttachments);
      return toSave;
    } catch (_) {
      await _cleanupUploaded(uploaded);
      rethrow;
    }
  }

  Future<void> markAsSettled({
    required String userId,
    required String transactionId,
    DateTime? paymentDate,
  }) async {
    final docRef = _transactionsCollection(userId).doc(transactionId);
    final now = DateTime.now();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw const ValidationFailure('Movimentação não encontrada.');
      }

      final existing = TransactionModel.fromFirestore(snap);
      if (existing.status.isSettled) return;
      if (existing.kind != TransactionKind.income &&
          existing.kind != TransactionKind.expense) {
        return;
      }

      final targetStatus = existing.kind == TransactionKind.income
          ? TransactionStatus.received
          : TransactionStatus.paid;

      final updated = existing.copyWith(
        status: targetStatus,
        paymentDate: paymentDate ?? now,
        updatedAt: now,
      );

      final accountId = updated.accountId;
      final delta = accountId == null
          ? 0
          : updated.signedBalanceDeltaForAccount(accountId);

      DocumentReference<Map<String, dynamic>>? accountRef;
      DocumentSnapshot<Map<String, dynamic>>? accountSnap;
      if (accountId != null && delta != 0) {
        accountRef = _accountDoc(userId, accountId);
        accountSnap = await tx.get(accountRef);
      }

      final settlePayload = FirestoreUtils.withoutCreatedAt(
        TransactionModel.toFirestore(updated),
      );
      tx.update(docRef, settlePayload);
      if (accountRef != null && accountSnap != null && accountSnap.exists) {
        final account = AccountModel.fromFirestore(accountSnap);
        tx.update(accountRef, <String, dynamic>{
          'currentBalanceCents': account.currentBalanceCents + delta,
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      }
    });
  }

  Future<void> deleteTransaction({
    required String userId,
    required TransactionEntity transaction,
  }) async {
    if (transaction.kind == TransactionKind.transfer &&
        transaction.transferGroupId != null &&
        transaction.transferGroupId!.isNotEmpty) {
      await _deleteLinkedTransfer(
        userId: userId,
        transferGroupId: transaction.transferGroupId!,
      );
      return;
    }

    final docRef = _transactionsCollection(userId).doc(transaction.id);
    List<TransactionAttachment> attachmentsToDelete =
        const <TransactionAttachment>[];

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final existing = TransactionModel.fromFirestore(snap);
      if (existing.kind == TransactionKind.invoicePayment) {
        throw const ValidationFailure(
          'Pagamentos de fatura consolidados não podem ser excluídos diretamente.',
        );
      }

      attachmentsToDelete = existing.attachments;
      final now = DateTime.now();

      DocumentReference<Map<String, dynamic>>? recurringRef;
      DocumentSnapshot<Map<String, dynamic>>? recurringSnap;
      if (existing.recurringId != null &&
          existing.recurringId!.isNotEmpty &&
          existing.occurrenceKey != null &&
          existing.occurrenceKey!.isNotEmpty) {
        recurringRef = _userDoc(userId)
            .collection(FirestoreCollections.recurring)
            .doc(existing.recurringId!);
        recurringSnap = await tx.get(recurringRef);
      }

      void recordSkippedOccurrenceIfNeeded() {
        if (recurringRef == null ||
            recurringSnap == null ||
            !recurringSnap.exists) {
          return;
        }
        final occKey = existing.occurrenceKey!;
        final rawSkipped =
            recurringSnap.data()?['skippedOccurrenceKeys'] as List<dynamic>?;
        final current = rawSkipped?.whereType<String>().toList() ?? <String>[];
        if (!current.contains(occKey)) {
          current.add(occKey);
        }
        final trimmed = current.length > 200
            ? current.sublist(current.length - 200)
            : current;
        tx.update(recurringRef, <String, dynamic>{
          'skippedOccurrenceKeys': trimmed,
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      }

      if (existing.kind == TransactionKind.cardPurchase ||
          existing.kind == TransactionKind.cardRefund) {
        final isRefund = existing.kind == TransactionKind.cardRefund;
        if (existing.status.isSettled) {
          throw const ValidationFailure(
            'Não é possível excluir um lançamento de uma fatura já paga.',
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

        tx.delete(docRef);
        recordSkippedOccurrenceIfNeeded();

        if (invoiceRef != null && invoiceSnap != null && invoiceSnap.exists) {
          final invoice = InvoiceModel.fromFirestore(invoiceSnap);
          if (invoice.status == InvoiceStatus.paid) {
            throw const ValidationFailure(
              'Não é possível excluir um lançamento de uma fatura já paga.',
            );
          }
          final nextTotal = isRefund
              ? invoice.totalAmountCents + existing.amountCents
              : invoice.totalAmountCents - existing.amountCents;
          tx.update(invoiceRef, <String, dynamic>{
            'totalAmountCents': nextTotal < 0 ? 0 : nextTotal,
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }

        if (cardRef != null && cardSnap != null && cardSnap.exists) {
          final card = CreditCardModel.fromFirestore(cardSnap);
          final nextUsed = isRefund
              ? card.usedLimitCents + existing.amountCents
              : card.usedLimitCents - existing.amountCents;
          tx.update(cardRef, <String, dynamic>{
            'usedLimitCents': nextUsed < 0 ? 0 : nextUsed,
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }
        return;
      }

      final accountId = existing.accountId;
      final delta = accountId == null
          ? 0
          : existing.signedBalanceDeltaForAccount(accountId);

      DocumentReference<Map<String, dynamic>>? accountRef;
      DocumentSnapshot<Map<String, dynamic>>? accountSnap;
      if (accountId != null && delta != 0) {
        accountRef = _accountDoc(userId, accountId);
        accountSnap = await tx.get(accountRef);
      }

      tx.delete(docRef);
      recordSkippedOccurrenceIfNeeded();
      if (accountRef != null && accountSnap != null && accountSnap.exists) {
        final account = AccountModel.fromFirestore(accountSnap);
        tx.update(accountRef, <String, dynamic>{
          'currentBalanceCents': account.currentBalanceCents - delta,
          'updatedAt': FirestoreUtils.toMillisTimestamp(now),
        });
      }
    });

    await _cleanupUploaded(attachmentsToDelete);
  }

  Future<void> _deleteLinkedTransfer({
    required String userId,
    required String transferGroupId,
  }) async {
    final pairQuery = await _transactionsCollection(userId)
        .where('transferGroupId', isEqualTo: transferGroupId)
        .get();
    if (pairQuery.docs.isEmpty) return;

    final now = DateTime.now();
    await _db.runTransaction((tx) async {
      final legs = <TransactionEntity>[];
      final legRefs = <DocumentReference<Map<String, dynamic>>>[];

      for (final doc in pairQuery.docs) {
        final snap = await tx.get(doc.reference);
        if (snap.exists) {
          legs.add(TransactionModel.fromFirestore(snap));
          legRefs.add(doc.reference);
        }
      }

      final accountReversals = <String, int>{};
      for (final leg in legs) {
        final accountId = leg.accountId;
        if (accountId == null) continue;
        final delta = leg.signedBalanceDeltaForAccount(accountId);
        if (delta != 0) {
          accountReversals[accountId] =
              (accountReversals[accountId] ?? 0) - delta;
        }
      }

      final accountSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final accountId in accountReversals.keys) {
        accountSnaps[accountId] = await tx.get(_accountDoc(userId, accountId));
      }

      for (final ref in legRefs) {
        tx.delete(ref);
      }

      for (final entry in accountReversals.entries) {
        final snap = accountSnaps[entry.key];
        if (snap != null && snap.exists) {
          final account = AccountModel.fromFirestore(snap);
          tx.update(snap.reference, <String, dynamic>{
            'currentBalanceCents': account.currentBalanceCents + entry.value,
            'updatedAt': FirestoreUtils.toMillisTimestamp(now),
          });
        }
      }
    });
  }

  Future<List<TransactionAttachment>> _uploadAttachments({
    required String userId,
    required String transactionId,
    required List<PickedAttachment> files,
  }) async {
    if (files.isEmpty) return const <TransactionAttachment>[];

    final uploaded = <TransactionAttachment>[];
    try {
      for (final file in files) {
        final saved = await _attachmentStorage.uploadTransactionAttachment(
          userId: userId,
          transactionId: transactionId,
          attachment: file,
        );
        uploaded.add(saved);
      }
      return uploaded;
    } catch (_) {
      await _cleanupUploaded(uploaded);
      rethrow;
    }
  }

  Future<void> _cleanupUploaded(
    List<TransactionAttachment> attachments,
  ) async {
    for (final item in attachments) {
      try {
        await _attachmentStorage.deleteAttachmentByPath(item.storagePath);
      } catch (_) {
        // Limpeza em melhor esforço para não mascarar erro ou rollback já efetuado.
      }
    }
  }
}
