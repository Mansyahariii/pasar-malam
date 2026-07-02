import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pasar_malam/features/order/data/models/order_model.dart';
import 'package:pasar_malam/features/order/data/repositories/order_repository_impl.dart';
import 'package:pasar_malam/features/order/domain/repositories/order_repository.dart';

enum OrderStatus { initial, loading, success, error }

enum PaymentCheckStatus { idle, checking, paid, failed }

class OrderProvider extends ChangeNotifier {
  final OrderRepository _repository = OrderRepositoryImpl();

  OrderStatus _checkoutStatus = OrderStatus.initial;
  OrderModel? _lastOrder;
  List<OrderModel> _orders = [];
  String? _error;

  // ── Payment status polling ─────────────────────────────────
  PaymentCheckStatus _paymentCheckStatus = PaymentCheckStatus.idle;
  Timer? _pollingTimer;

  OrderStatus get checkoutStatus => _checkoutStatus;
  OrderModel? get lastOrder => _lastOrder;
  List<OrderModel> get orders => _orders;
  String? get error => _error;
  PaymentCheckStatus get paymentCheckStatus => _paymentCheckStatus;

  void _setLoading() {
    _checkoutStatus = OrderStatus.loading;
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _checkoutStatus = OrderStatus.error;
    _error = message;
    notifyListeners();
  }

  Future<bool> checkout({
    required String shippingAddress,
    String? notes,
    required String paymentMethod,
  }) async {
    _paymentCheckStatus = PaymentCheckStatus.idle;
    _setLoading();
    try {
      _lastOrder = await _repository.checkout(
        shippingAddress: shippingAddress,
        notes: notes,
        paymentMethod: paymentMethod,
      );
      _checkoutStatus = OrderStatus.success;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _setError(
        e.response?.data['message'] as String? ?? 'Gagal membuat pesanan',
      );
      return false;
    } catch (e) {
      _setError('Terjadi kesalahan: $e');
      return false;
    }
  }

  Future<void> fetchMyOrders() async {
    _setLoading();
    try {
      _orders = await _repository.getMyOrders();
      _checkoutStatus = OrderStatus.success;
      notifyListeners();
    } on DioException catch (e) {
      _setError(
        e.response?.data['message'] as String? ?? 'Gagal memuat pesanan',
      );
    } catch (e) {
      _setError('Terjadi kesalahan: $e');
    }
  }

  Future<OrderModel?> getOrderDetail(int orderId) async {
    try {
      final order = await _repository.getOrderDetail(orderId);
      return order;
    } catch (e) {
      debugPrint('[PasarMalam/OrderProvider] Error getOrderDetail: $e');
      return null;
    }
  }

  // ── Payment Status Check ───────────────────────────────────

  /// Cek status pembayaran sekali (manual tap atau saat kembali dari GoPay)
  Future<void> checkPaymentStatus(int orderId) async {
    _paymentCheckStatus = PaymentCheckStatus.checking;
    notifyListeners();
    try {
      final updated = await _repository.checkPaymentStatus(orderId);
      _lastOrder = updated;
      _paymentCheckStatus = _isPaid(updated.status)
          ? PaymentCheckStatus.paid
          : PaymentCheckStatus.idle;
      notifyListeners();
    } catch (_) {
      _paymentCheckStatus = PaymentCheckStatus.idle;
      notifyListeners();
    }
  }

  /// Mulai auto-polling setiap [intervalSeconds] detik.
  /// Berhenti otomatis jika sudah terbayar atau [maxAttempts] habis.
  void startPaymentPolling(
    int orderId, {
    int intervalSeconds = 5,
    int maxAttempts = 24, // 24 × 5 s = 2 menit
  }) {
    _pollingTimer?.cancel();
    int attempts = 0;
    _pollingTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (timer) async {
        attempts++;
        if (attempts > maxAttempts) {
          timer.cancel();
          return;
        }
        try {
          final updated = await _repository.checkPaymentStatus(orderId);
          _lastOrder = updated;
          if (_isPaid(updated.status)) {
            _paymentCheckStatus = PaymentCheckStatus.paid;
            timer.cancel();
            notifyListeners();
          }
        } catch (_) {
          // abaikan error polling — coba lagi di iterasi berikut
        }
      },
    );
  }

  /// Hentikan polling (panggil saat page di-dispose)
  void stopPaymentPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  bool _isPaid(String status) =>
      status == 'processing' ||
      status == 'shipped' ||
      status == 'delivered' ||
      status == 'paid';

  void resetPaymentCheckStatus() {
    _paymentCheckStatus = PaymentCheckStatus.idle;
    notifyListeners();
  }

  void resetCheckoutStatus() {
    _checkoutStatus = OrderStatus.initial;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
