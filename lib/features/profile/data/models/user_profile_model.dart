import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/user_profile.dart';

/// Modelo de serialização Firestore para [UserProfile].
class UserProfileModel {
  const UserProfileModel._();

  static UserProfile fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];

    return UserProfile(
      uid: (data['uid'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? 'Usuário',
      email: (data['email'] as String?) ?? '',
      photoUrl: data['photoUrl'] as String?,
      defaultCurrency:
          (data['defaultCurrency'] as String?) ?? AppConstants.defaultCurrency,
      localeCode: (data['localeCode'] as String?) ?? AppConstants.defaultLocale,
      monthStartDay: ((data['monthStartDay'] as num?)?.toInt() ?? 1).clamp(1, 28),
      reminderDaysBefore:
          ((data['reminderDaysBefore'] as num?)?.toInt() ?? 3).clamp(1, 30),
      notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
      pushNotificationsEnabled:
          (data['pushNotificationsEnabled'] as bool?) ?? false,
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : now,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : now,
    );
  }

  static Map<String, dynamic> toFirestore(UserProfile profile) {
    return {
      'uid': profile.uid,
      'displayName': profile.displayName.trim(),
      'email': profile.email.trim(),
      'photoUrl': profile.photoUrl,
      'defaultCurrency': profile.defaultCurrency,
      'localeCode': profile.localeCode,
      'monthStartDay': profile.monthStartDay.clamp(1, 28),
      'reminderDaysBefore': profile.reminderDaysBefore.clamp(1, 30),
      'notificationsEnabled': profile.notificationsEnabled,
      'pushNotificationsEnabled': profile.pushNotificationsEnabled,
      'createdAt': FirestoreUtils.toMillisTimestamp(profile.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(profile.updatedAt),
    };
  }
}
