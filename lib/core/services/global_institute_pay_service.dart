import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

// ── Log helper ────────────────────────────────────────────────
void _log(String tag, String message) {
 debugPrint('[PasarMalam/$tag] $message');
}

// ── Model callback ────────────────────────────────────────────

class PaymentCallbackData {
 final String status;
 final String? reference;
 final String? transactionId;

 const PaymentCallbackData({required this.status, this.reference, this.transactionId});

 bool get isSuccess => status == 'success';

 @override
 String toString() =>
 'PaymentCallbackData(status=$status, reference=$reference, transactionId=$transactionId)';
}

// ── Service ───────────────────────────────────────────────────

/// Mengelola deeplink keluar ke Monplace
/// dan deeplink masuk (callback pembayaran) ke Home Living.
class GlobalInstitutePayService {
 static final GlobalInstitutePayService _instance = GlobalInstitutePayService._();
 factory GlobalInstitutePayService() => _instance;
 GlobalInstitutePayService._();

 static const _tag = 'GlobalInstitutePay';

 final _callbackController = StreamController<PaymentCallbackData>.broadcast();
 Stream<PaymentCallbackData> get onCallback => _callbackController.stream;

 PaymentCallbackData? _pendingCallback;

 /// Ambil callback cold-start, dikosongkan setelah dibaca (consume-once).
 PaymentCallbackData? consumePendingCallback() {
 final data = _pendingCallback;
 _pendingCallback = null;
 if (data != null) {
 _log(_tag, ' Mengonsumsi pending cold-start callback: $data');
 }
 return data;
 }

 // ── Init ────────────────────────────────────────────────────

 Future<void> init() async {
 _log(_tag, ' Inisialisasi GlobalInstitutePayService...');

 final appLinks = AppLinks();

 // Kasus 1: cold start — app dibuka oleh deeplink
 try {
 _log(_tag, ' Mengambil initial link (cold start)...');
 final uri = await appLinks.getInitialLink();
 if (uri != null) {
 _log(_tag, ' Initial link ditemukan: $uri');
 _handleUri(uri, isColdStart: true);
 } else {
 _log(_tag, 'ℹ Tidak ada initial link (app dibuka normal)');
 }
 } catch (e) {
 _log(_tag, 'Error saat getInitialLink: $e');
 }

 // Kasus 2: app sudah berjalan — deeplink masuk via stream
 _log(_tag, ' Memulai listener uriLinkStream...');
 appLinks.uriLinkStream.listen(
 (uri) {
 _log(_tag, ' URI masuk via stream: $uri');
 _handleUri(uri);
 },
 onError: (Object e) {
 _log(_tag, 'Error pada uriLinkStream: $e');
 },
 );

 _log(_tag, ' Inisialisasi selesai.');
 }

 // ── Handle URI masuk ─────────────────────────────────────────

 void _handleUri(Uri uri, {bool isColdStart = false}) {
 _log(
 _tag,
 ' Handle URI | scheme=${uri.scheme} host=${uri.host} '
 'path=${uri.path} params=${uri.queryParameters} | coldStart=$isColdStart',
 );

 // Filter: hanya proses callback Home Living
 if (uri.scheme != 'pasarmalam') {
 _log(_tag, '⏩ Diabaikan — bukan skema pasarmalam (scheme=${uri.scheme})');
 return;
 }
 if (uri.host != 'payment-callback') {
 _log(_tag, '⏩ Diabaikan — bukan host payment-callback (host=${uri.host})');
 return;
 }

 final data = PaymentCallbackData(
 status: uri.queryParameters['status'] ?? 'unknown',
 reference: uri.queryParameters['reference'],
 transactionId: uri.queryParameters['transaction_id'],
 );

 _log(_tag, ' Callback diterima: $data');

 if (isColdStart) {
 _pendingCallback = data;
 _log(_tag, ' Disimpan sebagai pending cold-start callback');
 }

 _callbackController.add(data);
 _log(_tag, ' Event dikirim ke stream (subscriber aktif)');
 }

 // ── Build URL keluar ─────────────────────────────────────────

 /// Membangun URL deeplink ke Monplace sesuai spesifikasi.
 static String buildDeeplinkUrl({
 required int orderId,
 required double amount,
 String? description,
 }) {
 const scheme = 'monplace';
 const host = 'pay';
 final desc = (description != null && description.isNotEmpty) ? description : 'Order #$orderId';
 const callbackUrl = 'pasarmalam://payment-callback';

 _log(_tag, ' Membangun deeplink URL:');
 _log(_tag, 'merchant_id : MCH_PASAR_MALAM');
 _log(_tag, 'merchant_name: Home Living');
 _log(_tag, 'amount : ${amount.toInt()}');
 _log(_tag, 'description : $desc');
 _log(_tag, 'reference : INV-$orderId');
 _log(_tag, 'callback : $callbackUrl');

 final uri = Uri(
 scheme: scheme,
 host: host,
 queryParameters: {
 'merchant_id': 'MCH_PASAR_MALAM',
 'merchant_name': 'Home Living',
 'amount': amount.toInt().toString(),
 'description': desc,
 'reference': 'INV-$orderId',
 'callback': callbackUrl,
 },
 );

 final result = uri.toString();
 _log(_tag, ' URL lengkap (sebelum launch): $result');
 return result;
 }
}
