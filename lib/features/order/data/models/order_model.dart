class OrderItemModel {
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double subtotal;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        productId: json['product_id'] as int? ?? 0,
        productName: json['product_name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        quantity: json['quantity'] as int? ?? 0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      );
}

class OrderModel {
  final int id;
  final double totalAmount;
  final String status;
  final String shippingAddress;
  final String notes;
  final String paymentMethod;
  final List<OrderItemModel> items;
  final String createdAt;

  /// Nomor Virtual Account — hanya terisi jika payment_method == 'virtual_account'
  final String? vaNumber;

  /// Deep-link GoPay — hanya terisi jika payment_method == 'gopay'
  final String? gopayDeeplink;

  const OrderModel({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.shippingAddress,
    required this.notes,
    required this.paymentMethod,
    required this.items,
    required this.createdAt,
    this.vaNumber,
    this.gopayDeeplink,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return OrderModel(
      id: json['ID'] as int? ?? json['id'] as int? ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      shippingAddress: json['shipping_address'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      items: items,
      createdAt: json['created_at'] as String? ?? '',
      vaNumber: json['va_number'] as String?,
      gopayDeeplink: json['gopay_deeplink'] as String?,
    );
  }

  /// Buat salinan dengan field tertentu diubah (berguna saat polling status)
  OrderModel copyWith({
    String? status,
    String? paymentMethod,
    String? vaNumber,
    String? gopayDeeplink,
  }) {
    return OrderModel(
      id: id,
      totalAmount: totalAmount,
      status: status ?? this.status,
      shippingAddress: shippingAddress,
      notes: notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items,
      createdAt: createdAt,
      vaNumber: vaNumber ?? this.vaNumber,
      gopayDeeplink: gopayDeeplink ?? this.gopayDeeplink,
    );
  }
}
