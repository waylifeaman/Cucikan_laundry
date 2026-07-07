import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddCashierPage extends StatefulWidget {
  final DocumentSnapshot? cashier;

  const AddCashierPage({super.key, this.cashier});

  @override
  State<AddCashierPage> createState() => _AddCashierPageState();
}

class _AddCashierPageState extends State<AddCashierPage> {
  final _cashierIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool isActive = true;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.cashier != null) {
      final data = widget.cashier!.data() as Map<String, dynamic>? ?? {};
      _cashierIdController.text = data['cashier_id']?.toString() ?? 'K01';
      _nameController.text = data['name']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      isActive = data['isActive'] ?? true;
    }
    _loadNextCashierId();
  }

  Future<void> _loadNextCashierId() async {
    if (widget.cashier != null) return;

    final prefs = await SharedPreferences.getInstance();
    final outletId = prefs.getString('outletId');
    if (outletId == null || outletId.isEmpty) {
      _cashierIdController.text = 'K01';
      return;
    }

    final collection = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('cashiers');

    final query = await collection
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      _cashierIdController.text = 'K01';
      return;
    }

    final lastCashier = query.docs.first.data();
    final lastId = lastCashier['cashier_id']?.toString() ?? '';
    final nextId = _nextCashierId(lastId);

    if (!mounted) return;
    setState(() {
      _cashierIdController.text = nextId;
    });
  }

  String _nextCashierId(String lastId) {
    if (!lastId.startsWith('K')) return 'K01';
    final numericPart = int.tryParse(lastId.substring(1)) ?? 0;
    return 'K${(numericPart + 1).toString().padLeft(2, '0')}';
  }

  Future<String> _generateUniqueCashierId(String outletId) async {
    final collection = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('cashiers');

    final query = await collection
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return 'K01';
    }

    final lastCashier = query.docs.first.data();
    final lastId = lastCashier['cashier_id']?.toString() ?? '';
    return _nextCashierId(lastId);
  }

  Future<void> saveCashier() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();

    final outletId = prefs.getString('outletId');
    final collection = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('cashiers');

    final cashierId = widget.cashier == null
        ? await _generateUniqueCashierId(outletId!)
        : _cashierIdController.text.trim();

    final data = {
      'cashier_id': cashierId,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'role': 'cashier',
      'isActive': isActive,
      'created_at': Timestamp.now(),
    };

    if (widget.cashier == null) {
      await collection.add(data);
    } else {
      await collection.doc(widget.cashier!.id).update(data);
    }

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Tambah Kasir",
          style: TextStyle(color: Color(0xFF152C4A)),
        ),
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              controller: _cashierIdController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'ID Kasir',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Kasir'),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                const Text(
                  'Status Aktif',
                  style: TextStyle(color: Color(0xFF152C4A)),
                ),
                const Spacer(),
                Switch(
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveCashier,
                child: const Text("SIMPAN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
