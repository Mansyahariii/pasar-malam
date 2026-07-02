import 'package:flutter/material.dart';
import 'package:pasar_malam/core/routes/app_router.dart';
import 'package:pasar_malam/features/cart/presentation/providers/cart_provider.dart';
import 'package:pasar_malam/features/order/presentation/providers/order_provider.dart';
import 'package:provider/provider.dart';

void _log(String msg) => debugPrint('[PasarMalam/Checkout] $msg');

class CheckoutPage extends StatefulWidget {
 const CheckoutPage({super.key});

 @override
 State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
 final _formKey = GlobalKey<FormState>();
 final _addressCtrl = TextEditingController();
 final _notesCtrl = TextEditingController();
 String? _selectedPaymentMethod;

 static const List<_PaymentOption> _paymentOptions = [
 _PaymentOption(
 value: 'global_institute_pay',
 label: 'Global Institute Pay',
 subtitle: 'Bayar via Dompet Kampus Global',
 icon: Icons.school_rounded,
 iconColor: Color(0xFF1A237E),
 ),
 _PaymentOption(
 value: 'bank_transfer',
 label: 'Transfer Bank',
 subtitle: 'BCA, Mandiri, BNI, BRI',
 icon: Icons.account_balance,
 iconColor: Color(0xFF1565C0),
 ),
 _PaymentOption(
 value: 'virtual_account',
 label: 'Virtual Account',
 subtitle: 'Nomor VA otomatis digenerate',
 icon: Icons.credit_card,
 iconColor: Color(0xFFE65100),
 ),
 ];

 @override
 void dispose() {
 _addressCtrl.dispose();
 _notesCtrl.dispose();
 super.dispose();
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

 Future<void> _placeOrder(BuildContext context) async {
 if (!_formKey.currentState!.validate()) return;
 if (_selectedPaymentMethod == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Pilih metode pembayaran terlebih dahulu'),
 backgroundColor: Colors.red,
 ),
 );
 return;
 }

 final orderProv = context.read<OrderProvider>();
 final cartProv = context.read<CartProvider>();

 // Show loading overlay
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (_) => const Center(child: CircularProgressIndicator()),
 );

 _log('─── _placeOrder ───');
 _log(' Mengirim order | paymentMethod="$_selectedPaymentMethod"');

 final success = await orderProv.checkout(
 shippingAddress: _addressCtrl.text.trim(),
 notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
 paymentMethod: _selectedPaymentMethod!,
 );

 if (!context.mounted) return;
 Navigator.pop(context); // dismiss loading

 _log(' checkout selesai | success=$success | error="${orderProv.error}"');

 if (success) {
 await cartProv.clearCart();
 if (!context.mounted) return;

 final order = orderProv.lastOrder!;
 _log(' Order dari backend:');
 _log('order.id = ${order.id}');
 _log('order.paymentMethod = "${order.paymentMethod}"');
 _log('order.status = "${order.status}"');
 _log('order.totalAmount = ${order.totalAmount}');

 // Gunakan pilihan user — tidak bergantung pada nilai yang dikembalikan backend
 final needsPaymentFlow =
 _selectedPaymentMethod == 'virtual_account' ||
 _selectedPaymentMethod == 'global_institute_pay';

 _log(' needsPaymentFlow = $needsPaymentFlow');
 _log('_selectedPaymentMethod = "$_selectedPaymentMethod"');
 _log('order.paymentMethod (backend) = "${order.paymentMethod}"');

 if (needsPaymentFlow) {
 // Pastikan paymentMethod pada order sesuai pilihan user,
 // karena backend mungkin mengembalikan nilai berbeda.
 final orderToPass = order.paymentMethod == _selectedPaymentMethod
 ? order
 : order.copyWith(paymentMethod: _selectedPaymentMethod!);
 _log('Navigasi ke PaymentPendingPage');
 _log('order.paymentMethod yang diteruskan = "${orderToPass.paymentMethod}"');
 Navigator.pushNamedAndRemoveUntil(
 context,
 AppRouter.paymentPending,
 (route) => route.settings.name == AppRouter.dashboard,
 arguments: orderToPass,
 );
 } else {
 _log('Navigasi ke OrderSuccessPage (bank_transfer atau lainnya)');
 Navigator.pushNamedAndRemoveUntil(
 context,
 AppRouter.orderSuccess,
 (route) => route.settings.name == AppRouter.dashboard,
 arguments: order,
 );
 }
 } else {
 _log(' checkout gagal: "${orderProv.error}"');
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(orderProv.error ?? 'Gagal membuat pesanan'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 final cartProv = context.watch<CartProvider>();
 final cart = cartProv.cart;
 final onSurface = Theme.of(context).colorScheme.onSurface;
 final surface = Theme.of(context).colorScheme.surface;
 final primary = Theme.of(context).colorScheme.primary;

 return Scaffold(
 appBar: AppBar(title: const Text('Checkout')),
 body: Form(
 key: _formKey,
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // ── 1. Ringkasan Pesanan ───────────────────────
 _SectionTitle(title: 'Ringkasan Pesanan'),
 const SizedBox(height: 8),
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
 if (cart != null) ...[
 ...cart.items.map(
 (item) => Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 16,
 vertical: 10,
 ),
 child: Row(
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 item.product.name,
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w500,
 color: onSurface,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 '${item.quantity} x ${_formatPrice(item.product.price)}',
 style: TextStyle(
 fontSize: 12,
 color: onSurface.withValues(alpha: 0.5),
 ),
 ),
 ],
 ),
 ),
 Text(
 _formatPrice(item.subtotal),
 style: TextStyle(
 fontSize: 13,
 fontWeight: FontWeight.w600,
 color: onSurface,
 ),
 ),
 ],
 ),
 ),
 ),
 const Divider(height: 1),
 ],
 Padding(
 padding: const EdgeInsets.all(16),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'Total',
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.bold,
 ),
 ),
 Text(
 _formatPrice(cart?.total ?? 0),
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 color: primary,
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 24),

 // ── 2. Alamat Pengiriman ───────────────────────
 _SectionTitle(title: 'Alamat Pengiriman'),
 const SizedBox(height: 8),
 TextFormField(
 controller: _addressCtrl,
 maxLines: 3,
 decoration: InputDecoration(
 hintText: 'Masukkan alamat lengkap pengiriman...',
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 filled: true,
 fillColor: surface,
 ),
 validator: (val) {
 if (val == null || val.trim().isEmpty) {
 return 'Alamat pengiriman wajib diisi';
 }
 return null;
 },
 ),

 const SizedBox(height: 24),

 // ── 3. Catatan ─────────────────────────────────
 _SectionTitle(title: 'Catatan (opsional)'),
 const SizedBox(height: 8),
 TextFormField(
 controller: _notesCtrl,
 maxLines: 2,
 decoration: InputDecoration(
 hintText: 'Tambahkan catatan untuk penjual...',
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 filled: true,
 fillColor: surface,
 ),
 ),

 const SizedBox(height: 24),

 // ── 4. Metode Pembayaran ───────────────────────
 _SectionTitle(title: 'Metode Pembayaran'),
 const SizedBox(height: 8),
 ..._paymentOptions.map(
 (option) => _PaymentOptionCard(
 option: option,
 isSelected: _selectedPaymentMethod == option.value,
 onSelect: () =>
 setState(() => _selectedPaymentMethod = option.value),
 ),
 ),

 const SizedBox(height: 32),

 // ── 5. Tombol Place Order ──────────────────────
 SizedBox(
 width: double.infinity,
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: primary,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(12),
 ),
 ),
 onPressed: () => _placeOrder(context),
 child: const Text(
 'Place Order',
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 ),
 ),
 ),
 ),

 const SizedBox(height: 24),
 ],
 ),
 ),
 ),
 );
 }
}

