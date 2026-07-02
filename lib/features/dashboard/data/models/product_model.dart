import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  final int id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final String imageUrl;
  final bool isActive;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.imageUrl,
    required this.isActive,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['ID'] as int? ?? json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        stock: json['stock'] as int? ?? 0,
        category: json['category'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [id, name, price];
}
