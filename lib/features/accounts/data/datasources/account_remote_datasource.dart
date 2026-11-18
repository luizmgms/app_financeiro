import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/account_entity.dart';
import '../models/account_model.dart';

/// Fonte de dados Firestore para contas financeiras e transferências atômicas.
class AccountRemoteDatasource {
  AccountRemoteDatasource({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore? _firestore;
  final Uuid _uuid;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _accountsCollection(String userId) {
    return _userDoc(userId).collection(FirestoreCollections.accounts);
  }

  CollectionReference<Map<String, dynamic>> _transactionsCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.transactions);
  }

  Stream<List<AccountEntity>> watchAccounts(String userId) {
    return _accountsCollection(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map(AccountModel.fromFirestore)
          .toList(growable: false);
      final sorted = List<AccountEntity>.of(list)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    });
  }

  Future<AccountEntity> createAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    final docRef = _accountsCollection(userId).doc();
    final now = DateTime.now();
    final toSave = account.copyWith(
      id: docRef.id,
      currentBalanceCents: account.initialBalanceCents,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(AccountModel.toFirestore(toSave));
    return toSave;
  }

  Future<void> updateAccount({
    required String userId,
    required AccountEntity account,
  }) async {
    final docRef = _accountsCollection(userId).doc(account.id);
    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) {
        throw const ValidationFailure('Conta não encontrada.');
      }

      final current = AccountModel.fromFirestore(snapshot);
      final initialDelta =
          account.initialBalanceCents - current.initialBalanceCents;
      final updated = account.copyWith(
        currentBalanceCents: current.currentBalanceCents + initialDelta,
        updatedAt: DateTime.now(),
      );
      final payload = FirestoreUtils.withoutCreatedAt(
        AccountModel.toFirestore(updated),
      );
      tx.update(docRef, payload);
    });
  }

  Future<void> setArchived({
    required String userId,
    required String accountId,
    required bool archived,
  }) async {
    await _accountsCollection(userId).doc(accountId).update(<String, dynamic>{
      'isActive': !archived,
      'updatedAt': FirestoreUtils.toMillisTimestamp(DateTime.now()),
    });
  }

  Future<void> deleteAccount({
    required String userId,
    required String accountId,
  }) async {
    final txCol = _transactionsCollection(userId);
    final asSource =
        await txCol.where('accountId', isEqualTo: accountId).limit(1).get();
    final asDestination = await txCol
        .where('destinationAccountId', isEqualTo: accountId)
        .limit(1)
        .get();

    if (asSource.docs.isNotEmpty || asDestination.docs.isNotEmpty) {
      throw const ValidationFailure(
        'Esta conta possui movimentações no extrato. Arquive-a para preservar o histórico financeiro.',
      );
    }

    await _accountsCollection(userId).doc(accountId).delete();
  }

  Future<void> transferBetweenAccounts({
    required String userId,
    required String sourceAccountId,
    required String destinationAccountId,
    required int amountCents,
    required DateTime transferDate,
    required String description,
    String? notes,
  }) async {
    if (sourceAccountId == destinationAccountId) {
      throw const ValidationFailure(
        'Selecione contas diferentes de origem e destino.',
      );
    }
    if (amountCents <= 0) {
      throw const ValidationFailure(
        'Informe um valor maior que zero para a transferência.',
      );
    }

    final sourceRef = _accountsCollection(userId).doc(sourceAccountId);
    final destRef = _accountsCollection(userId).doc(destinationAccountId);
    final outTxRef = _transactionsCollection(userId).doc();
    final inTxRef = _transactionsCollection(userId).doc();

    await _db.runTransaction((tx) async {
      final sourceSnap = await tx.get(sourceRef);
      final destSnap = await tx.get(destRef);

      if (!sourceSnap.exists || !destSnap.exists) {
        throw const ValidationFailure(
          'Conta de origem ou destino não encontrada.',
        );
      }

      final sourceAccount = AccountModel.fromFirestore(sourceSnap);
      final destAccount = AccountModel.fromFirestore(destSnap);

      if (!sourceAccount.isActive || !destAccount.isActive) {
        throw const ValidationFailure(
          'Apenas contas ativas podem participar de transferências.',
        );
      }

      final now = DateTime.now();
      final transferGroupId = _uuid.v4();
      final trimmedDescription = description.trim();
      final outDescription = trimmedDescription.isNotEmpty
          ? trimmedDescription
          : 'Transferência para ${destAccount.name}';
      final inDescription = trimmedDescription.isNotEmpty
          ? trimmedDescription
          : 'Transferência de ${sourceAccount.name}';

      final outflowTx = TransactionEntity(
        id: outTxRef.id,
        kind: TransactionKind.transfer,
        description: outDescription,
        amountCents: amountCents,
        accountId: sourceAccount.id,
        destinationAccountId: destAccount.id,
        transferGroupId: transferGroupId,
        transferDirection: TransferDirection.outflow,
        competencyDate: transferDate,
        paymentDate: transferDate,
        status: TransactionStatus.completed,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      final inflowTx = TransactionEntity(
        id: inTxRef.id,
        kind: TransactionKind.transfer,
        description: inDescription,
        amountCents: amountCents,
        accountId: destAccount.id,
        destinationAccountId: sourceAccount.id,
        transferGroupId: transferGroupId,
        transferDirection: TransferDirection.inflow,
        competencyDate: transferDate,
        paymentDate: transferDate,
        status: TransactionStatus.completed,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      tx.set(outTxRef, TransactionModel.toFirestore(outflowTx));
      tx.set(inTxRef, TransactionModel.toFirestore(inflowTx));
      tx.update(sourceRef, <String, dynamic>{
        'currentBalanceCents': sourceAccount.currentBalanceCents - amountCents,
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });
      tx.update(destRef, <String, dynamic>{
        'currentBalanceCents': destAccount.currentBalanceCents + amountCents,
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });
    });
  }
}
