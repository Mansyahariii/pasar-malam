import 'package:flutter/foundation.dart';
import 'package:pasar_malam/core/constants/api_constants.dart';
import 'package:pasar_malam/core/services/dio_client.dart';
import 'package:pasar_malam/features/order/data/models/order_model.dart';
import 'package:pasar_malam/features/order/domain/repositories/order_repository.dart';

void _log(String msg) => debugPrint('[PasarMalam/OrderRepo] $msg');

class OrderRepositoryImpl implements OrderRepository {
 @override
 Future<OrderModel> checkout({
 required String shippingAddress,
 String? notes,
 required String paymentMethod,
 }) async {
 _log('─── checkout ───');
 _log(' REQUEST payment_method = "$paymentMethod"');
 _log('shipping_address = "$shippingAddress"');
 _log('notes = "${notes ?? ''}"');

 final response = await DioClient.instance.post(
 ApiConstants.checkout,
 data: {
 'shipping_address': shippingAddress,
 'notes': notes ?? '',
 'payment_method': paymentMethod,
 },
 );

 _log(' RESPONSE HTTP ${response.statusCode}');
 _log('raw data = ${response.data}');

 final data = response.data['data'] as Map<String, dynamic>;
 _log('data["payment_method"] = "${data['payment_method']}"');
 _log('data["status"] = "${data['status']}"');
 _log('data["ID"] / data["id"] = "${data['ID'] ?? data['id']}"');

 final order = OrderModel.fromJson(data);
 _log(' OrderModel.paymentMethod = "${order.paymentMethod}"');
 return order;
 }

 @override
 Future<List<OrderModel>> getMyOrders({int page = 1, int limit = 10}) async {
 final response = await DioClient.instance.get(
 ApiConstants.orders,
 queryParameters: {'page': page, 'limit': limit},
 );
 final List<dynamic> data = response.data['data'] as List<dynamic>? ?? [];
 return data
 .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
 .toList();
 }

 @override
 Future<OrderModel> getOrderDetail(int orderId) async {
 final response =
 await DioClient.instance.get('${ApiConstants.orders}/$orderId');
 final data = response.data['data'] as Map<String, dynamic>;
 return OrderModel.fromJson(data);
 }

 @override
 Future<OrderModel> checkPaymentStatus(int orderId) =>
 getOrderDetail(orderId);
}
