class CartProductModel {
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;

  const CartProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
  });

  factory CartProductModel.fromJson(Map<String, dynamic> json) =>
      CartProductModel(
        id: json['ID'] as int? ?? json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['image_url'] as String? ?? '',
        category: json['category'] as String? ?? '',
      );
}

class CartItemModel {
  final int id;
  final int productId;
  final CartProductModel product;
  final int quantity;
  final double subtotal;

  const CartItemModel({
    required this.id,
    required this.productId,
    required this.product,
    required this.quantity,
    required this.subtotal,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final product = CartProductModel.fromJson(
      json['product'] as Map<String, dynamic>? ?? {},
    );
    final quantity = json['quantity'] as int? ?? 0;
    // Gunakan subtotal dari API jika ada dan > 0, fallback hitung price × qty
    final apiSubtotal = (json['subtotal'] as num?)?.toDouble() ?? 0.0;
    final subtotal = apiSubtotal > 0 ? apiSubtotal : product.price * quantity;
    return CartItemModel(
      id: json['ID'] as int? ?? json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      product: product,
      quantity: quantity,
      subtotal: subtotal,
    );
  }
}

class CartModel {
  final List<CartItemModel> items;
  final double total;
  final int itemCount;

  const CartModel({
    required this.items,
    required this.total,
    required this.itemCount,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Selalu hitung total dari items agar akurat (tidak bergantung field API)
    final total = items.fold<double>(0.0, (sum, i) => sum + i.subtotal);

    final itemCount = json['item_count'] as int? ??
        items.fold<int>(0, (sum, i) => sum + i.quantity);
    return CartModel(items: items, total: total, itemCount: itemCount);
  }
}
