import 'package:flutter/material.dart';
import 'package:flutter_biometric_kit/flutter_biometric_kit.dart';
import 'package:provider/provider.dart';

import '../services/biometric_lock_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Membungkus seluruh widget tree dan menampilkan layar kunci
/// jika [BiometricLockProvider.isLocked] bernilai true.
///
/// Dipasang di [MaterialApp.builder] agar aktif di semua halaman.
class BiometricLockScreen extends StatefulWidget {
  final Widget child;

  const BiometricLockScreen({super.key, required this.child});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  // Kunci setelah app di background lebih dari 30 detik
  static const _lockTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger unlock pertama kali app dibuka (setelah frame pertama render)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BiometricLockProvider>();
      if (provider.isLocked) provider.unlock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Guard: element mungkin belum active saat transisi lifecycle
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.paused:
        final provider = context.read<BiometricLockProvider>();
        if (!provider.isLocked) {
          _backgroundedAt = DateTime.now();
        }

      case AppLifecycleState.resumed:
        final bg = _backgroundedAt;
        if (bg != null && DateTime.now().difference(bg) >= _lockTimeout) {
          _backgroundedAt = null;
          // Defer ke frame berikutnya agar element sudah active
          // sebelum notifyListeners() dipanggil oleh lock()/unlock()
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final provider = context.read<BiometricLockProvider>();
            provider.lock();
            provider.unlock();
          });
        }

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BiometricLockProvider>();

    if (!provider.isLocked) return widget.child;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon kunci dengan animasi loading saat autentikasi
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: provider.isAuthenticating
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.teal,
                          ),
                        )
                      : Container(
                          key: const ValueKey('icon'),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.teal.shade50,
                            border: Border.all(color: Colors.teal, width: 2),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            size: 36,
                            color: Colors.teal,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Aplikasi Terkunci',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Verifikasi identitas Anda untuk melanjutkan',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),

                // Pesan error jika autentikasi gagal
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade400, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Tombol buka kunci
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        provider.isAuthenticating ? null : provider.unlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Buka Kunci'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                // Tombol Buka Pengaturan — muncul hanya jika belum ada biometrik terdaftar
                if (provider.errorCode == BiometricErrorCode.notEnrolled) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      // Android akan membuka Settings biometrik
                      // Implementasi lanjutan: gunakan package open_settings
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Daftarkan Biometrik di Pengaturan'),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal),
                  ),
                ],

                // Tombol Keluar Akun (Logout) — penyelamat jika biometrik error / tidak terdaftar
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    final authProv = context.read<AuthProvider>();
                    await authProv.logout();
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Keluar Akun / Login Ulang'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
