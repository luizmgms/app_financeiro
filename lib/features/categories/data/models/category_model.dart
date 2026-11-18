import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_utils.dart';
import '../../domain/entities/category_entity.dart';

/// Modelo de serialização Firestore para [CategoryEntity].
class CategoryModel {
  const CategoryModel._();

  static CategoryEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = DateTime.now();
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];

    return CategoryEntity(
      id: snapshot.id,
      name: (data['name'] as String?) ?? 'Categoria',
      description: (data['description'] as String?) ?? '',
      type: CategoryType.fromStorage(data['type'] as String?),
      iconName: (data['iconName'] as String?) ?? 'category',
      colorHex: (data['colorHex'] as String?) ?? '#0F766E',
      isDefault: (data['isDefault'] as bool?) ?? false,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : now,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : now,
    );
  }

  static Map<String, dynamic> toFirestore(CategoryEntity category) {
    return <String, dynamic>{
      'name': category.name.trim(),
      'description': category.description.trim(),
      'type': category.type.storageValue,
      'iconName': category.iconName,
      'colorHex': category.colorHex,
      'isDefault': category.isDefault,
      'isActive': category.isActive,
      'createdAt': FirestoreUtils.toMillisTimestamp(category.createdAt),
      'updatedAt': FirestoreUtils.toMillisTimestamp(category.updatedAt),
    };
  }
}
