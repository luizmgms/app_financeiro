import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../../authentication/domain/entities/auth_user.dart';
import '../../domain/entities/user_profile.dart';
import '../models/user_profile_model.dart';

/// Acesso remoto ao documento de perfil e exclusão de subcoleções do usuário.
class ProfileRemoteDatasource {
  ProfileRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  static const String mainProfileDocId = 'main';

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection(FirestoreCollections.profile)
        .doc(mainProfileDocId);
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _profileDoc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserProfileModel.fromFirestore(snapshot);
    });
  }

  Future<UserProfile> ensureProfile({required AuthUser user}) async {
    final docRef = _profileDoc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      return UserProfileModel.fromFirestore(snapshot);
    }

    final now = DateTime.now();
    final profile = UserProfile(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoUrl,
      defaultCurrency: AppConstants.defaultCurrency,
      localeCode: AppConstants.defaultLocale,
      monthStartDay: AppConstants.defaultMonthStartDay,
      createdAt: now,
      updatedAt: now,
    );

    final userRootDoc = _db.collection(FirestoreCollections.users).doc(user.uid);
    final batch = _db.batch();
    batch.set(
      userRootDoc,
      {
        'uid': user.uid,
        'email': user.email,
        'createdAt': FirestoreUtils.toMillisTimestamp(now),
        'updatedAt': FirestoreUtils.toMillisTimestamp(now),
      },
      SetOptions(merge: true),
    );
    batch.set(docRef, UserProfileModel.toFirestore(profile));
    await batch.commit();

    return profile;
  }

  Future<void> updateProfile(UserProfile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now());
    await _profileDoc(profile.uid).set(
      FirestoreUtils.withoutCreatedAt(UserProfileModel.toFirestore(updated)),
      SetOptions(merge: true),
    );
  }

  /// Remove os documentos das subcoleções do usuário e o documento raiz
  /// `users/{uid}` em lotes antes da exclusão no Firebase Authentication.
  Future<void> deleteUserData(String uid) async {
    const subcollections = [
      FirestoreCollections.profile,
      FirestoreCollections.accounts,
      FirestoreCollections.categories,
      FirestoreCollections.creditCards,
      FirestoreCollections.invoices,
      FirestoreCollections.transactions,
      FirestoreCollections.recurring,
      FirestoreCollections.installments,
      FirestoreCollections.budgets,
      FirestoreCollections.notifications,
      FirestoreCollections.aiInteractions,
    ];

    final userDoc = _db.collection(FirestoreCollections.users).doc(uid);

    for (final subcollectionName in subcollections) {
      await _deleteCollectionInBatches(userDoc.collection(subcollectionName));
    }

    await userDoc.delete();
  }

  Future<void> _deleteCollectionInBatches(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const batchLimit = 200;
    while (true) {
      final snapshot = await collection.limit(batchLimit).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchLimit) break;
    }
  }
}
