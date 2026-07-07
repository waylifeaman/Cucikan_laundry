import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../transaction/transaction_page.dart';
import '../transaction/rincian_pesanan_page.dart';

class OrderPage extends StatefulWidget {
  final String outletId;

  const OrderPage({Key? key, required this.outletId}) : super(key: key);

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  String selectedStatus = "Semua";

  int _countBaru = 0;
  int _countProses = 0;
  int _countSiapAmbil = 0;
  int _countSelesai = 0;
  int _countUnpaid = 0;
  int _countSemua = 0;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  final List<String> statusTabs = [
    "Baru",
    "Proses",
    "Siap Ambil",
    "Selesai",
    "Unpaid",
    "Semua",
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _initStatusCounts();
  }

  Future<void> _initStatusCounts() async {
    _ordersSubscription = FirebaseFirestore.instance
        .collection('outlets')
        .doc(widget.outletId)
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
          int baru = 0;
          int proses = 0;
          int siapAmbil = 0;
          int selesai = 0;
          int unpaid = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? '';
            final paymentStatus = data['payment_status']?.toString() ?? '';

            if (status == 'Baru') {
              baru++;
            } else if (status == 'Proses') {
              proses++;
            } else if (status == 'Siap Ambil') {
              siapAmbil++;
            } else if (status == 'Selesai') {
              selesai++;
            }

            if (paymentStatus == 'Belum Bayar') {
              unpaid++;
            }
          }

