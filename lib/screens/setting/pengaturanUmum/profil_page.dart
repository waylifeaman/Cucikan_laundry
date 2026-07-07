import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/services/session_service.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _outletNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = true;
  String _outletId = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _outletNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final outletId = await SessionService.getOutletId();
    if (outletId.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final document = await FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .get();
    final data = document.data();

    if (!mounted) return;
    setState(() {
      _outletId = outletId;
      _ownerNameController.text = data?['owner_name']?.toString() ?? '';
      _outletNameController.text = data?['name']?.toString() ?? '';
      _addressController.text = data?['address']?.toString() ?? '';
      _phoneController.text = data?['phone']?.toString() ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_outletId.isEmpty) return;

    setState(() => _isLoading = true);

    await FirebaseFirestore.instance
        .collection('outlets')
        .doc(_outletId)
        .update({
          'owner_name': _ownerNameController.text.trim(),
          'name': _outletNameController.text.trim(),
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
        });

    final currentOutletCode = await SessionService.getOutletCode();

    await SessionService.saveLogin(
      outletId: _outletId,
      userId: await SessionService.getOutletId(),
      userName: _ownerNameController.text.trim(),
      role: await SessionService.getRole(),
      outletName: _outletNameController.text.trim(),
      outletCode: currentOutletCode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data profil berhasil diperbarui')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan Profil',
          style: TextStyle(
            color: Color(0xFF152C4A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.amber,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      'Data Pemilik & Laundry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF152C4A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _ownerNameController,
                      label: 'Nama Owner',
                      hint: 'Masukkan nama pemilik',
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _outletNameController,
                      label: 'Nama Laundry',
                      hint: 'Masukkan nama laundry',
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Alamat Laundry',
                      hint: 'Masukkan alamat lengkap',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'No. Telepon',
                      hint: 'Masukkan nomor telepon',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saveProfile,
                      child: const Text('Simpan Perubahan'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: Color(0xFF152C4A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label tidak boleh kosong';
        }
        return null;
      },
    );
  }
}
