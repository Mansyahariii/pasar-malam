import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pasar_malam/features/cart/data/models/cart_model.dart';
import 'package:pasar_malam/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:pasar_malam/features/cart/domain/repositories/cart_repository.dart';

enum CartStatus { initial, loading, loaded, error }

class CartProvider extends ChangeNotifier {
  final CartRepository _repository = CartRepositoryImpl();

  CartStatus _status = CartStatus.initial;
  CartModel? _cart;
  String? _error;
  bool _isAdding = false;

  CartStatus get status => _status;
  CartModel? get cart => _cart;
  String? get error => _error;
  bool get isAdding => _isAdding;
  int get itemCount => _cart?.itemCount ?? 0;

  void _setLoading() {
    _status = CartStatus.loading;
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = CartStatus.error;
    _error = message;
    notifyListeners();
  }

  Future<void> fetchCart() async {
    _setLoading();
    try {
      _cart = await _repository.getCart();
      _status = CartStatus.loaded;
    } on DioException catch (e) {
      _setError(
        e.response?.data['message'] as String? ?? 'Gagal memuat keranjang',
      );
      return;
    } catch (e) {
      _setError('Terjadi kesalahan: $e');
      return;
    }
    notifyListeners();
  }

  Future<bool> addToCart(int productId, int quantity) async {
    _isAdding = true;
    notifyListeners();
    try {
      await _repository.addToCart(productId, quantity);
      await fetchCart();
      _isAdding = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data['message'] as String? ?? 'Gagal menambah ke keranjang';
      _isAdding = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Terjadi kesalahan: $e';
      _isAdding = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateItem(int cartItemId, int quantity) async {
    try {
      await _repository.updateCartItem(cartItemId, quantity);
      await fetchCart();
    } on DioException catch (e) {
      _setError(
        e.response?.data['message'] as String? ?? 'Gagal memperbarui item',
      );
    } catch (e) {
      _setError('Terjadi kesalahan: $e');
    }
  }

  Future<void> removeItem(int cartItemId) async {
    try {
      await _repository.removeCartItem(cartItemId);
      await fetchCart();
    } on DioException catch (e) {
      _setError(
        e.response?.data['message'] as String? ?? 'Gagal menghapus item',
      );
    } catch (e) {
      _setError('Terjadi kesalahan: $e');
    }
  }

  Future<void> clearCart() async {
    try {
      await _repository.clearCart();
      _cart = const CartModel(items: [], total: 0, itemCount: 0);
      _status = CartStatus.loaded;
      notifyListeners();
    } on DioException catch (e) {
      _setError(
        e.response?.data['message'] as String? ?? 'Gagal mengosongkan keranjang',
      );
    } catch (e) {
      _setError('Terjadi kesalahan: $e');
    }
  }
}