          if (!mounted) return;
          setState(() {
            _countBaru = baru;
            _countProses = proses;
            _countSiapAmbil = siapAmbil;
            _countSelesai = selesai;
            _countUnpaid = unpaid;
            _countSemua = snapshot.docs.length;
          });
        });
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Query _getFilteredQuery() {
    Query query = FirebaseFirestore.instance
        .collection('outlets')
        .doc(widget.outletId)
        .collection('orders');

    switch (selectedStatus) {
      case 'Semua':
        return query.orderBy('created_at', descending: true);
      case 'Unpaid':
        return query
            .where('payment_status', isEqualTo: 'Belum Bayar')
            .orderBy('created_at', descending: true);
      default:
        return query
            .where('status', isEqualTo: selectedStatus)
            .orderBy('created_at', descending: true);
    }
  }

  // Dummy data untuk simulasi jumlah counter status di atas chip.
  // Kamu bisa menggantinya dengan stream/future count riil dari Firestore nanti.
  int _getStatusCount(String status) {
    switch (status) {
      case "Baru":
        return _countBaru;
      case "Proses":
        return _countProses;
      case "Siap Ambil":
        return _countSiapAmbil;
      case "Selesai":
        return _countSelesai;
      case "Unpaid":
        return _countUnpaid;
      case "Semua":
        return _countSemua;
      default:
        return 0;
    }
  }

  String? _nextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'Baru':
        return 'Proses';
      case 'Proses':
        return 'Siap Ambil';
      case 'Siap Ambil':
        return 'Selesai';
      default:
        return null;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    final nextStatus = _nextStatus(currentStatus);
    if (nextStatus == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order sudah berada pada status akhir.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('outlets')
          .doc(widget.outletId)
          .collection('orders')
          .doc(orderId)
          .update({'status': nextStatus});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status order berhasil diperbarui menjadi $nextStatus.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFCF9FC,
      ), // Background agak keunguan/pink pucat tipis sesuai gambar
      appBar: AppBar(
        title: const Text(
          'Pesanan',
          style: TextStyle(
            color: Color(0xFF152C4A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.amber,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF152C4A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // --- KOTAK PENCARIAN ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari orderan (nama / invoice)..',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.amber),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Kotak agak rounded sesuai gambar
                  borderSide: BorderSide(color: Colors.grey.shade100),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade100),
                ),
              ),
            ),
          ),

          // --- TAB CHIPS DENGAN COUNTER MERAH ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                alignment: WrapAlignment
                    .center, // Pusatkan agar seimbang seperti di gambar
                children: List.generate(statusTabs.length, (index) {
                  final tabName = statusTabs[index];
                  final isSelected = selectedStatus == tabName;
                  final count = _getStatusCount(tabName);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedStatus = tabName;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amber : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.amber
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tabName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF152C4A),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Lingkaran counter jumlah item
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935), // Merah cerah
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // --- LIST DATA ORDERS (REALTIME STREAM) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Terjadi kesalahan: ${snapshot.error}'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada orderan ditemukan.'),
                  );
                }

                final orderDocs = snapshot.data!.docs;
                final filteredOrderDocs = orderDocs.where((doc) {
                  final order = doc.data() as Map<String, dynamic>;
                  if (_searchText.isEmpty) return true;

                  final invoiceNo =
                      order['invoice_no']?.toString().toLowerCase() ?? '';
                  final customerName =
                      order['customer_name']?.toString().toLowerCase() ?? '';
                  final customerPhone =
                      order['customer_phone']?.toString().toLowerCase() ?? '';
                  final query = _searchText.toLowerCase();

                  return invoiceNo.contains(query) ||
                      customerName.contains(query) ||
                      customerPhone.contains(query);
                }).toList();

                if (filteredOrderDocs.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada orderan sesuai pencarian.'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredOrderDocs.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    final order =
                        filteredOrderDocs[index].data() as Map<String, dynamic>;

                    final customerName = order['customer_name'] ?? 'Tanpa Nama';
                    final customerPhone = order['customer_phone'] ?? '-';
                    final invoiceNo = order['invoice_no'] ?? '-';
                    final items = (order['items'] as List<dynamic>?) ?? [];
                    final serviceType = items.isNotEmpty
                        ? (items.first['service_type'] ?? '-')
                        : '-';
                    final totalPrice = order['total_price'] ?? 0;
                    final paymentStatus =
                        order['payment_status'] ?? 'Belum Bayar';

                    // Format tanggal kustom untuk sisi kiri (Hari dan Bulan)
                    String dayStr = "-";
                    String monthStr = "-";
                    String yearTimeStr = "-";

                    if (order['created_at'] != null) {
                      Timestamp timestamp = order['created_at'];
                      DateTime date = timestamp.toDate();
                      dayStr = DateFormat('d').format(date);
                      monthStr = DateFormat(
                        'MMM',
                      ).format(date); // Jan, Dec, dll.
                      yearTimeStr = DateFormat('HH:mm').format(date);
                    }

                    final currencyFormat = NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. BAGIAN KIRI: TANGGAL VERTIKAL
                            SizedBox(
                              width: 45,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    serviceType,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          serviceType
                                                  .toString()
                                                  .toLowerCase() ==
                                              'regular'
                                          ? Colors.green
                                          : serviceType
                                                    .toString()
                                                    .toLowerCase() ==
                                                'express'
                                          ? Colors.amber
                                          : serviceType
                                                    .toString()
                                                    .toLowerCase() ==
                                                'kilat'
                                          ? Colors.red
                                          : Colors.grey[500],
                                    ),
                                  ),
                                  Text(
                                    dayStr,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF152C4A),
                                    ),
                                  ),
                                  Text(
                                    monthStr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 2. BAGIAN TENGAH: INFORMASI UTAMA & TOMBOL
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Baris Invoice dan Teks "Total"
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "$yearTimeStr  Order: $invoiceNo ",
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        "Total",
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),

                                  // Baris Nama Pelanggan & Harga Total
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF152C4A),
                                        ),
                                      ),
                                      Text(
                                        currencyFormat.format(totalPrice),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF152C4A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Nomor Telepon
                                  Text(
                                    customerPhone,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Tombol Aksi di bagian bawah item
                                  Row(
                                    children: [
                                      // Status Badge Warna Berdasarkan Pembayaran
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: paymentStatus == 'Lunas'
                                              ? Colors.green
                                              : const Color(0xFFFF9800),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          paymentStatus,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Tombol Lihat Detail
                                      SizedBox(
                                        height: 26,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RincianPesananPage(
                                                      orderData: order,
                                                    ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFE53935,
                                            ), // Merah
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text(
                                            'Lihat',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 3. BAGIAN KANAN: TOMBOL UPDATE STATUS
                            Container(
                              margin: const EdgeInsets.only(top: 20, left: 4),
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () {
                                  final orderId = orderDocs[index].id;
                                  final currentStatus =
                                      order['status']?.toString() ?? 'Baru';
                                  _updateOrderStatus(orderId, currentStatus);
                                },
                              ),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
      // Floating Action Button Tambah Orderan Baru (Dibuat agak besar & kotak membulat sesuai gambar)
      // floatingActionButton: SizedBox(
      //   width: 60,
      //   height: 60,
      //   child: FloatingActionButton(
      //     onPressed: () {},
      //     backgroundColor: Colors.amber,
      //     elevation: 4,
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(16),
      //     ),
      //     child: const Icon(Icons.add, color: Colors.black87, size: 32),
      //   ),
      // ),
    );
  }
}
