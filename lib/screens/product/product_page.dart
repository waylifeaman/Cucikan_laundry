import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_form_dialog.dart';
import '../../services/session_service.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  String outletId = '';
  String searchQuery = '';

  Future<void> deleteProduct(String productId) async {
    await FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('products')
        .doc(productId)
        .update({'isDeleted': true});
  }

  @override
  void initState() {
    super.initState();
    loadOutlet();
  }

  Future<void> loadOutlet() async {
    outletId = await SessionService.getOutletId();

    setState(() {});
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Cari produk...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF152C4A)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Produk", style: TextStyle(color: Color(0xFF152C4A))),
        backgroundColor: Colors.amber,
      ),

      body: outletId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('outlets')
                  .doc(outletId)
                  .collection('products')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data!.docs
                    .where(
                      (doc) =>
                          !(doc.data()
                              as Map<String, dynamic>?)?['isDeleted'] ==
                          true,
                    )
                    .where((doc) {
                      if (searchQuery.isEmpty) return true;
                      final productData = doc.data() as Map<String, dynamic>?;
                      final name =
                          productData?['name']?.toString().toLowerCase() ?? '';
                      final type =
                          productData?['product_type']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      final query = searchQuery.toLowerCase();
                      return name.contains(query) || type.contains(query);
                    })
                    .toList();

                if (products.isEmpty) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildSearchBar(),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Produk tidak ditemukan',
                            style: TextStyle(color: Color(0xFF152C4A)),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildSearchBar(),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final productData =
                              product.data() as Map<String, dynamic>;
                          final name = productData['name']?.toString() ?? '-';
                          final productType =
                              productData['product_type']?.toString() ?? '-';
                          final regularPrice =
                              productData['regular_price']?.toString() ?? '-';
                          final expressPrice =
                              productData['express_price']?.toString() ?? '-';
                          final kilatPrice =
                              productData['kilat_price']?.toString() ?? '-';

                          return Card(
                            color: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF152C4A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          productType,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF152C4A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Reguler: Rp $regularPrice',
                                          style: TextStyle(
                                            color: Color(0xFF152C4A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Express: Rp $expressPrice',
                                          style: TextStyle(
                                            color: Color(0xFF152C4A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Kilat: Rp $kilatPrice',
                                          style: TextStyle(
                                            color: Color(0xFF152C4A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => ProductFormDialog(
                                              outletId: outletId,
                                              product: product,
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final confirm = await showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Hapus Produk'),
                                              content: const Text(
                                                'Yakin ingin menghapus produk ini?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Batal'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('Hapus'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            deleteProduct(product.id);
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => ProductFormDialog(outletId: outletId),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