// ── Section Title ──────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
 final String title;

 const _SectionTitle({required this.title});

 @override
 Widget build(BuildContext context) {
 return Text(
 title,
 style: Theme.of(context).textTheme.titleMedium?.copyWith(
 fontWeight: FontWeight.bold,
 ),
 );
 }
}

// ── Payment Option Card ────────────────────────────────────
class _PaymentOption {
 final String value;
 final String label;
 final String subtitle;
 final IconData icon;
 final Color iconColor;

 const _PaymentOption({
 required this.value,
 required this.label,
 required this.subtitle,
 required this.icon,
 required this.iconColor,
 });
}

class _PaymentOptionCard extends StatelessWidget {
 final _PaymentOption option;
 final bool isSelected;
 final VoidCallback onSelect;

 const _PaymentOptionCard({
 required this.option,
 required this.isSelected,
 required this.onSelect,
 });

 @override
 Widget build(BuildContext context) {
 final surface = Theme.of(context).colorScheme.surface;
 final primary = Theme.of(context).colorScheme.primary;
 final onSurface = Theme.of(context).colorScheme.onSurface;

 return GestureDetector(
 onTap: onSelect,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 margin: const EdgeInsets.only(bottom: 10),
 decoration: BoxDecoration(
 color: surface,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: isSelected ? primary : Colors.transparent,
 width: 2,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.05),
 blurRadius: 6,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 child: Row(
 children: [
 Container(
 width: 40,
 height: 40,
 decoration: BoxDecoration(
 color: option.iconColor.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(10),
 ),
 child: Icon(option.icon, color: option.iconColor, size: 22),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 option.label,
 style: TextStyle(
 fontSize: 14,
 fontWeight: FontWeight.w600,
 color: onSurface,
 ),
 ),
 Text(
 option.subtitle,
 style: TextStyle(
 fontSize: 12,
 color: onSurface.withValues(alpha: 0.5),
 ),
 ),
 ],
 ),
 ),
 Container(
 width: 20,
 height: 20,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(
 color: isSelected ? primary : onSurface.withValues(alpha: 0.3),
 width: 2,
 ),
 ),
 child: isSelected
 ? Center(
 child: Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: primary,
 ),
 ),
 )
 : null,
 ),
 ],
 ),
 ),
 ),
 );
 }
}
