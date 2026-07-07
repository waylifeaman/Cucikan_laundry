import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/session_service.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String outletId = '';
  late DateTime _selectedMonth;
  final TextEditingController _searchController = TextEditingController();
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    initializeDateFormatting('id_ID').then((_) {
      if (mounted) setState(() {});
    });
    _loadOutlet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOutlet() async {
    outletId = await SessionService.getOutletId();
    if (mounted) setState(() {});
  }

  DateTime get _monthStart {
    return DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  }

  DateTime get _monthEnd {
    return DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
  }

  String get _monthLabel {
    return DateFormat.yMMMM('id_ID').format(_selectedMonth);
  }

  String _formatCurrency(int value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  Future<void> _showMonthPicker() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 2, 1),
      lastDate: DateTime(now.year + 1, 12),
      helpText: 'Pilih Bulan Laporan',
      fieldLabelText: 'Bulan',
      fieldHintText: 'Bulan/Tahun',
      initialDatePickerMode: DatePickerMode.year,
    );

    if (selected != null) {
      setState(() {
        _selectedMonth = DateTime(selected.year, selected.month, 1);
      });
    }
  }

  List<Map<String, dynamic>> _extractOrderRows(
    List<QueryDocumentSnapshot> orders,
  ) {
    return orders.map((order) {
      final data = order.data() as Map<String, dynamic>;
      final totalPrice = data['total_price'] is num
          ? (data['total_price'] as num).toInt()
          : int.tryParse(data['total_price']?.toString() ?? '') ?? 0;

      final items = data['items'];
      final itemList = <Map<String, dynamic>>[];
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            itemList.add(item);
          } else if (item is Map) {
            itemList.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final productNames = itemList
          .map((item) => item['product_name']?.toString() ?? '-')
          .toList();
      final qtyValues = itemList
          .map((item) => item['qty']?.toString() ?? '-')
          .toList();
      final serviceTypes = itemList
          .map((item) => item['service_type']?.toString() ?? '-')
          .toList();

      return {
        'invoice_no': data['invoice_no']?.toString() ?? '-',
        'customer_name': data['customer_name']?.toString() ?? '-',
        'product_name': productNames.isNotEmpty ? productNames.join(', ') : '-',
        'qty': qtyValues.isNotEmpty ? qtyValues.join(', ') : '-',
        'service_type': serviceTypes.isNotEmpty ? serviceTypes.join(', ') : '-',
        'total_price': totalPrice,
        'created_at': data['created_at'] is Timestamp
            ? (data['created_at'] as Timestamp).toDate()
            : null,
      };
    }).toList();
  }

  Future<Uint8List> _generatePdf(List<QueryDocumentSnapshot> orders) async {
    final rows = _extractOrderRows(orders);
    final pdf = pw.Document();
    final regularFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Laporan Order Bulanan',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(_monthLabel, style: pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: [
                'No Invoice',
                'Customer',
                'Product',
                'Qty',
                'Service',
                'Total',
                'Tanggal',
              ],
              data: rows.map((row) {
                return [
                  row['invoice_no'],
                  row['customer_name'],
                  row['product_name'],
                  row['qty'],
                  row['service_type'],
                  _formatCurrency(row['total_price'] as int),
                  row['created_at'] != null
                      ? DateFormat(
                          'dd/MM/yyyy HH:mm',
                          'id_ID',
                        ).format(row['created_at'] as DateTime)
                      : '-',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Pendapatan: ${_formatCurrency(rows.fold<int>(0, (sum, r) => sum + (r['total_price'] as int)))}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _printReport(List<QueryDocumentSnapshot> orders) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk dicetak.')),
      );
      return;
    }

    setState(() => _isPrinting = true);
    try {
      final pdfData = await _generatePdf(orders);
      await Printing.layoutPdf(onLayout: (_) async => pdfData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mencetak laporan: $e')));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Order'),
        content: const Text('Yakin ingin menghapus order ini?'),
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

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('orders')
        .doc(orderId)
        .delete();
  }

  Widget _buildChart(Map<int, int> dailyRevenue) {
    final maxValue = dailyRevenue.values.fold<int>(
      0,
      (prev, elem) => elem > prev ? elem : prev,
    );
    final daysInMonth = DateTime(
      _monthStart.year,
      _monthStart.month + 1,
      0,
    ).day;

    return SizedBox(
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafik Pendapatan Harian',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF152C4A),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(daysInMonth, (index) {
                  final day = index + 1;
                  final value = dailyRevenue[day] ?? 0;
                  final heightFactor = maxValue > 0 ? value / maxValue : 0.0;
                  final barHeight = 120.0 * heightFactor + 8.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 18,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: value > 0
                                ? Colors.amber
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          day.toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bulan: $_monthLabel',
                style: const TextStyle(color: Color(0xFF152C4A)),
              ),
              Text(
                'Maks: ${_formatCurrency(maxValue)}',
                style: const TextStyle(color: Color(0xFF152C4A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrafikKeterangan(int totalOrders, int totalRevenue) {
    final average = totalOrders > 0 ? (totalRevenue / totalOrders).round() : 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keterangan Grafik Pendapatan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF152C4A),
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Total order bulan ini', totalOrders.toString()),
            const SizedBox(height: 8),
            _infoRow('Total pendapatan', _formatCurrency(totalRevenue)),
            const SizedBox(height: 8),
            _infoRow(
              'Rata-rata pendapatan per order',
              _formatCurrency(average),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF152C4A)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF152C4A),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTable(
    List<QueryDocumentSnapshot> orders,
    int totalRevenue,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rekap Orderan Bulanan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF152C4A),
              ),
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('Tidak ada order pada bulan ini')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.resolveWith(
                    (states) => Colors.grey.shade100,
                  ),
                  columnSpacing: 24,
                  horizontalMargin: 12,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 60,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF152C4A),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'No Invoice',
                        style: TextStyle(color: Color(0xFF152C4A)),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Customer',
                        style: TextStyle(color: Color(0xFF152C4A)),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Total',
                        style: TextStyle(color: Color(0xFF152C4A)),
                        softWrap: false,
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Aksi',
                        style: TextStyle(color: Color(0xFF152C4A)),
                      ),
                    ),
                  ],
                  rows: orders.map((order) {
                    final data = order.data() as Map<String, dynamic>;
                    final invoiceNo = data['invoice_no']?.toString() ?? '-';
                    final customerName =
                        data['customer_name']?.toString() ?? '-';
                    final totalPrice = data['total_price'] is num
                        ? (data['total_price'] as num).toInt()
                        : int.tryParse(data['total_price']?.toString() ?? '') ??
                              0;

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            invoiceNo,
                            style: const TextStyle(color: Color(0xFF152C4A)),
                          ),
                        ),
                        DataCell(
                          Text(
                            customerName,
                            style: const TextStyle(color: Color(0xFF152C4A)),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatCurrency(totalPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF152C4A),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteOrder(order.id),
                                tooltip: 'Hapus',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const Divider(height: 32, thickness: 1),
            Row(
              children: [
                const Expanded(
                  flex: 6,
                  child: Text(
                    'Total Pendapatan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF152C4A),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatCurrency(totalRevenue),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF152C4A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Laporan Bulanan',
          style: TextStyle(color: Color(0xFF152C4A)),
        ),
        backgroundColor: Colors.amber,
      ),
      body: outletId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pilih Bulan: ${DateFormat.yMMMM('id_ID').format(_selectedMonth)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF152C4A),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                            ),
                            onPressed: _showMonthPicker,
                            child: const Text('Ubah'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('outlets')
                            .doc(outletId)
                            .collection('orders')
                            .where(
                              'created_at',
                              isGreaterThanOrEqualTo: Timestamp.fromDate(
                                _monthStart,
                              ),
                            )
                            .where(
                              'created_at',
                              isLessThan: Timestamp.fromDate(_monthEnd),
                            )
                            .orderBy('created_at', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final orders = snapshot.data!.docs;
                          final dailyRevenue = <int, int>{};
                          var totalRevenue = 0;

                          for (final order in orders) {
                            final data = order.data() as Map<String, dynamic>;
                            final createdAt = data['created_at'] as Timestamp?;
                            final totalPrice = data['total_price'] is num
                                ? (data['total_price'] as num).toInt()
                                : int.tryParse(
                                        data['total_price']?.toString() ?? '',
                                      ) ??
                                      0;

                            if (createdAt != null) {
                              final day = createdAt.toDate().day;
                              dailyRevenue[day] =
                                  (dailyRevenue[day] ?? 0) + totalPrice;
                            }

                            totalRevenue += totalPrice;
                          }

                          final query = _searchController.text
                              .trim()
                              .toLowerCase();
                          final filteredOrders = orders.where((order) {
                            final data = order.data() as Map<String, dynamic>?;
                            final invoiceNo =
                                data?['invoice_no']?.toString().toLowerCase() ??
                                '';
                            return invoiceNo.contains(query);
                          }).toList();

                          final filteredTotalRevenue = filteredOrders.fold<int>(
                            0,
                            (total, order) {
                              final data = order.data() as Map<String, dynamic>;
                              final totalPrice = data['total_price'] is num
                                  ? (data['total_price'] as num).toInt()
                                  : int.tryParse(
                                          data['total_price']?.toString() ?? '',
                                        ) ??
                                        0;
                              return total + totalPrice;
                            },
                          );

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ringkasan Bulan Ini',
                                            style: TextStyle(
                                              color: Color(0xFF152C4A),
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Bulan: $_monthLabel',
                                                    style: const TextStyle(
                                                      color: Color(0xFF152C4A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Total order: ${orders.length}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF152C4A),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                _formatCurrency(totalRevenue),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF152C4A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _buildChart(dailyRevenue),
                                    ),
                                  ),
                                ),
                                _buildGrafikKeterangan(
                                  orders.length,
                                  totalRevenue,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Cari berdasarkan No Invoice',
                                      prefixIcon: const Icon(Icons.search),
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
                                if (query.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      0,
                                    ),
                                    child: Text(
                                      'Menampilkan ${filteredOrders.length} dari ${orders.length} order',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.print),
                                      label: const Text('Cetak Laporan'),
                                      onPressed: () =>
                                          _printReport(filteredOrders),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildOrderTable(
                                  filteredOrders,
                                  filteredTotalRevenue,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_isPrinting)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    ),
                  ),
              ],
            ),
    );
  }
}
