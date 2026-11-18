import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finance_control/core/errors/failures.dart';
import 'package:finance_control/core/errors/firebase_error_mapper.dart';
import 'package:finance_control/core/services/attachment_storage_service.dart';
import 'package:finance_control/core/utils/firestore_utils.dart';
import 'package:finance_control/features/accounts/data/models/account_model.dart';
import 'package:finance_control/features/accounts/domain/entities/account_entity.dart';
import 'package:finance_control/features/authentication/application/providers/auth_providers.dart';
import 'package:finance_control/features/authentication/domain/entities/auth_user.dart';
import 'package:finance_control/features/authentication/domain/repositories/auth_repository.dart';
import 'package:finance_control/features/categories/data/models/category_model.dart';
import 'package:finance_control/features/categories/domain/entities/category_entity.dart';
import 'package:finance_control/features/profile/data/models/user_profile_model.dart';
import 'package:finance_control/features/profile/domain/entities/user_profile.dart';
import 'package:finance_control/features/transactions/application/controllers/transaction_controller.dart';
import 'package:finance_control/features/transactions/application/providers/transaction_providers.dart';
import 'package:finance_control/features/transactions/data/models/transaction_model.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_attachment.dart';
import 'package:finance_control/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finance_control/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo(this._user);

  final AuthUser? _user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);

  @override
  AuthUser? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionRepository implements TransactionRepository {
  Object? errorToThrow;
  TransactionEntity? lastCreated;
  TransactionEntity? lastUpdated;
  List<PickedAttachment> lastNewAttachments = const <PickedAttachment>[];
  List<TransactionAttachment> lastRemovedAttachments =
      const <TransactionAttachment>[];

  @override
  Stream<List<TransactionEntity>> watchTransactions(String userId) {
    return Stream.value(const <TransactionEntity>[]);
  }

  @override
  Future<TransactionEntity> createTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    lastCreated = transaction.copyWith(id: 'tx_1');
    lastNewAttachments = newAttachments;
    return lastCreated!;
  }

  @override
  Future<TransactionEntity> updateTransaction({
    required String userId,
    required TransactionEntity transaction,
    List<PickedAttachment> newAttachments = const <PickedAttachment>[],
    List<TransactionAttachment> removedAttachments =
        const <TransactionAttachment>[],
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    lastUpdated = transaction;
    lastNewAttachments = newAttachments;
    lastRemovedAttachments = removedAttachments;
    return transaction;
  }

  @override
  Future<void> markAsSettled({
    required String userId,
    required String transactionId,
    DateTime? paymentDate,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> deleteTransaction({
    required String userId,
    required TransactionEntity transaction,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
  }
}

void main() {
  group('FirestoreUtils timestamp normalization and preservation', () {
    test('toMillisTimestamp aligns DateTime with microseconds to milliseconds',
        () {
      final raw = DateTime.utc(2026, 11, 18, 1, 3, 15, 540, 613);
      final ts = FirestoreUtils.toMillisTimestamp(raw);

      expect(ts.microsecondsSinceEpoch % 1000, 0);
      expect(ts.millisecondsSinceEpoch, raw.millisecondsSinceEpoch);
      expect(FirestoreUtils.toNullableMillisTimestamp(null), isNull);
    });

    test(
        'withoutCreatedAt removes createdAt from TransactionModel and AccountModel update payloads',
        () {
      final raw = DateTime.utc(2026, 11, 18, 1, 3, 15, 540, 613);
      final txPayload = FirestoreUtils.withoutCreatedAt(
        TransactionModel.toFirestore(
          TransactionEntity(
            id: 'QrU0fkCRQC0hbJpcrcXn',
            kind: TransactionKind.expense,
            description: 'Pães',
            amountCents: 1000,
            competencyDate: raw,
            status: TransactionStatus.paid,
            createdAt: raw,
            updatedAt: raw,
          ),
        ),
      );

      expect(txPayload.containsKey('createdAt'), isFalse);
      expect(txPayload['description'], 'Pães');

      final accountPayload = FirestoreUtils.withoutCreatedAt(
        AccountModel.toFirestore(
          AccountEntity(
            id: 'LaqKgkbflYqToG3NatVT',
            name: 'Corrente',
            institution: 'BB',
            type: AccountType.checking,
            initialBalanceCents: 2304,
            currentBalanceCents: 1304,
            colorHex: '#0F766E',
            iconName: 'account_balance',
            openedAt: raw,
            isActive: true,
            createdAt: raw,
            updatedAt: raw,
          ),
        ),
      );
      expect(accountPayload.containsKey('createdAt'), isFalse);
      expect(accountPayload['name'], 'Corrente');
    });

    test('withoutCreatedAt removes createdAt without mutating original map',
        () {
      final source = <String, dynamic>{
        'name': 'Alimentação',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 18)),
      };
      final sanitized = FirestoreUtils.withoutCreatedAt(source);

      expect(sanitized.containsKey('createdAt'), isFalse);
      expect(sanitized['name'], 'Alimentação');
      expect(source.containsKey('createdAt'), isTrue);
    });

    test('models serialize timestamps aligned to milliseconds', () {
      final raw = DateTime.utc(2026, 11, 18, 1, 3, 15, 540, 613);

      final txMap = TransactionModel.toFirestore(
        TransactionEntity(
          id: 't1',
          kind: TransactionKind.expense,
          description: 'Pães',
          amountCents: 1000,
          competencyDate: raw,
          dueDate: raw,
          paymentDate: raw,
          status: TransactionStatus.paid,
          createdAt: raw,
          updatedAt: raw,
        ),
      );
      expect((txMap['createdAt'] as Timestamp).microsecondsSinceEpoch % 1000, 0);
      expect((txMap['updatedAt'] as Timestamp).microsecondsSinceEpoch % 1000, 0);

      final accountMap = AccountModel.toFirestore(
        AccountEntity(
          id: 'a1',
          name: 'Corrente',
          institution: 'Banco',
          type: AccountType.checking,
          initialBalanceCents: 2304,
          currentBalanceCents: 1304,
          colorHex: '#0F766E',
          iconName: 'account_balance',
          openedAt: raw,
          isActive: true,
          createdAt: raw,
          updatedAt: raw,
        ),
      );
      expect(
        (accountMap['createdAt'] as Timestamp).microsecondsSinceEpoch % 1000,
        0,
      );

      final catMap = CategoryModel.toFirestore(
        CategoryEntity(
          id: 'c1',
          name: 'Mercado',
          description: '',
          type: CategoryType.expense,
          iconName: 'shopping_cart',
          colorHex: '#0F766E',
          isDefault: false,
          isActive: true,
          createdAt: raw,
          updatedAt: raw,
        ),
      );
      expect((catMap['createdAt'] as Timestamp).microsecondsSinceEpoch % 1000, 0);

      final profileMap = UserProfileModel.toFirestore(
        UserProfile(
          uid: 'u1',
          displayName: 'Luiz',
          email: 'luiz.mg.ms@gmail.com',
          createdAt: raw,
          updatedAt: raw,
        ),
      );
      expect(
        (profileMap['createdAt'] as Timestamp).microsecondsSinceEpoch % 1000,
        0,
      );
    });
  });

  group('FirebaseAttachmentStorageService path and filename sanitization', () {
    test('sanitizeFileName collapses consecutive dots and special chars', () {
      expect(
        FirebaseAttachmentStorageService.sanitizeFileName('comprovante..pdf'),
        'comprovante.pdf',
      );
      expect(
        FirebaseAttachmentStorageService.sanitizeFileName('..foto (1).png'),
        'foto__1_.png',
      );
      expect(
        FirebaseAttachmentStorageService.sanitizeFileName('nota...fiscal.JPG'),
        'nota.fiscal.JPG',
      );
      expect(
        FirebaseAttachmentStorageService.sanitizeFileName('   '),
        'comprovante',
      );
    });

    test('buildTransactionAttachmentPath complies with Firestore rule limits',
        () {
      final veryLongName = '${'comprovante..'.padRight(500, 'a')}.pdf';
      final path = FirebaseAttachmentStorageService.buildTransactionAttachmentPath(
        userId: 'KREfZNj4PyO4KjKgAsyXgJjI6vp1',
        transactionId: 'QrU0fkCRQC0hbJpcrcXn',
        attachmentId: '123e4567-e89b-12d3-a456-426614174000',
        fileName: veryLongName,
      );

      expect(path.startsWith('users/KREfZNj4PyO4KjKgAsyXgJjI6vp1/'), isTrue);
      expect(path.contains('..'), isFalse);
      expect(path.length, lessThanOrEqualTo(512));
      expect(path.endsWith('.pdf'), isTrue);
    });

    test('normalizeAttachmentName keeps filename within 255 chars and keeps ext',
        () {
      final longName = '${'recibo_'.padRight(300, 'x')}.pdf';
      final normalized =
          FirebaseAttachmentStorageService.normalizeAttachmentName(longName);

      expect(normalized.length, lessThanOrEqualTo(255));
      expect(normalized.endsWith('.pdf'), isTrue);
    });

    test('buildTransactionAttachmentPath rejects path traversal in segments',
        () {
      expect(
        () => FirebaseAttachmentStorageService.buildTransactionAttachmentPath(
          userId: '../evil',
          transactionId: 'tx1',
          attachmentId: 'att1',
          fileName: 'ok.pdf',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('Firebase error mapper and TransactionController', () {
    test('mapFirebaseFailure produces clear domain failures', () {
      final permissionDenied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      final mappedPerm = mapFirebaseFailure(
        permissionDenied,
        fallbackMessage: 'Erro',
      );
      expect(mappedPerm, isA<ValidationFailure>());
      expect(mappedPerm.message, contains('permission-denied'));

      final storageUnauthorized = FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
      );
      final mappedStorage = mapFirebaseFailure(
        storageUnauthorized,
        fallbackMessage: 'Erro',
      );
      expect(mappedStorage, isA<StorageFailure>());
      expect(mappedStorage.code, 'unauthorized');
    });

    test('TransactionController exposes StorageFailure and unexpected errors',
        () async {
      final fakeRepo = _FakeTransactionRepository();
      const user = AuthUser(
        uid: 'KREfZNj4PyO4KjKgAsyXgJjI6vp1',
        email: 'luiz.mg.ms@gmail.com',
        displayName: 'Luiz',
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepo(user)),
          currentAuthUserProvider.overrideWithValue(user),
          transactionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final attachment = PickedAttachment(
        id: 'att-1',
        name: 'comprovante.png',
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        contentType: 'image/png',
      );

      fakeRepo.errorToThrow = const StorageFailure(
        'Sem permissão para acessar ou enviar o anexo no Firebase Storage.',
        code: 'unauthorized',
      );

      final ctrl = container.read(transactionControllerProvider.notifier);
      final failedStorage = await ctrl.saveTransaction(
        kind: TransactionKind.expense,
        description: 'Pães',
        amountCents: 1000,
        categoryId: 'cat_food',
        accountId: 'acc_1',
        competencyDate: DateTime(2026, 11, 18),
        status: TransactionStatus.paid,
        newAttachments: <PickedAttachment>[attachment],
      );
      expect(failedStorage, isFalse);
      expect(
        container.read(transactionControllerProvider).errorMessage,
        contains('Firebase Storage'),
      );

      fakeRepo.errorToThrow = StateError('storage js interop boom');
      final failedUnexpected = await ctrl.saveTransaction(
        kind: TransactionKind.expense,
        description: 'Pães',
        amountCents: 1000,
        categoryId: 'cat_food',
        accountId: 'acc_1',
        competencyDate: DateTime(2026, 11, 18),
        status: TransactionStatus.paid,
        newAttachments: <PickedAttachment>[attachment],
      );
      expect(failedUnexpected, isFalse);
      expect(
        container.read(transactionControllerProvider).errorMessage,
        contains('storage js interop boom'),
      );

      fakeRepo.errorToThrow = null;
      final existing = TransactionEntity(
        id: 'QrU0fkCRQC0hbJpcrcXn',
        kind: TransactionKind.expense,
        description: 'Pães',
        amountCents: 1000,
        categoryId: 'cat_food',
        accountId: 'LaqKgkbflYqToG3NatVT',
        competencyDate: DateTime(2026, 11, 18),
        paymentDate: DateTime(2026, 11, 18),
        status: TransactionStatus.paid,
        createdAt: DateTime.utc(2026, 11, 18, 1, 3, 15, 540),
        updatedAt: DateTime.utc(2026, 11, 18, 1, 3, 15, 540),
      );
      final okEdit = await ctrl.saveTransaction(
        existing: existing,
        kind: TransactionKind.expense,
        description: 'Pães',
        amountCents: 1000,
        categoryId: 'cat_food',
        accountId: 'LaqKgkbflYqToG3NatVT',
        competencyDate: DateTime(2026, 11, 18),
        paymentDate: DateTime(2026, 11, 18),
        status: TransactionStatus.paid,
        newAttachments: <PickedAttachment>[attachment],
      );
      expect(okEdit, isTrue);
      expect(fakeRepo.lastUpdated?.id, 'QrU0fkCRQC0hbJpcrcXn');
      expect(fakeRepo.lastNewAttachments, hasLength(1));
    });
  });
}
