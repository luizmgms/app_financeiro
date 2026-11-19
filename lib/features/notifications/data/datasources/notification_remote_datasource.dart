import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../models/app_notification_model.dart';

/// Fonte de dados remota para notificações, lembretes e tokens FCM.
class NotificationRemoteDatasource {
  NotificationRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _db.collection(FirestoreCollections.users).doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _notificationsCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.notifications);
  }

  CollectionReference<Map<String, dynamic>> _devicesCollection(
    String userId,
  ) {
    return _userDoc(userId).collection(FirestoreCollections.notificationDevices);
  }

  Stream<List<AppNotificationEntity>> watchNotifications(String userId) {
    if (_firestore == null && Firebase.apps.isEmpty) {
      return Stream.value(const <AppNotificationEntity>[]);
    }
    return _notificationsCollection(userId)
        .orderBy('scheduledFor', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AppNotificationModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<int> syncSystemAlerts({
    required String userId,
    required List<AppNotificationEntity> candidates,
  }) async {
    if (candidates.isEmpty) return 0;

    final capped = candidates.take(40).toList(growable: false);
    final now = DateTime.now();

    return _db.runTransaction<int>((tx) async {
      final toCreate = <AppNotificationEntity>[];
      for (final item in capped) {
        final ref = _notificationsCollection(userId).doc(item.id);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          toCreate.add(item);
        }
      }

      for (final item in toCreate) {
        final ref = _notificationsCollection(userId).doc(item.id);
        final entity = item.copyWith(createdAt: now, updatedAt: now);
        tx.set(ref, AppNotificationModel.toFirestore(entity));
      }

      return toCreate.length;
    });
  }

  Future<AppNotificationEntity> createCustomReminder({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? referenceId,
  }) async {
    final now = DateTime.now();
    final ref = _notificationsCollection(userId).doc();
    final entity = AppNotificationEntity(
      id: ref.id,
      title: title.trim(),
      body: body.trim(),
      type: NotificationType.customReminder,
      referenceId: referenceId,
      scheduledFor: scheduledFor,
      isRead: false,
      isCustom: true,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(AppNotificationModel.toFirestore(entity));
    return entity;
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
    required bool isRead,
  }) async {
    final now = DateTime.now();
    await _notificationsCollection(userId).doc(notificationId).update({
      'isRead': isRead,
      'updatedAt': FirestoreUtils.toMillisTimestamp(now),
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _notificationsCollection(userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;

    final now = FirestoreUtils.toMillisTimestamp(DateTime.now());
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'updatedAt': now,
      });
    }
    await batch.commit();
  }

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    await _notificationsCollection(userId).doc(notificationId).delete();
  }

  Future<void> registerDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    final deviceId = _deterministicDeviceId(token);
    final ref = _devicesCollection(userId).doc(deviceId);
    final now = DateTime.now();
    final snap = await ref.get();

    if (snap.exists) {
      await ref.update({
        'token': token,
        'platform': platform,
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });
    } else {
      await ref.set({
        'token': token,
        'platform': platform,
        'createdAt': FirestoreUtils.toMillisTimestamp(now),
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      });
    }
  }

  static String _deterministicDeviceId(String token) {
    var hash = 0;
    for (final unit in token.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return 'fcm_${hash}_${token.length}';
  }
}
