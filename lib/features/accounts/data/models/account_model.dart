import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/account_entity.dart';

/// Modelo de serialização Firestore para [AccountEntity].
class AccountModel {
  const AccountModel._();

  static AccountEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();
    final openedRaw = data['openedAt'];
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];

    return AccountEntity(
      id: snapshot.id,
      name: (data['name'] as String?) ?? 'Conta',
      institution: (data['institution'] as String?) ?? '',
      type: AccountType.fromStorage(data['type'] as String?),
      initialBalanceCents: (data['initialBalanceCents'] as num?)?.toInt() ?? 0,
      currentBalanceCents: (data['currentBalanceCents'] as num?)?.toInt() ?? 0,
      colorHex: (data['colorHex'] as String?) ?? '#0F766E',
      iconName: (data['iconName'] as String?) ?? 'account_balance',
      openedAt: openedRaw is Timestamp ? openedRaw.toDate() : now,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : now,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : now,
    );
  }

  static Map<String, dynamic> toFirestore(AccountEntity account) {
    return <String, dynamic>{
      'name': account.name.trim(),
      'institution': account.institution.trim(),
      'type': account.type.storageValue,
      'initialBalanceCents': account.initialBalanceCents,
      'currentBalanceCents': account.currentBalanceCents,
      'colorHex': account.colorHex,
      'iconName': account.iconName,
      'openedAt': FirestoreUtils.toMillisTimestamp(account.openedAt),
      'isActive': account.isActive,
      'createdAt': FirestoreUtils.toMillisTimestamp(account.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(account.updatedAt),
    };
  }
}
