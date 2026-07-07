import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerFormDialog extends StatefulWidget {
  final String outletId;
  final DocumentSnapshot? customer;

  const CustomerFormDialog({super.key, required this.outletId, this.customer});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.customer?['name'] ?? '',
    );

    phoneController = TextEditingController(
      text: widget.customer?['phone'] ?? '',
    );

    addressController = TextEditingController(
      text: widget.customer?['address'] ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> saveCustomer() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama pelanggan wajib diisi')),
      );
      return;
    }

    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nomor HP wajib diisi')));
      return;
    }

    // Validasi format nomor HP Indonesia: awalan 08 atau +62, 9-13 digit
    final phoneRegex = RegExp(r'^(08|\+628)[0-9]{7,11}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Format nomor HP tidak valid. Gunakan awalan 08 atau +628, contoh: 081234567890',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final data = {
      'name': nameController.text.trim(),
      'phone': phone,
      'address': addressController.text.trim(),
      'total_orders': 0,
      'total_spending': 0,
      'created_at': Timestamp.now(),
    };

    try {
      if (widget.customer == null) {
        await FirebaseFirestore.instance
            .collection('outlets')
            .doc(widget.outletId)
            .collection('customers')
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('outlets')
            .doc(widget.outletId)
            .collection('customers')
            .doc(widget.customer!.id)
            .update({
              'name': nameController.text.trim(),
              'phone': phone,
              'address': addressController.text.trim(),
            });
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan pelanggan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan',
        style: TextStyle(color: Color(0xFF152C4A)),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  hintText: 'Contoh: 081234567890',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : saveCustomer,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
