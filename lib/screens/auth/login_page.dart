import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../home/dashboard_page.dart';
import '../../services/session_service.dart';

class LoginOwnerPage extends StatefulWidget {
  const LoginOwnerPage({super.key});

  @override
  State<LoginOwnerPage> createState() => _LoginOwnerPageState();
}

class _LoginOwnerPageState extends State<LoginOwnerPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1. LOGIN KE FIREBASE AUTHENTICATION
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      User? user = userCredential.user;

      if (user != null) {
        // 2. CEK APAKAH EMAIL SUDAH DIVERIFIKASI
        if (!user.emailVerified) {
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;
          setState(() => isLoading = false);
          _showUnverifiedDialog();
          return;
        }

        // 3. AMBIL DATA OUTLET DARI FIRESTORE MENGGUNAKAN UID
        final outletDoc = await FirebaseFirestore.instance
            .collection('outlets')
            .doc(user.uid)
            .get();

        if (!outletDoc.exists) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data outlet tidak ditemukan.')),
          );
          setState(() => isLoading = false);
          return;
        }

        final outletData = outletDoc.data();

        // 4. CEK APAKAH OUTLET AKTIF
        if (outletData?['isActive'] == false) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Outlet tidak aktif')));
          setState(() => isLoading = false);
          return;
        }

        // 5. SIMPAN DATA KE SESSION / LOCAL STORAGE
        await SessionService.saveLogin(
          outletId: outletDoc.id,
          userId: outletDoc.id,
          userName: outletData?['owner_name'] ?? '',
          role: 'owner',
          outletName: outletData?['name'] ?? '',
          outletCode: outletData?['outlet_code'] ?? '',
        );

        if (!mounted) return;

        // 6. MASUK KE DASHBOARD
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Email atau Password salah';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid';
      } else {
        errorMessage = e.message ?? errorMessage;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showUnverifiedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Belum Diverifikasi'),
        content: const Text(
          'Akun Anda belum diverifikasi. Silakan cek inbox atau folder spam email Anda untuk link verifikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () => _resendVerificationEmail(context),
            child: const Text('Kirim Ulang'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail(BuildContext dialogContext) async {
    try {
      // Login ulang sementara untuk bisa mengirim ulang verifikasi
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await cred.user?.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verifikasi telah dikirim ulang.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengirim ulang: $e')));
    }
  }

  Future<void> _loginWithGoogle() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    AuthResult result = await _authService.registerWithGoogle();

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    if (result.success && result.user != null) {
      User user = result.user!;

      final outletDoc = await FirebaseFirestore.instance
          .collection('outlets')
          .doc(user.uid)
          .get();

      if (!outletDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data outlet tidak ditemukan.')),
        );
        return;
      }

      final outletData = outletDoc.data();
      if (outletData?['isActive'] == false) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Outlet tidak aktif')));
        return;
      }

      await SessionService.saveLogin(
        outletId: outletDoc.id,
        userId: outletDoc.id,
        userName: outletData?['owner_name'] ?? '',
        role: 'owner',
        outletName: outletData?['name'] ?? '',
        outletCode: outletData?['outlet_code'] ?? '',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan email Anda untuk reset password.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Link reset password telah dikirim ke email Anda. Silakan cek inbox/spam.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Gagal mengirim reset password.';
      if (e.code == 'invalid-email') {
        errorMessage = 'Format email tidak valid.';
      } else if (e.code == 'user-not-found') {
        errorMessage =
            'Email tidak ditemukan. Pastikan email yang digunakan benar.';
      } else {
        errorMessage = e.message ?? errorMessage;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo2.png', height: 80),
                const SizedBox(height: 20),
                const Text(
                  "LOGIN OWNER",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF152C4A),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("MASUK"),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : _resetPassword,
                    child: const Text(
                      'Lupa Password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text(
                    'Belum punya Outlet? Daftar di sini',
                    style: TextStyle(color: Color(0xFF152C4A)),
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
