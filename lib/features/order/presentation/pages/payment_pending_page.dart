import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasar_malam/core/routes/app_router.dart';
import 'package:pasar_malam/core/services/global_institute_pay_service.dart';
import 'package:pasar_malam/features/order/data/models/order_model.dart';
import 'package:pasar_malam/features/order/presentation/providers/order_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

void _log(String msg) => debugPrint('[PasarMalam/PaymentPending] $msg');

class PaymentPendingPage extends StatefulWidget {
  final OrderModel order;

  const PaymentPendingPage({super.key, required this.order});

  @override
  State<PaymentPendingPage> createState() => _PaymentPendingPageState();
}

class _PaymentPendingPageState extends State<PaymentPendingPage>
    with WidgetsBindingObserver {
  bool _payLaunched = false;
  late OrderProvider _orderProvider;

  @override
  void initState() {
    super.initState();
    _orderProvider = context.read<OrderProvider>();
    _log('─────────────────────────────────────────');
    _log(
      'initState | orderId=${widget.order.id} '
      'paymentMethod=${widget.order.paymentMethod} '
      'amount=${widget.order.totalAmount}',
    );

    WidgetsBinding.instance.addObserver(this);

    if (widget.order.paymentMethod == 'global_institute_pay') {
      _log(' Akan auto-launch Monplace setelah frame pertama');
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _launchGlobalInstitutePay(),
      );
    } else {
      _log(
        'ℹ Metode bukan global_institute_pay → skip auto-launch '
        '(method=${widget.order.paymentMethod})',
      );
    }

    _log('⏱ Memulai polling backend (orderId=${widget.order.id})');
    _orderProvider.startPaymentPolling(widget.order.id);

    _log('initState selesai.');
  }

  @override
  void dispose() {
    _log('dispose | orderId=${widget.order.id}');
    WidgetsBinding.instance.removeObserver(this);
    _orderProvider.stopPaymentPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('AppLifecycle: $state | _payLaunched=$_payLaunched');
    if (state == AppLifecycleState.resumed && _payLaunched) {
      _log(
        ' Resumed setelah launch → cek status sekali (orderId=${widget.order.id})',
      );
      _orderProvider.checkPaymentStatus(widget.order.id);
    }
  }

  Future<void> _launchGlobalInstitutePay() async {
    _log('─── _launchGlobalInstitutePay ───');
    _log(
      'orderId=${widget.order.id} | amount=${widget.order.totalAmount} '
      '| notes="${widget.order.notes}"',
    );

    final notes = widget.order.notes.isNotEmpty ? widget.order.notes : null;

    // Build URL — detail parameter sudah dilog di dalam service
    final deeplinkUrl = GlobalInstitutePayService.buildDeeplinkUrl(
      orderId: widget.order.id,
      amount: widget.order.totalAmount,
      description: notes,
    );

    final uri = Uri.parse(deeplinkUrl);
    _log(' URI yang akan diluncurkan: $uri');

    // canLaunchUrl hanya untuk diagnosis — bukan penjaga keras.
    // Bisa false-negatif jika APK belum di-rebuild setelah perubahan manifest.
    _log(' Mengecek canLaunchUrl (diagnosis saja)...');
    final canLaunch = await canLaunchUrl(uri);
    _log('canLaunchUrl → $canLaunch');
    if (!canLaunch) {
      _log('canLaunchUrl=false — tetap mencoba launchUrl langsung...');
      _log('Kemungkinan penyebab false-negatif:');
      _log('1. APK belum di-rebuild setelah perubahan AndroidManifest.xml');
      _log('2. Aplikasi Monplace belum terinstal di perangkat ini');
    }

    _log(' Memanggil launchUrl (mode=externalApplication)...');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      _log('launchUrl → $launched');
      if (launched) {
        _log(' Monplace berhasil dibuka');
        setState(() => _payLaunched = true);
      } else {
        _log('launchUrl=false — aplikasi ada tapi tidak merespons');
        if (!mounted) return;
        _showAppNotFoundDialog();
      }
    } catch (e) {
      _log(' Exception launchUrl: $e');
      _log('→ Aplikasi Monplace kemungkinan tidak terinstal');
      if (!mounted) return;
      _showAppNotFoundDialog();
    }
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return 'Rp. ${buffer.toString().split('').reversed.join()}';
  }

  bool _isTransitioning = false;

  void _onPaymentSuccess() {
    if (!mounted || _isTransitioning) return;
    _isTransitioning = true;
    _log(' _onPaymentSuccess dipanggil — hentikan polling & navigasi');
    _orderProvider.stopPaymentPolling();
    _orderProvider.resetPaymentCheckStatus();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.orderSuccess,
      (route) => route.settings.name == AppRouter.dashboard,
      arguments: _orderProvider.lastOrder ?? widget.order,
    );
  }

  void _showAppNotFoundDialog() {
    _log(' Menampilkan dialog: aplikasi tidak ditemukan');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplikasi Tidak Ditemukan'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aplikasi Monplace tidak terinstal di perangkat ini.',
            ),
            SizedBox(height: 12),
            Text(
              'Pesanan Anda tetap tersimpan. Lakukan pembayaran melalui aplikasi '
              'Monplace, lalu kembali untuk mengecek status.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OrderProvider>().checkPaymentStatus(widget.order.id);
            },
            child: const Text('Cek Status Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = context.watch<OrderProvider>();
    final payStatus = orderProv.paymentCheckStatus;
    final order = orderProv.lastOrder ?? widget.order;

    // Jika sudah terbayar, navigasi ke halaman sukses
    if (payStatus == PaymentCheckStatus.paid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPaymentSuccess());
    }

    return PopScope(
      // Cegah tombol back saat pembayaran masih pending agar tidak bisa skip
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showCancelConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Selesaikan Pembayaran'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showCancelConfirmation,
          ),
        ),
        body: order.paymentMethod == 'virtual_account'
            ? _VirtualAccountBody(
                order: order,
                payStatus: payStatus,
                formatPrice: _formatPrice,
                onCheckStatus: () =>
                    context.read<OrderProvider>().checkPaymentStatus(order.id),
              )
            : _GlobalInstitutePayBody(
                order: order,
                payStatus: payStatus,
                formatPrice: _formatPrice,
                payLaunched: _payLaunched,
                onOpenApp: _launchGlobalInstitutePay,
                onCheckStatus: () =>
                    context.read<OrderProvider>().checkPaymentStatus(order.id),
              ),
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pembayaran?'),
        content: const Text(
          'Pesanan tetap tersimpan. Kamu bisa bayar nanti di halaman "Pesanan Saya".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lanjutkan Bayar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.dashboard,
                (route) => false,
              );
            },
            child: Text(
              'Bayar Nanti',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Virtual Account Body
// ──────────────────────────────────────────────────────────────

class _VirtualAccountBody extends StatelessWidget {
  final OrderModel order;
  final PaymentCheckStatus payStatus;
  final String Function(double) formatPrice;
  final VoidCallback onCheckStatus;

  const _VirtualAccountBody({
    required this.order,
    required this.payStatus,
    required this.formatPrice,
    required this.onCheckStatus,
  });

  static const List<_BankInfo> _banks = [
    _BankInfo('BCA', '888', Color(0xFF003087)),
    _BankInfo('Mandiri', '888', Color(0xFF003087)),
    _BankInfo('BNI', '8808', Color(0xFF004B87)),
    _BankInfo('BRI', '889', Color(0xFF00529B)),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final vaNumber = order.vaNumber ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header icon ─────────────────────────────────────
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card,
                size: 40,
                color: Color(0xFFE65100),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Selesaikan Pembayaran via Virtual Account',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Order #${order.id} · ${formatPrice(order.totalAmount)}',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Nomor VA ────────────────────────────────────────
          _SectionLabel(label: 'Nomor Virtual Account'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vaNumber,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: vaNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nomor VA disalin'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: 'Salin nomor VA',
                  color: primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Total Pembayaran ─────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Pembayaran',
                  style: TextStyle(fontSize: 14, color: onSurface),
                ),
                Text(
                  formatPrice(order.totalAmount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Cara Bayar ─────────────────────────────────────
          _SectionLabel(label: 'Cara Pembayaran'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < _banks.length; i++) ...[
                  _BankStepTile(bank: _banks[i], vaNumber: vaNumber),
                  if (i < _banks.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Cek Status ─────────────────────────────────────
          _CheckStatusButton(payStatus: payStatus, onPressed: onCheckStatus),

          const SizedBox(height: 16),

          // Status belum bayar
          if (payStatus == PaymentCheckStatus.idle) ...[
            Center(
              child: Text(
                'Belum ada pembayaran terdeteksi',
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BankInfo {
  final String name;
  final String prefix;
  final Color color;

  const _BankInfo(this.name, this.prefix, this.color);
}

class _BankStepTile extends StatelessWidget {
  final _BankInfo bank;
  final String vaNumber;

  const _BankStepTile({required this.bank, required this.vaNumber});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bank.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            bank.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: bank.color,
            ),
          ),
        ),
      ),
      title: Text(
        bank.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      subtitle: Text(
        'Pilih Transfer → Virtual Account → masukkan nomor VA',
        style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.5)),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Monplace Body
// ──────────────────────────────────────────────────────────────

class _GlobalInstitutePayBody extends StatelessWidget {
  final OrderModel order;
  final PaymentCheckStatus payStatus;
  final String Function(double) formatPrice;
  final bool payLaunched;
  final VoidCallback onOpenApp;
  final VoidCallback onCheckStatus;

  const _GlobalInstitutePayBody({
    required this.order,
    required this.payStatus,
    required this.formatPrice,
    required this.payLaunched,
    required this.onOpenApp,
    required this.onCheckStatus,
  });

  static const _brandColor = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ── Header icon ─────────────────────────────────────
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0x1A1A237E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              size: 46,
              color: _brandColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bayar dengan Monplace',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Order #${order.id} · ${formatPrice(order.totalAmount)}',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          // ── Info keamanan ────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _brandColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _brandColor.withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: _brandColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pembayaran akan diverifikasi dengan PIN dan kode 2FA di aplikasi Monplace',
                    style: TextStyle(
                      fontSize: 12,
                      color: _brandColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Langkah pembayaran ───────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepItem(
                  number: '1',
                  text: payLaunched
                      ? 'Aplikasi Monplace sudah dibuka'
                      : 'Kamu akan diarahkan ke Monplace',
                  done: payLaunched,
                ),
                const SizedBox(height: 14),
                _StepItem(
                  number: '2',
                  text:
                      'Masukkan PIN dan kode verifikasi 2FA, lalu konfirmasi pembayaran ${formatPrice(order.totalAmount)}',
                  done: false,
                ),
                const SizedBox(height: 14),
                _StepItem(
                  number: '3',
                  text:
                      'Kembali ke aplikasi — status diperbarui otomatis via callback atau polling',
                  done: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Tombol buka Monplace ─────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(
                payLaunched
                    ? 'Buka Kembali Monplace'
                    : 'Buka Monplace',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onOpenApp,
            ),
          ),

          const SizedBox(height: 12),

          // ── Cek Status Manual ────────────────────────────────
          _CheckStatusButton(payStatus: payStatus, onPressed: onCheckStatus),

          const SizedBox(height: 16),

          if (payStatus == PaymentCheckStatus.idle && payLaunched)
            Text(
              'Menunggu konfirmasi pembayaran dari Monplace...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withValues(alpha: 0.5),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String text;
  final bool done;

  const _StepItem({
    required this.number,
    required this.text,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? Colors.green
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    number,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: TextStyle(fontSize: 14, color: onSurface)),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Shared Widgets
// ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _CheckStatusButton extends StatelessWidget {
  final PaymentCheckStatus payStatus;
  final VoidCallback onPressed;

  const _CheckStatusButton({required this.payStatus, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isChecking = payStatus == PaymentCheckStatus.checking;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
        icon: isChecking
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : const Icon(Icons.refresh_rounded),
        label: Text(
          isChecking ? 'Memeriksa Status...' : 'Cek Status Pembayaran',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: isChecking ? null : onPressed,
      ),
    );
  }
}
