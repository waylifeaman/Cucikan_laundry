import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/session_service.dart';
import 'rincian_pesanan_page.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String outletId = '';
  bool isLoading = false;

  // State Pelanggan
  final TextEditingController _customerSearchController =
      TextEditingController();
  DocumentSnapshot? selectedCustomer;
  List<DocumentSnapshot> allCustomers = [];
  List<DocumentSnapshot> filteredCustomers = [];
  bool showCustomerSuggestions = false;

  // State Produk & Keranjang Belanja
  List<DocumentSnapshot> allProducts = [];
  Map<String, Map<String, dynamic>> cart =
      {}; // Struktur: { productId: { 'doc': doc, 'qty': 2, 'unitPrice': 5000, 'service': 'regular' } }

  // State Tambahan
  String selectedPerfume = 'No Perfume';
  int perfumePrice = 0;
  String paymentStatus = 'Belum Bayar';

  // Daftar Parfum dari Firestore
  List<Map<String, dynamic>> perfumeList = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => isLoading = true);
    outletId = await SessionService.getOutletId();
    if (outletId.isNotEmpty) {
      await _fetchCustomers();
      await _fetchProducts();
      await _fetchPerfumes();
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchPerfumes() async {
    final snap = await FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('parfums')
        .orderBy('name')
        .get();

    perfumeList = snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'name': data['name'] ?? 'Unknown', 'price': data['price'] ?? 0};
    }).toList();

    if (perfumeList.isNotEmpty) {
      selectedPerfume = perfumeList.first['name'] as String;
      perfumePrice = perfumeList.first['price'] as int;
    } else {
      selectedPerfume = 'No Perfume';
      perfumePrice = 0;
      perfumeList = [
        {'name': 'No Perfume', 'price': 0},
      ];
    }
  }

  Future<void> _fetchCustomers() async {
    final snap = await FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('customers')
        .orderBy('name')
        .get();
    allCustomers = snap.docs;
  }

  Future<void> _fetchProducts() async {
    final snap = await FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('products')
        .get();
    // Ambil produk yang tidak dihapus secara lokal
    allProducts = snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['isDeleted'] == false || !data.containsKey('isDeleted');
    }).toList();
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredCustomers = [];
        showCustomerSuggestions = false;
      });
      return;
    }

    setState(() {
      filteredCustomers = allCustomers.where((doc) {
        final name = (doc['name'] as String).toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
      showCustomerSuggestions = true;
    });
  }

  int getPriceForService(Map<String, dynamic> product, String service) {
    switch (service) {
      case 'express':
        return product['express_price'] ?? 0;
      case 'kilat':
        return product['kilat_price'] ?? 0;
      default:
        return product['regular_price'] ?? 0;
    }
  }

  int calculateTotal() {
    int total = 0;
    cart.forEach((key, item) {
      total += ((item['qty'] as double) * (item['unitPrice'] as int)).toInt();
    });
    total += perfumePrice;
    return total;
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  Future<String> _generateInvoiceNo() async {
    final now = DateTime.now();
    final datePrefix =
        '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
    final counterRef = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('order_counters')
        .doc(datePrefix);

    final invoiceNo = await FirebaseFirestore.instance.runTransaction((
      transaction,
    ) async {
      final snapshot = await transaction.get(counterRef);
      final nextOrderNo = snapshot.exists
          ? ((snapshot.get('count') as int? ?? 0) + 1)
          : 1;

      if (snapshot.exists) {
        transaction.update(counterRef, {'count': nextOrderNo});
      } else {
        transaction.set(counterRef, {
          'count': nextOrderNo,
          'date': Timestamp.now(),
        });
      }

      return 'INV-$datePrefix-$nextOrderNo';
    });

    return invoiceNo;
  }

  // --- POP UP FORM INPUT JUMLAH (KG / PCS) ---
  void _showQtyDialog(DocumentSnapshot productDoc, String service) {
    final productData = productDoc.data() as Map<String, dynamic>;
    final isKiloan = productData['product_type'] == 'Kiloan';
    final label = isKiloan ? 'Berat (Kg)' : 'Jumlah (Pcs)';

    final TextEditingController qtyInputController = TextEditingController(
      text: '1',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Masukkan ${productData['name']} (${service.toUpperCase()})',
        ),
        content: TextField(
          controller: qtyInputController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              final inputQty = double.tryParse(qtyInputController.text) ?? 0.0;
              if (inputQty <= 0) return;

              final uPrice = getPriceForService(productData, service);

              setState(() {
                cart[productDoc.id] = {
                  'doc': productDoc,
                  'qty': inputQty,
                  'unitPrice': uPrice,
                  'service': service,
                };
              });
              Navigator.pop(context);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  // --- POP UP TAMBAH CUSTOMER BARU ---
  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Pelanggan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Alamat',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context);
              setState(() => isLoading = true);

              try {
                final newCustomerRef = await FirebaseFirestore.instance
                    .collection('outlets')
                    .doc(outletId)
                    .collection('customers')
                    .add({
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'address': addressController.text.trim(),
                      'total_orders': 0,
                      'total_spending': 0,
                      'created_at': Timestamp.now(),
                    });

                await _fetchCustomers(); // Refresh list lokal
                final newDoc = await newCustomerRef.get();

                setState(() {
                  selectedCustomer = newDoc;
                  _customerSearchController.text = newDoc['name'];
                  showCustomerSuggestions = false;
                });
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
              }
              setState(() => isLoading = false);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- FUNGI SIMPAN ORDER ---
  Future<void> saveOrder() async {
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelanggan terlebih dahulu')),
      );
      return;
    }
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang belanja masih kosong')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final customerData = selectedCustomer!.data() as Map<String, dynamic>;
      final invoiceNo = await _generateInvoiceNo();
      final userName = await SessionService.getUserName();
      final finalTotal = calculateTotal();

      // Membuat list ringkasan item belanjaan
      List<Map<String, dynamic>> itemsSummary = [];
      cart.forEach((key, item) {
        final pData = item['doc'].data() as Map<String, dynamic>;
        itemsSummary.add({
          'product_id': key,
          'product_name': pData['name'],
          'product_type': pData['product_type'],
          'qty': item['qty'],
          'price_per_unit': item['unitPrice'],
          'service_type': item['service'],
        });
      });

      // WADAHI DATA KE DALAM VARIABEL MAP AGAR BISA DIKIRIM KE HALAMAN RINCIAN
      final Map<String, dynamic> orderData = {
        'invoice_no': invoiceNo,
        'customer_id': selectedCustomer!.id,
        'customer_name': customerData['name'],
        'customer_phone': customerData['phone'],
        'customer_address':
            customerData['address'] ?? '-', // Sesuaikan field alamat di DB-mu
        'items': itemsSummary,
        'perfume': selectedPerfume,
        'perfume_price': perfumePrice,
        'total_price': finalTotal,
        'payment_status': paymentStatus,
        'status': 'Baru',
        'created_by': userName,
        'created_at': Timestamp.now(),
      };

      // 1. Simpan Transaksi Utama ke Firestore menggunakan variabel orderData
      await FirebaseFirestore.instance
          .collection('outlets')
          .doc(outletId)
          .collection('orders')
          .add(orderData);

      // 2. Akumulasi Data Pengeluaran Customer
      await FirebaseFirestore.instance
          .collection('outlets')
          .doc(outletId)
          .collection('customers')
          .doc(selectedCustomer!.id)
          .update({
            'total_orders': FieldValue.increment(1),
            'total_spending': FieldValue.increment(finalTotal),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order berhasil disimpan!')));

      // 3. SEKARANG 'orderData' SUDAH TERDEFINISIKAN DAN BISA DIKIRIM
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RincianPesananPage(orderData: orderData),
        ),
      );

      // [DIHAPUS]: Navigator.pop(context) dibuang agar halaman rincian tidak langsung tertutup otomatis.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Transaksi Laundry',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.amber,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.black45,
            indicatorColor: Colors.black87,
            tabs: [
              Tab(text: 'Reguler'),
              Tab(text: 'Express'),
              Tab(text: 'Kilat'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: SEARCH & INPUT PELANGGAN ---
                    const Text(
                      'Data Pelanggan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customerSearchController,
                            decoration: InputDecoration(
                              hintText: 'Cari nama customer...',
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              suffixIcon:
                                  _customerSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _customerSearchController.clear();
                                        setState(() {
                                          selectedCustomer = null;
                                          _filterCustomers('');
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: _filterCustomers,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                            onPressed: _showAddCustomerDialog,
                          ),
                        ),
                      ],
                    ),

                    // Live Suggestion List Pelanggan
                    if (showCustomerSuggestions && filteredCustomers.isNotEmpty)
                      Card(
                        elevation: 4,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final doc = filteredCustomers[index];
                            return ListTile(
                              title: Text(doc['name']),
                              subtitle: Text(doc['phone'] ?? '-'),
                              onTap: () {
                                setState(() {
                                  selectedCustomer = doc;
                                  _customerSearchController.text = doc['name'];
                                  showCustomerSuggestions = false;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    if (showCustomerSuggestions && filteredCustomers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Customer tidak ditemukan. Klik tombol + untuk menambahkan.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 25),

                    // --- SECTION 2: CATALOG PRODUK TAB VIEW ---
                    const Text(
                      'Pilih Produk / Paket Laundry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: TabBarView(
                        children: [
                          _buildProductTabContent('regular'),
                          _buildProductTabContent('express'),
                          _buildProductTabContent('kilat'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- SECTION 3: RINGKASAN PESANAN (KERANJANG) ---
                    if (cart.isNotEmpty) ...[
                      const Text(
                        'Ringkasan Pesanan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              // Tampilkan daftar belanjaan produk yang dipilih
                              ...cart.entries.map((entry) {
                                final item = entry.value;
                                final pData =
                                    item['doc'].data() as Map<String, dynamic>;
                                final isKiloan =
                                    pData['product_type'] == 'Kiloan';
                                final subTotal =
                                    (item['qty'] * item['unitPrice']).toInt();

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${pData['name']} (${item['service'].toString().toUpperCase()})',
                                  ),
                                  subtitle: Text(
                                    '${item['qty']} ${isKiloan ? 'Kg' : 'Pcs'} x ${_formatCurrency(item['unitPrice'])}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatCurrency(subTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => cart.remove(entry.key),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(),

                              // Dropdown Parfum
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Pilih Parfum:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButton<String>(
                                      value: selectedPerfume,
                                      isExpanded: true,
                                      items: perfumeList.map((perfume) {
                                        return DropdownMenuItem<String>(
                                          value: perfume['name'],
                                          child: Text(
                                            '${perfume['name']} (${_formatCurrency(perfume['price'] ?? 0)})',
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        final item = perfumeList.firstWhere(
                                          (p) => p['name'] == val,
                                          orElse: () => {
                                            'name': 'No Perfume',
                                            'price': 0,
                                          },
                                        );
                                        setState(() {
                                          selectedPerfume = val ?? 'No Perfume';
                                          perfumePrice = item['price'] as int;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),

                              // Komponen TOTAL HARGA Akhir
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL AKHIR:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(calculateTotal()),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- SECTION 4: OPSI PEMBAYARAN ---
                      const Text(
                        'Opsi Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  'Belum Bayar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: paymentStatus == 'Belum Bayar',
                              selectedColor: Colors.red.shade400,
                              labelStyle: TextStyle(
                                color: paymentStatus == 'Belum Bayar'
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              onSelected: (val) =>
                                  setState(() => paymentStatus = 'Belum Bayar'),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text(
                                  'Lunas',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: paymentStatus == 'Lunas',
                              selectedColor: Colors.green.shade500,
                              labelStyle: TextStyle(
                                color: paymentStatus == 'Lunas'
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              onSelected: (val) =>
                                  setState(() => paymentStatus = 'Lunas'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // BUTTON SIMPAN UTAMA
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: saveOrder,
                          child: const Text(
                            'SIMPAN PESANAN & LIHAT NOTA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  // Widget Pembuat Item di Dalam Tab Bar
  Widget _buildProductTabContent(String service) {
    if (allProducts.isEmpty) {
      return const Center(
        child: Text('Tidak ada master produk. Buat di menu Produk dahulu.'),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: allProducts.length,
      itemBuilder: (context, index) {
        final doc = allProducts[index];
        final data = doc.data() as Map<String, dynamic>;
        final price = getPriceForService(data, service);
        final isKiloan = data['product_type'] == 'Kiloan';

        return Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.local_laundry_service,
                  size: 40,
                  color: Colors.amber,
                ),
                Text(
                  data['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Rp $price/${isKiloan ? 'Kg' : 'Pcs'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.amber,
                    size: 30,
                  ),
                  onPressed: () => _showQtyDialog(doc, service),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
