import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pasar_malam/core/constants/api_constants.dart';
import 'package:pasar_malam/core/services/secure_storage.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // ── Interceptor 1: Logging Request & Response ─────────────
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          debugPrint('┌─────────────────────────────────────────────');
          debugPrint('│ [BACKEND REQUEST]');
          debugPrint('│ Method : ${options.method}');
          debugPrint('│ URL    : ${options.baseUrl}${options.path}');
          if (options.queryParameters.isNotEmpty) {
            debugPrint('│ Query  : ${options.queryParameters}');
          }
          if (options.data != null) {
            // Sembunyikan nilai firebase_token agar tidak terlalu panjang di log
            final body = options.data is Map
                ? (options.data as Map).map(
                    (k, v) => MapEntry(
                      k,
                      k == 'firebase_token' ? '${(v as String).substring(0, 20)}...[truncated]' : v,
                    ),
                  )
                : options.data;
            debugPrint('│ Body   : $body');
          }
          debugPrint('└─────────────────────────────────────────────');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('┌─────────────────────────────────────────────');
          debugPrint('│ [BACKEND RESPONSE]');
          debugPrint('│ Status : ${response.statusCode} ${response.statusMessage}');
          debugPrint(
            '│ URL    : ${response.requestOptions.baseUrl}${response.requestOptions.path}',
          );
          debugPrint('│ Data   : ${response.data}');
          debugPrint('└─────────────────────────────────────────────');
          handler.next(response);
        },
        onError: (error, handler) async {
          debugPrint('┌─────────────────────────────────────────────');
          debugPrint('│ [BACKEND ERROR]');
          debugPrint('│ Status : ${error.response?.statusCode}');
          debugPrint('│ URL    : ${error.requestOptions.baseUrl}${error.requestOptions.path}');
          debugPrint('│ Type   : ${error.type}');
          debugPrint('│ Message: ${error.message}');
          if (error.response?.data != null) {
            debugPrint('│ Body   : ${error.response?.data}');
          }
          debugPrint('└─────────────────────────────────────────────');

          // Auto logout jika 401 Unauthorized
          if (error.response?.statusCode == 401) {
            await SecureStorageService.clearAll();
          }
          handler.next(error);
        },
      ),
    );

    // ── Interceptor 2: Auto-inject Bearer Token ────────────────
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            debugPrint('[BACKEND] Authorization token injected');
          }
          handler.next(options);
        },
      ),
    );

    return dio;
  }
}
