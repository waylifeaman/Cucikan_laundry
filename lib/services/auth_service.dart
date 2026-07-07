import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthResult {
  final bool success;
  final String message;
  final User? user;

  const AuthResult({required this.success, required this.message, this.user});
}

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 1. FUNGSI GENERATE KODE OUTLET (Bawaan Anda)
  Future<String> _generateUniqueOutletCode() async {
    final rand = Random();
    const maxAttempts = 1000;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final n = rand.nextInt(999) + 1; // 1..999
      final code = 'A${n.toString().padLeft(3, '0')}';

      final snap = await _firestore
          .collection('outlets')
          .where('outlet_code', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return code;
    }

    throw Exception('Unable to generate unique outlet code');
  }

  /// 2. REGISTRASI VIA EMAIL AKTIF + VERIFIKASI (Resmi & Aman)
  Future<AuthResult> registerWithEmail({
    required String outletName,
    required String ownerName,
    required String email,
    required String phone,
    required String address,
    required String password,
  }) async {
    try {
      // Langkah A: Daftarkan akun di Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        // Langkah B: Kirim Link Verifikasi ke Email Aktif User
        await user.sendEmailVerification();

        // Langkah C: Generate kode unik outlet
        final outletCode = await _generateUniqueOutletCode();

        // Langkah D: Simpan data pelengkap ke Firestore menggunakan UID dari Auth sebagai ID dokumen
        await _firestore.collection('outlets').doc(user.uid).set({
          'uid': user.uid,
          'name': outletName,
          'owner_name': ownerName,
          'email': email,
          'phone': phone,
          'address': address,
          'isActive': true,
          'subscription': 'trial',
          'created_at': Timestamp.now(),
          'trial_end_date': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'outlet_code': outletCode,
          'auth_method': 'email', // Penanda metode daftar
        });

        return const AuthResult(
          success: true,
          message:
              'Registrasi sukses! Silakan cek email Anda untuk verifikasi.',
        );
      }
      return const AuthResult(
        success: false,
        message: 'Registrasi gagal, silakan coba lagi.',
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registrasi gagal.';
      if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage =
            'Email sudah terdaftar. Silakan login atau gunakan email lain.';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Pendaftaran email belum diaktifkan di Firebase.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      print("Error Register Email: $e");
      return AuthResult(success: false, message: errorMessage);
    } catch (e) {
      print("Error Register Email: $e");
      return AuthResult(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  /// 3. REGISTRASI / LOGIN VIA GOOGLE (DINONAKTIFKAN)
  Future<AuthResult> registerWithGoogle({
    String? phone,
    String? address,
    String? outletName,
  }) async {
    return const AuthResult(
      success: false,
      message: 'Login Google saat ini tidak tersedia.',
    );
  }
}
