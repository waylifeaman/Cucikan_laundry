import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/services/session_service.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _outletData;
  String _outletId = '';

  // Controller untuk Form Edit
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 1. Ambil Data Akun dari Firestore
  Future<void> _loadAccountData() async {
    setState(() => _isLoading = true);
    try {
      _outletId = await SessionService.getOutletId();
      if (_outletId.isEmpty) throw Exception('Silakan login terlebih dahulu');

      final snapshot = await FirebaseFirestore.instance
          .collection('outlets')
          .doc(_outletId)
          .get();

      if (snapshot.exists) {
        _outletData = snapshot.data();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. Hitung Sisa Hari Langganan
  int _calculateRemainingDays(dynamic expiryData) {
    if (expiryData == null) return 0;
    DateTime expiryDate;
    if (expiryData is Timestamp) {
      expiryDate = expiryData.toDate();
    } else {
      return 0;
    }
    final difference = expiryDate.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }

  // 3. Logika Ubah Email via Dialog
  Future<void> _changeEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('outlets')
          .doc(_outletId)
          .update({'email': newEmail});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email berhasil diperbarui')),
      );
      _loadAccountData(); // Refresh tampilan
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengubah email: $e')));
    }
  }

  // 4. Logika Ubah Password via Dialog
  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Semua kolom harus diisi')));
      return;
    }

    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password baru minimal 8 karakter')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi password tidak cocok')),
      );
      return;
    }

    try {
      final storedPassword = _outletData?['password'] as String?;
      if (storedPassword != currentPassword) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password lama salah')));
        return;
      }

      await FirebaseFirestore.instance
          .collection('outlets')
          .doc(_outletId)
          .update({'password': newPassword});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diperbarui')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengubah password: $e')));
    }
  }

  // ==================== TAMPILAN DIALOGS ====================
  void _showEditEmailDialog() {
    _emailController.text = _outletData?['email'] ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Email'),
        content: TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email Baru'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: _changeEmail,
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: 'Password Lama'),
                obscureText: true,
              ),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Password Baru (min 8 karakter)',
                ),
                obscureText: true,
              ),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: _changePassword,
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ==================== UTAMA BUILD ====================
  @override
  Widget build(BuildContext context) {
    final remainingDays = _calculateRemainingDays(
      _outletData?['subscription_expires'],
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Akun',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF152C4A),
          ),
        ),
        backgroundColor: Colors.amber,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Kredensial Akun',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),

                // Card Utama Akun (Email & Password)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email, color: Colors.amber),
                          title: const Text(
                            'Email',
                            style: TextStyle(color: Color(0xFF152C4A)),
                          ),
                          subtitle: Text(
                            _outletData?['email'] ?? 'Tidak ada email',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            onPressed: _showEditEmailDialog,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock, color: Colors.amber),
                          title: const Text(
                            'Password',
                            style: TextStyle(color: Color(0xFF152C4A)),
                          ),
                          subtitle: const Text('••••••••••••'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            onPressed: _showEditPasswordDialog,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // const Text(
                //   'Informasi Langganan / Kredit',
                //   style: TextStyle(
                //     fontSize: 16,
                //     fontWeight: FontWeight.bold,
                //     color: Colors.black54,
                //   ),
                // ),
                // const SizedBox(height: 10),

                // // Card Informasi Sisa Masa Aktif Kredit
                // Card(
                //   shape: RoundedRectangleBorder(
                //     borderRadius: BorderRadius.circular(14),
                //   ),
                //   elevation: 2,
                //   color:
                //       remainingDays <= 3
                //           ? Colors.red.shade50
                //           : Colors.amber.shade50,
                //   child: Padding(
                //     padding: const EdgeInsets.all(20.0),
                //     child: Row(
                //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //       children: [
                //         Column(
                //           crossAxisAlignment: CrossAxisAlignment.start,
                //           children: [
                //             const Text(
                //               'Sisa Masa Aktif Langganan',
                //               style: TextStyle(
                //                 fontSize: 14,
                //                 color: Colors.black54,
                //               ),
                //             ),
                //             const SizedBox(height: 4),
                //             Text(
                //               _outletData?['subscription_expires'] != null
                //                   ? DateFormat('dd MMMM yyyy').format(
                //                     (_outletData!['subscription_expires']
                //                             as Timestamp)
                //                         .toDate(),
                //                   )
                //                   : '-',
                //               style: const TextStyle(
                //                 fontSize: 13,
                //                 fontWeight: FontWeight.w500,
                //                 color: Colors.black87,
                //               ),
                //             ),
                //           ],
                //         ),
                //         Container(
                //           padding: const EdgeInsets.symmetric(
                //             horizontal: 16,
                //             vertical: 10,
                //           ),
                //           decoration: BoxDecoration(
                //             color:
                //                 remainingDays <= 3
                //                     ? Colors.red
                //                     : Colors.amber.shade700,
                //             borderRadius: BorderRadius.circular(12),
                //           ),
                //           child: Text(
                //             '$remainingDays Hari',
                //             style: const TextStyle(
                //               fontSize: 18,
                //               fontWeight: FontWeight.bold,
                //               color: Colors.white,
                //             ),
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
              ],
            ),
    );
  }
}
