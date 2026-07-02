import 'package:pasar_malam/features/order/data/models/order_model.dart';

abstract class OrderRepository {
  Future<OrderModel> checkout({
    required String shippingAddress,
    String? notes,
    required String paymentMethod,
  });
  Future<List<OrderModel>> getMyOrders({int page = 1, int limit = 10});
  Future<OrderModel> getOrderDetail(int orderId);

  /// Cek status pembayaran terkini untuk order tertentu
  Future<OrderModel> checkPaymentStatus(int orderId);
}
