import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/credit_card_entity.dart';

/// Modelo de serialização Firestore para [CreditCardEntity].
class CreditCardModel {
  const CreditCardModel._();

  static CreditCardEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];

    return CreditCardEntity(
      id: snapshot.id,
      name: (data['name'] as String?) ?? 'Cartão',
      institution: (data['institution'] as String?) ?? '',
      brand: CardBrand.fromStorage(data['brand'] as String?),
      totalLimitCents: (data['totalLimitCents'] as num?)?.toInt() ?? 0,
      usedLimitCents: (data['usedLimitCents'] as num?)?.toInt() ?? 0,
      closingDay: ((data['closingDay'] as num?)?.toInt() ?? 1).clamp(1, 31),
      dueDay: ((data['dueDay'] as num?)?.toInt() ?? 10).clamp(1, 31),
      paymentAccountId: data['paymentAccountId'] as String?,
      colorHex: (data['colorHex'] as String?) ?? '#7C3AED',
      defaultInstallments:
          ((data['defaultInstallments'] as num?)?.toInt() ?? 1).clamp(1, 48),
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : now,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : now,
    );
  }

  static Map<String, dynamic> toFirestore(CreditCardEntity card) {
    return <String, dynamic>{
      'name': card.name.trim(),
      'institution': card.institution.trim(),
      'brand': card.brand.storageValue,
      'totalLimitCents': card.totalLimitCents,
      'usedLimitCents': card.usedLimitCents,
      'closingDay': card.closingDay.clamp(1, 31),
      'dueDay': card.dueDay.clamp(1, 31),
      'paymentAccountId': card.paymentAccountId,
      'colorHex': card.colorHex,
      'defaultInstallments': card.defaultInstallments.clamp(1, 48),
      'isActive': card.isActive,
      'createdAt': FirestoreUtils.toMillisTimestamp(card.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(card.updatedAt),
    };
  }
}
