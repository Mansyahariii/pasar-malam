import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pasar_malam/core/constants/api_constants.dart';
import 'package:pasar_malam/core/services/dio_client.dart';
import 'package:pasar_malam/core/services/notification_service.dart';
import 'package:pasar_malam/core/services/secure_storage.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  emailNotVerified,
  error,
}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1029957735829-92731o7vv5nsemr1ej1ipr9gsss4psas.apps.googleusercontent.com',
  );

  // ─── State ──────────────────────────────────────────────
  AuthStatus _status = AuthStatus.initial;
  User? _firebaseUser;
  String? _backendToken;
  String? _errorMessage;

  // Kredensial sementara — hanya ada di memory, dipakai untuk re-login
  // setelah user klik "Ya sudah konfirmasi" di VerifyEmailPage
  String? _tempEmail;
  String? _tempPassword;

  // ─── Getters ────────────────────────────────────────────
  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  String? get backendToken => _backendToken;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;

  // ─── Register dengan Email & Password ───────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading();
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ [FIREBASE REQUEST] createUserWithEmailAndPassword');
    debugPrint('│ Email : $email');
    debugPrint('│ Name  : $name');
    debugPrint('└─────────────────────────────────────────────');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _firebaseUser = credential.user;
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE RESPONSE] Register berhasil');
      debugPrint('│ UID   : ${_firebaseUser?.uid}');
      debugPrint('│ Email : ${_firebaseUser?.email}');
      debugPrint('└─────────────────────────────────────────────');

      // Update display name di Firebase
      debugPrint('[FIREBASE] updateDisplayName → $name');
      await _firebaseUser?.updateDisplayName(name);

      // Kirim email verifikasi
      debugPrint('[FIREBASE] sendEmailVerification → ${_firebaseUser?.email}');
      await _firebaseUser?.sendEmailVerification();
      debugPrint('[FIREBASE] Email verifikasi terkirim');

      // Simpan sementara di memory untuk re-login setelah verifikasi
      _tempEmail = email;
      _tempPassword = password;

      _status = AuthStatus.emailNotVerified;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE ERROR] Register gagal');
      debugPrint('│ Code   : ${e.code}');
      debugPrint('│ Message: ${e.message}');
      debugPrint('└─────────────────────────────────────────────');
      _setError(_mapFirebaseError(e.code));
      return false;
    }
  }

  // ─── Cek Persistent Auth (Startup/Deep Link) ────────────
  Future<void> checkPersistentAuth() async {
    try {
      final token = await SecureStorageService.getToken();
      final currentUser = _auth.currentUser;

      debugPrint('[AUTH] checkPersistentAuth | token: ${token != null ? "ada" : "null"} | firebaseUser: ${currentUser?.email}');

      if (token != null) {
        _backendToken = token;
        _firebaseUser = currentUser;
        if (currentUser != null && !currentUser.emailVerified) {
          _status = AuthStatus.emailNotVerified;
        } else {
          _status = AuthStatus.authenticated;
          NotificationService.updateFcmToken();
        }
      } else {
        _status = AuthStatus.unauthenticated;
        _backendToken = null;
        _firebaseUser = null;
      }
    } catch (e) {
      debugPrint('[AUTH] checkPersistentAuth error: $e');
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Login dengan Email & Password ──────────────────────
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading();
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ [FIREBASE REQUEST] signInWithEmailAndPassword');
    debugPrint('│ Email : $email');
    debugPrint('└─────────────────────────────────────────────');
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _firebaseUser = credential.user;
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE RESPONSE] Login berhasil');
      debugPrint('│ UID           : ${_firebaseUser?.uid}');
      debugPrint('│ Email         : ${_firebaseUser?.email}');
      debugPrint('│ EmailVerified : ${_firebaseUser?.emailVerified}');
      debugPrint('└─────────────────────────────────────────────');

      // Cek apakah email sudah diverifikasi
      if (!(_firebaseUser?.emailVerified ?? false)) {
        debugPrint(
          '[FIREBASE] Email belum diverifikasi → redirect verify page',
        );
        _status = AuthStatus.emailNotVerified;
        notifyListeners();
        return false;
      }

      return await _verifyTokenToBackend();
    } on FirebaseAuthException catch (e) {
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE ERROR] Login gagal');
      debugPrint('│ Code   : ${e.code}');
      debugPrint('│ Message: ${e.message}');
      debugPrint('└─────────────────────────────────────────────');
      _setError(_mapFirebaseError(e.code));
      return false;
    }
  }

  // ─── Login dengan Google ─────────────────────────────────
  Future<bool> loginWithGoogle() async {
    _setLoading();
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ [FIREBASE REQUEST] Google Sign-In');
    debugPrint('└─────────────────────────────────────────────');
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[FIREBASE]  Google Sign-In dibatalkan user');
        _setError('Login Google dibatalkan');
        return false;
      }
      debugPrint('[FIREBASE] Google account dipilih: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      debugPrint('[FIREBASE] Google auth token diperoleh');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      _firebaseUser = userCred.user;
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE RESPONSE] Google Login berhasil');
      debugPrint('│ UID           : ${_firebaseUser?.uid}');
      debugPrint('│ Email         : ${_firebaseUser?.email}');
      debugPrint('│ DisplayName   : ${_firebaseUser?.displayName}');
      debugPrint('│ EmailVerified : ${_firebaseUser?.emailVerified}');
      debugPrint('└─────────────────────────────────────────────');

      return await _verifyTokenToBackend();
    } catch (e) {
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE ERROR] Google Sign-In gagal');
      debugPrint('│ Error: $e');
      debugPrint('└─────────────────────────────────────────────');
      _setError('Gagal login dengan Google: $e');
      return false;
    }
  }

  // ─── Kirim Firebase Token ke Backend ────────────────────
  Future<bool> _verifyTokenToBackend() async {
    try {
      debugPrint('[FIREBASE] Mengambil ID Token dari Firebase...');
      final firebaseToken = await _firebaseUser?.getIdToken();
      if (firebaseToken == null) throw Exception('Token Firebase null');
      debugPrint(
        '[FIREBASE] ID Token diperoleh (${firebaseToken.length} chars)',
      );

      // DioClient interceptor akan log request/response ke backend
      final response = await DioClient.instance.post(
        ApiConstants.verifyToken,
        data: {'firebase_token': firebaseToken},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final backendToken = data['access_token'] as String;
      _backendToken = backendToken;

      await SecureStorageService.saveToken(backendToken);
      debugPrint('[AUTH] Backend JWT tersimpan di SecureStorage');

      _status = AuthStatus.authenticated;
      notifyListeners();

      // Register FCM token to backend after successful auth
      NotificationService.updateFcmToken();

      return true;
    } catch (e) {
      debugPrint('[AUTH] _verifyTokenToBackend gagal: $e');
      _setError('Gagal verifikasi ke server: $e');
      return false;
    }
  }

  // ─── Login ulang otomatis setelah email terkonfirmasi ───
  // Dipanggil saat user klik "Ya sudah konfirmasi" di VerifyEmailPage.
  // Alur: reload → cek emailVerified → re-login → fresh token → verify-token backend
  Future<bool> loginAfterEmailVerification() async {
    _setLoading();

    // Step 1: Reload user dari Firebase untuk dapat status emailVerified terbaru
    debugPrint('[FIREBASE] Reload user untuk cek emailVerified...');
    await _firebaseUser?.reload();
    _firebaseUser = _auth.currentUser;
    final verified = _firebaseUser?.emailVerified ?? false;
    debugPrint('[FIREBASE] emailVerified = $verified');

    if (!verified) {
      debugPrint('[FIREBASE] Email belum dikonfirmasi');
      _status = AuthStatus.emailNotVerified;
      notifyListeners();
      return false;
    }

    // Step 2: Re-login dengan kredensial tersimpan untuk mendapat fresh session
    if (_tempEmail == null || _tempPassword == null) {
      debugPrint('[AUTH] Kredensial tidak tersedia, pakai token lama');
      return await _verifyTokenToBackend();
    }

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ [FIREBASE REQUEST] Re-login setelah verifikasi');
    debugPrint('│ Email : $_tempEmail');
    debugPrint('└─────────────────────────────────────────────');

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _tempEmail!,
        password: _tempPassword!,
      );
      _firebaseUser = credential.user;
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE RESPONSE] Re-login berhasil');
      debugPrint('│ UID           : ${_firebaseUser?.uid}');
      debugPrint('│ Email         : ${_firebaseUser?.email}');
      debugPrint('│ EmailVerified : ${_firebaseUser?.emailVerified}');
      debugPrint('└─────────────────────────────────────────────');

      // Hapus kredensial sementara setelah dipakai
      _tempEmail = null;
      _tempPassword = null;

      // Step 3: Kirim fresh Firebase token ke backend → dapat JWT
      return await _verifyTokenToBackend();
    } on FirebaseAuthException catch (e) {
      debugPrint('┌─────────────────────────────────────────────');
      debugPrint('│ [FIREBASE ERROR] Re-login gagal');
      debugPrint('│ Code   : ${e.code}');
      debugPrint('│ Message: ${e.message}');
      debugPrint('└─────────────────────────────────────────────');
      _setError(_mapFirebaseError(e.code));
      return false;
    }
  }

  // ─── Kirim ulang email verifikasi ───────────────────────
  Future<void> resendVerificationEmail() async {
    debugPrint(
      '[FIREBASE] Resend verification email → ${_firebaseUser?.email}',
    );
    await _firebaseUser?.sendEmailVerification();
    debugPrint('[FIREBASE] Email verifikasi dikirim ulang');
  }

  // ─── Cek status verifikasi email (polling) ───────────────
  Future<bool> checkEmailVerified() async {
    debugPrint('[FIREBASE] Polling: reload user dari Firebase...');
    await _firebaseUser?.reload();
    _firebaseUser = _auth.currentUser;
    final verified = _firebaseUser?.emailVerified ?? false;
    debugPrint('[FIREBASE] emailVerified = $verified');

    if (verified) {
      debugPrint('[FIREBASE] Email sudah verified → lanjut ke backend');
      return await _verifyTokenToBackend();
    }
    debugPrint('[FIREBASE] Email belum verified, polling lanjut...');
    return false;
  }

  // ─── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    debugPrint('[AUTH] Logout...');
    await _auth.signOut();
    await _googleSignIn.signOut();
    await SecureStorageService.clearAll();
    _firebaseUser = null;
    _backendToken = null;
    _tempEmail = null;
    _tempPassword = null;
    _status = AuthStatus.unauthenticated;
    debugPrint('[AUTH] Logout berhasil, token dihapus');
    notifyListeners();
  }

  // ─── Private Helpers ────────────────────────────────────
  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    debugPrint('[AUTH] Error: $message');
    notifyListeners();
  }

  String _mapFirebaseError(String code) => switch (code) {
    'email-already-in-use' => 'Email sudah terdaftar. Gunakan email lain.',
    'user-not-found' => 'Akun tidak ditemukan. Silakan daftar.',
    'wrong-password' => 'Password salah. Coba lagi.',
    'invalid-credential' => 'Email atau password salah.',
    'invalid-email' => 'Format email tidak valid.',
    'weak-password' => 'Password terlalu lemah. Minimal 6 karakter.',
    'network-request-failed' => 'Tidak ada koneksi internet.',
    _ => 'Terjadi kesalahan. Coba lagi.',
  };
}
