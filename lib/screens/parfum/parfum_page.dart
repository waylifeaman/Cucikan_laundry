import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/session_service.dart';

class ParfumPage extends StatefulWidget {
  const ParfumPage({super.key});

  @override
  State<ParfumPage> createState() => _ParfumPageState();
}

class _ParfumPageState extends State<ParfumPage> {
  String outletId = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOutlet();
  }

  Future<void> _loadOutlet() async {
    outletId = await SessionService.getOutletId();
    setState(() {});
  }

  Future<void> _saveParfum({DocumentSnapshot? parfum}) async {
    final name = _formNameController.text.trim();
    final priceText = _formPriceController.text.trim();
    final price =
        int.tryParse(priceText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (name.isEmpty) {
      return;
    }

    final data = {
      'name': name,
      'price': price,
      'created_at': parfum == null
          ? Timestamp.now()
          : parfum['created_at'] ?? Timestamp.now(),
    };

    final collection = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('parfums');

    if (parfum == null) {
      await collection.add(data);
    } else {
      await collection.doc(parfum.id).update(data);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _deleteParfum(DocumentSnapshot parfum) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Parfum'),
        content: const Text('Yakin ingin menghapus parfum ini?'),
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
          .doc(outletId)
          .collection('parfums')
          .doc(parfum.id)
          .delete();
    }
  }

  final TextEditingController _formNameController = TextEditingController();
  final TextEditingController _formPriceController = TextEditingController();

  void _openParfumForm({DocumentSnapshot? parfum}) {
    if (parfum != null) {
      final data = parfum.data() as Map<String, dynamic>? ?? {};
      _formNameController.text = data['name']?.toString() ?? '';
      _formPriceController.text = data['price']?.toString() ?? '';
    } else {
      _formNameController.clear();
      _formPriceController.clear();
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          parfum == null ? 'Tambah Parfum' : 'Edit Parfum',
          style: TextStyle(color: Color(0xFF152C4A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _formNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Parfum',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _formPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveParfum(parfum: parfum);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(price);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Parfum', style: TextStyle(color: Color(0xFF152C4A))),
        backgroundColor: Colors.amber,
      ),
      body: outletId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari parfum...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF152C4A),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('outlets')
                        .doc(outletId)
                        .collection('parfums')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        final name =
                            data?['name']?.toString().toLowerCase() ?? '';
                        final query = searchController.text.toLowerCase();
                        return query.isEmpty || name.contains(query);
                      }).toList();

                      if (docs.isEmpty) {
                        return const Center(child: Text('Belum ada parfum'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final parfum = docs[index];
                          final data = parfum.data() as Map<String, dynamic>?;
                          final name = data?['name']?.toString() ?? '-';
                          final price = data?['price'] is num
                              ? (data?['price'] as num).toInt()
                              : int.tryParse(
                                      data?['price']?.toString() ?? '',
                                    ) ??
                                    0;

                          return Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF152C4A),
                                ),
                              ),
                              subtitle: Text(_formatPrice(price)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () =>
                                        _openParfumForm(parfum: parfum),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteParfum(parfum),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add),
        onPressed: () => _openParfumForm(),
      ),
    );
  }
}
