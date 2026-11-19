import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/app_notification_entity.dart';

/// Serializador Cloud Firestore para [AppNotificationEntity].
class AppNotificationModel {
  const AppNotificationModel._();

  static AppNotificationEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return AppNotificationEntity(
      id: snapshot.id,
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      type: NotificationType.fromStorage(data['type'] as String?),
      referenceId: data['referenceId'] as String?,
      scheduledFor: _parseDate(data['scheduledFor']) ?? now,
      isRead: (data['isRead'] as bool?) ?? false,
      isCustom: (data['isCustom'] as bool?) ?? false,
      createdAt: _parseDate(data['createdAt']) ?? now,
      updatedAt: _parseDate(data['updatedAt']) ?? now,
    );
  }

  static Map<String, dynamic> toFirestore(AppNotificationEntity item) {
    return <String, dynamic>{
      'title': item.title.trim(),
      'body': item.body.trim(),
      'type': item.type.storageValue,
      'referenceId': item.referenceId,
      'scheduledFor': FirestoreUtils.toMillisTimestamp(item.scheduledFor),
      'isRead': item.isRead,
      'isCustom': item.isCustom,
      'createdAt': FirestoreUtils.toMillisTimestamp(item.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(item.updatedAt),
    };
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
