import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerDetailPage extends StatelessWidget {
  final String outletId;
  final DocumentSnapshot customer;

  const CustomerDetailPage({
    super.key,
    required this.outletId,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final data = customer.data() as Map<String, dynamic>? ?? {};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.amber,
          title: const Text(
            'Detail Pelanggan',
            style: TextStyle(color: Color(0xFF152C4A)),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Informasi'),
              Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    child: Icon(Icons.person, size: 35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data['name']?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF152C4A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['phone']?.toString() ?? '-',
                    style: const TextStyle(color: Color(0xFF152C4A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['address']?.toString() ?? '-',
                    style: const TextStyle(color: Color(0xFF152C4A)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildInfoTab(data),
                  _buildHistoryTab(outletId, customer.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> data) {
    final totalOrders = data['total_orders'] ?? 0;
    final totalSpending = data['total_spending'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(
                          totalOrders.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF152C4A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total Order',
                          style: TextStyle(color: Color(0xFF152C4A)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(
                          _formatCurrency(totalSpending),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF152C4A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total Belanja',
                          style: TextStyle(color: Color(0xFF152C4A)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text(
              'Nama',
              style: TextStyle(color: Color(0xFF152C4A)),
            ),
            subtitle: Text(data['name']?.toString() ?? '-'),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text(
              'Nomor HP',
              style: TextStyle(color: Color(0xFF152C4A)),
            ),
            subtitle: Text(data['phone']?.toString() ?? '-'),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text(
              'Alamat',
              style: TextStyle(color: Color(0xFF152C4A)),
            ),
            subtitle: Text(data['address']?.toString() ?? '-'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(String outletId, String customerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('outlets')
          .doc(outletId)
          .collection('orders')
          .where('customer_id', isEqualTo: customerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada riwayat laundry'));
        }

        final sortedDocs = [...docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>? ?? {};
            final bData = b.data() as Map<String, dynamic>? ?? {};
            final aCreated = aData['created_at'];
            final bCreated = bData['created_at'];
            if (aCreated is Timestamp && bCreated is Timestamp) {
              return bCreated.compareTo(aCreated);
            }
            return 0;
          });

        return ListView.builder(
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final item =
                sortedDocs[index].data() as Map<String, dynamic>? ?? {};
            final invoiceNo = item['invoice_no']?.toString() ?? '-';
            final items = (item['items'] as List<dynamic>?) ?? [];
            final firstItem = items.isNotEmpty
                ? (items.first as Map<String, dynamic>? ?? {})
                : <String, dynamic>{};
            final productName =
                firstItem['product_name']?.toString() ?? 'Tidak ada item';
            final serviceType = firstItem['service_type']?.toString() ?? '-';
            final qty = firstItem['qty']?.toString() ?? '-';
            final totalPrice = item['total_price'] ?? 0;
            final status = item['status']?.toString() ?? '-';
            final paymentStatus = item['payment_status']?.toString() ?? '-';
            final createdAt = item['created_at'];
            final createdAtLabel = createdAt is Timestamp
                ? DateFormat('dd MMM yyyy HH:mm').format(createdAt.toDate())
                : '-';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ListTile(
                title: Text(
                  'Invoice: $invoiceNo',
                  style: TextStyle(color: Color(0xFF152C4A)),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Produk: $productName'),
                    const SizedBox(height: 2),
                    Text('Layanan: $serviceType'),
                    const SizedBox(height: 2),
                    Text('Qty: $qty'),
                    const SizedBox(height: 2),
                    Text('Total: ${_formatCurrency(totalPrice)}'),
                    const SizedBox(height: 2),
                    Text('Pembayaran: $paymentStatus'),
                    const SizedBox(height: 2),
                    Text('Status: $status'),
                    const SizedBox(height: 2),
                    Text('Tanggal: $createdAtLabel'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}
