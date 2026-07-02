import 'package:pasar_malam/features/cart/data/models/cart_model.dart';

abstract class CartRepository {
  Future<CartModel> getCart();
  Future<void> addToCart(int productId, int quantity);
  Future<void> updateCartItem(int cartItemId, int quantity);
  Future<void> removeCartItem(int cartItemId);
  Future<void> clearCart();
}
