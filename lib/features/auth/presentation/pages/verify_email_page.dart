import 'package:flutter/material.dart';
import 'package:pasar_malam/core/routes/app_router.dart';
import 'package:pasar_malam/features/auth/presentation/providers/auth_provider.dart';
import 'package:pasar_malam/features/auth/presentation/widgets/auth_header.dart';
import 'package:pasar_malam/features/auth/presentation/widgets/custom_button.dart';
import 'package:pasar_malam/features/auth/presentation/widgets/loading_overlay.dart';
import 'package:provider/provider.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _resendCooldown = false;
  int _countdown = 60;

  // Tombol "Ya, sudah konfirmasi"
  // Alur: re-login Firebase (background) → fresh token → verify-token backend → Dashboard
  Future<void> _onYes() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.loginAfterEmailVerification();

    if (!mounted) return;

    if (success) {
      // Re-login berhasil + JWT dari backend → ke Dashboard
      Navigator.pushReplacementNamed(context, AppRouter.dashboard);
    } else if (auth.status == AuthStatus.error) {
      // Error: bisa backend gagal atau kredensial bermasalah
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Gagal konek ke server'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Coba Lagi',
            textColor: Colors.white,
            onPressed: _onYes,
          ),
        ),
      );
    } else {
      // emailVerified masih false — user belum klik link di Gmail
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email belum dikonfirmasi. Cek inbox atau folder spam, lalu klik link verifikasi.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Tombol "Belum, ke halaman login"
  Future<void> _onNo() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown) return;
    await context.read<AuthProvider>().resendVerificationEmail();

    setState(() {
      _resendCooldown = true;
      _countdown = 60;
    });

    // Countdown 60 detik
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        setState(() => _resendCooldown = false);
        return false;
      }
      return true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verifikasi sudah dikirim ulang')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.firebaseUser;

    return LoadingOverlay(
      isLoading: auth.isLoading,
      message: 'Memverifikasi email...',
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AuthHeader(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'Verifikasi Email',
                  subtitle:
                      'Kami sudah mengirim link verifikasi ke email di bawah ini. Buka email dan klik link tersebut.',
                  iconColor: Colors.orange,
                ),
                const SizedBox(height: 24),

                // Tampilkan email user
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        user?.email ?? '-',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Pertanyaan konfirmasi
                Text(
                  'Sudah konfirmasi email?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 20),

                // Tombol YES
                CustomButton(
                  label: 'Ya, sudah konfirmasi',
                  onPressed: _onYes,
                  isLoading: auth.isLoading,
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Tombol NO
                CustomButton(
                  label: 'Belum, kembali ke Login',
                  variant: ButtonVariant.outlined,
                  onPressed: _onNo,
                  icon: Icon(Icons.arrow_back,
                      color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 32),

                // Divider
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 16),

                // Kirim ulang email
                Text(
                  'Tidak menerima email?',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _resendCooldown ? null : _resendEmail,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _resendCooldown
                        ? 'Kirim Ulang ($_countdown detik)'
                        : 'Kirim Ulang Email',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
