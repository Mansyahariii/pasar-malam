class ApiConstants {
  // Ganti dengan URL backend kamu
  static const String baseUrl = 'http://192.168.100.97:8080/v1';

  // Auth endpoints
  static const String verifyToken = '/auth/verify-token';
  static const String refreshToken = '/auth/refresh';
  static const String fcmToken = '/auth/fcm-token';

  // Product endpoints
  static const String products = '/products';

  // Cart endpoints
  static const String cart = '/cart';

  // Order endpoints
  static const String orders = '/orders';
  static const String checkout = '/orders/checkout';

  // Timeouts
  static const int connectTimeout = 15000; // ms
  static const int receiveTimeout = 15000;
}
