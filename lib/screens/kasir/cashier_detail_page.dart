import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_cashier_page.dart';

class CashierDetailPage extends StatefulWidget {
  final String outletId;
  final DocumentSnapshot cashier;

  const CashierDetailPage({
    super.key,
    required this.outletId,
    required this.cashier,
  });

  @override
  State<CashierDetailPage> createState() => _CashierDetailPageState();
}

class _CashierDetailPageState extends State<CashierDetailPage> {
  late Map<String, dynamic> cashierData;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    cashierData = widget.cashier.data() as Map<String, dynamic>? ?? {};
  }

  Future<void> _refreshData() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('outlets')
            .doc(widget.outletId)
            .collection('cashiers')
            .doc(widget.cashier.id)
            .get();

    if (mounted) {
      setState(() {
        cashierData = doc.data() as Map<String, dynamic>? ?? {};
      });
    }
  }

  Future<void> _deleteCashier() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Kasir'),
            content: const Text('Yakin ingin menghapus kasir ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('outlets')
          .doc(widget.outletId)
          .collection('cashiers')
          .doc(widget.cashier.id)
          .delete();

      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _toggleActive() async {
    final current = cashierData['isActive'] ?? true;
    await FirebaseFirestore.instance
        .collection('outlets')
        .doc(widget.outletId)
        .collection('cashiers')
        .doc(widget.cashier.id)
        .update({'isActive': !current});

    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final name = cashierData['name']?.toString() ?? '-';
    final phone = cashierData['phone']?.toString() ?? '-';
    final cashier_id = cashierData['cashier_id']?.toString() ?? '-';
    final role = cashierData['role']?.toString() ?? '-';
    final isActive = cashierData['isActive'] ?? true;
    final createdAt = cashierData['created_at'];
    final createdAtLabel =
        createdAt is Timestamp
            ? DateFormat('dd MMM yyyy HH:mm').format(createdAt.toDate())
            : '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Kasir'),
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('ID: $cashier_id'),
                    const SizedBox(height: 6),
                    Text('No. Telp: $phone'),
                    const SizedBox(height: 6),
                    Text('Role: $role'),
                    const SizedBox(height: 6),
                    Text('Status: ${isActive ? 'Active' : 'Non Active'}'),
                    const SizedBox(height: 6),
                    Text('Dibuat: $createdAtLabel'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AddCashierPage(cashier: widget.cashier),
                        ),
                      );
                      await _refreshData();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: _deleteCashier,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(
                  isActive ? Icons.toggle_on : Icons.toggle_off,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                label: Text(isActive ? 'Set Non Active' : 'Set Active'),
                onPressed: _toggleActive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
