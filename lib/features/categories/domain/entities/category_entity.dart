import 'package:equatable/equatable.dart';

/// Tipo de categoria financeira (separação estrita entre receitas e despesas).
enum CategoryType {
  income('income', 'Receita'),
  expense('expense', 'Despesa');

  const CategoryType(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static CategoryType fromStorage(String? value) {
    return switch (value) {
      'income' => CategoryType.income,
      _ => CategoryType.expense,
    };
  }
}

/// Categoria financeira utilizada na classificação de lançamentos e orçamentos.
class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.iconName,
    required this.colorHex,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final CategoryType type;
  final String iconName;
  final String colorHex;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryEntity copyWith({
    String? id,
    String? name,
    String? description,
    CategoryType? type,
    String? iconName,
    String? colorHex,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        type,
        iconName,
        colorHex,
        isDefault,
        isActive,
        createdAt,
        updatedAt,
      ];
}
