import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/session_service.dart';

class RincianPesananPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const RincianPesananPage({super.key, required this.orderData});

  @override
  State<RincianPesananPage> createState() => _RincianPesananPageState();
}

class _RincianPesananPageState extends State<RincianPesananPage> {
  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _selectedDevice;
  bool _isConnected = false;
  String _outletName = 'ANNI LAUNDRY';
  String _outletAddress = 'Jl Nusa Tenggara Timur';

  Map<String, dynamic> get orderData => widget.orderData;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _loadOutletInfo();
  }

  Future<void> _loadOutletInfo() async {
    try {
      final outletId = await SessionService.getOutletId();
      if (outletId.isEmpty) return;

      final outletDoc = await FirebaseFirestore.instance
          .collection('outlets')
          .doc(outletId)
          .get();
      if (!outletDoc.exists) return;

      final data = outletDoc.data();
      if (!mounted) return;
      setState(() {
        _outletName = data?['name']?.toString() ?? _outletName;
        _outletAddress = data?['address']?.toString() ?? _outletAddress;
      });
    } catch (_) {
      // Ignore loading failure and use defaults.
    }
  }

  Future<void> _initBluetooth() async {
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      final bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isConnected = isConnected;
      });
    } catch (_) {
      // Bluetooth init might fail if platform not ready or no permissions.
    }
  }

  Future<void> _connectToDevice(BluetoothInfo device) async {
    try {
      final bool success = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );
      if (!mounted) return;
      setState(() {
        _selectedDevice = device;
        _isConnected = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terhubung ke printer ${device.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal terhubung ke printer: $e')));
    }
  }

  Future<BluetoothInfo?> _selectBluetoothDevice() async {
    if (_devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada printer Bluetooth terpasang. Silakan pair printer terlebih dahulu.',
            ),
          ),
        );
      }
      return null;
    }

    return showModalBottomSheet<BluetoothInfo>(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              const ListTile(title: Text('Pilih printer thermal')),
              Expanded(
                child: ListView.separated(
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return ListTile(
                      title: Text(device.name),
                      subtitle: Text(device.macAdress),
                      trailing: _selectedDevice?.macAdress == device.macAdress
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () => Navigator.of(context).pop(device),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPrinterGuidePage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThermalPrinterGuidePage(orderData: orderData),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '-';
    }
    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
  }

  String _encodeWhatsAppText(String text) {
    return Uri.encodeComponent(text);
  }

  Future<void> _sendWhatsApp(String phone, String message) async {
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${_encodeWhatsAppText(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Tidak dapat membuka WhatsApp';
    }
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    }
    return digits;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _buildWhatsAppMessage() {
    final invoiceNo = orderData['invoice_no'] ?? '-';
    final customerName = orderData['customer_name'] ?? '-';
    final customerAddress = orderData['customer_address'] ?? '-';
    final paymentStatus = orderData['payment_status'] ?? 'Belum Bayar';
    final status = orderData['status'] ?? 'Baru';
    final createdAtData = orderData['created_at'];
    final createdAtDateTime = createdAtData is Timestamp
        ? createdAtData.toDate()
        : DateTime.now();
    final createdAtLabel = DateFormat(
      'dd MMM yyyy HH:mm',
    ).format(createdAtDateTime);

    final items = (orderData['items'] as List<dynamic>?) ?? [];
    final itemLines = items
        .map((item) {
          final name = item['product_name'] ?? '-';
          final service = _capitalize(
            item['service_type']?.toString() ?? 'regular',
          );
          final qty = item['qty'] ?? 0;
          final pricePerUnit = item['price_per_unit'] ?? 0;
          final totalLine = (qty is num ? qty * pricePerUnit : 0);
          return '* $name ($service) - $qty x ${_formatCurrency(pricePerUnit)} = ${_formatCurrency(totalLine)}';
        })
        .join('\n');

    final packageName = items.isNotEmpty
        ? items.first['product_name'] ?? '-'
        : '-';
    final totalQty = items.fold<num>(
      0,
      (acc, item) => acc + (item['qty'] as num? ?? 0),
    );
    final totalPrice = orderData['total_price'] ?? 0;

    return '🧺 $_outletName\n'
        '🏢 Alamat Outlet: $_outletAddress\n\n'
        '🧾 No Invoice: $invoiceNo\n'
        '👤 Customer: $customerName\n'
        '🏡 Alamat: $customerAddress\n'
        '📅 Tanggal: $createdAtLabel\n\n'
        '📦 Detail Pesanan:\n'
        '$itemLines\n\n'
        '🪣 Paket: $packageName\n'
        '⚖️ Qty: ${_formatCurrency(totalQty)}\n\n'
        '💰 Total Biaya: ${_formatCurrency(totalPrice)}\n'
        '💳 Pembayaran: $paymentStatus\n'
        '📌 Status: $status\n\n'
        'Terima kasih telah menggunakan layanan kami 🙏';
  }

  @override
  Widget build(BuildContext context) {
    final int totalPrice = orderData['total_price'] ?? 0;
    final createdAtData = orderData['created_at'];
    final createdDateTime = createdAtData is Timestamp
        ? createdAtData.toDate()
        : DateTime.now();
    final perfumeName = orderData['perfume'] ?? 'tidak ada';
    final perfumePrice = orderData['perfume_price'] ?? 0;
    final perfumeLabel = perfumeName == 'tidak ada'
        ? 'tidak ada'
        : '$perfumeName (${_formatCurrency(perfumePrice)})';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'RINCIAN PESANAN',
          style: TextStyle(
            color: Color(0xFF152C4A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // const Icon(
                    //   Icons.local_laundry_service,
                    //   color: Colors.black87,
                    // ),
                    Image.asset('assets/logo2.png', height: 40),
                    const SizedBox(width: 8),
                    Text(
                      _outletName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF152C4A),
                      ),
                    ),
                  ],
                ),
                Text(
                  orderData['invoice_no'] ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF152C4A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderData['customer_name'] ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(orderData['customer_phone'] ?? '-'),
                        Text(
                          orderData['customer_address'] ?? 'Tidak ada alamat',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final phone =
                              orderData['customer_phone']?.toString() ?? '';
                          if (phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Nomor WhatsApp customer tidak tersedia',
                                ),
                              ),
                            );
                            return;
                          }
                          try {
                            await _sendWhatsApp(
                              _normalizePhone(phone),
                              _buildWhatsAppMessage(),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal membuka WhatsApp: $e'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.chat,
                          size: 16,
                          color: Colors.green,
                        ),
                        label: const Text(
                          'Kirim',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: _openPrinterGuidePage,
                        icon: const Icon(
                          Icons.receipt_long,
                          color: Colors.black54,
                        ),
                        tooltip: 'Cetak Nota',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final List<dynamic> items = orderData['items'] ?? [];
                if (items.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: items.map((item) {
                    final num pricePerUnit = item['price_per_unit'] ?? 0;
                    final num qty = item['qty'] ?? 0;
                    final num totalPerItem = pricePerUnit * qty;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['product_type'] ?? 'Kiloan'} (${item['service_type'] ?? 'regular'})',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['product_name'] ?? 'Cuci Lipat',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(qty)} x ${_formatCurrency(pricePerUnit)}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$qty Kg/Pcs',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                _formatCurrency(totalPerItem),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildRowDetail(
                    'Dibuat Oleh',
                    orderData['created_by'] ?? '-',
                  ),
                  _buildRowDetail('Status', orderData['status'] ?? 'Baru'),
                  _buildRowDetail(
                    'Tanggal Masuk',
                    _formatTimestamp(orderData['created_at']),
                  ),
                  _buildRowDetail('Parfum', perfumeLabel),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status Pembayaran',
                        style: TextStyle(color: Colors.black54),
                      ),
                      Text(
                        orderData['payment_status'] ?? 'Belum Bayar',
                        style: TextStyle(
                          color: orderData['payment_status'] == 'Lunas'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildRowDetail('Total', _formatCurrency(totalPrice)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bayar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatCurrency(totalPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF152C4A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class ThermalPrinterGuidePage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const ThermalPrinterGuidePage({super.key, required this.orderData});

  @override
  State<ThermalPrinterGuidePage> createState() =>
      _ThermalPrinterGuidePageState();
}

class _ThermalPrinterGuidePageState extends State<ThermalPrinterGuidePage> {
  List<BluetoothInfo> _devices = [];
  BluetoothInfo? _selectedDevice;
  bool _isConnected = false;
  bool _isLoading = false;
  String _outletName = '';
  String _outletAddress = '';

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _loadOutletInfo();
  }

  Future<void> _loadOutletInfo() async {
    try {
      final outletId = await SessionService.getOutletId();
      if (outletId.isEmpty) return;

      final outletDoc = await FirebaseFirestore.instance
          .collection('outlets')
          .doc(outletId)
          .get();
      if (!outletDoc.exists) return;

      final data = outletDoc.data();
      if (!mounted) return;
      setState(() {
        _outletName = data?['name']?.toString() ?? _outletName;
        _outletAddress = data?['address']?.toString() ?? _outletAddress;
      });
    } catch (_) {
      // Ignore loading failure and use defaults.
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      final bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isConnected = isConnected;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _devices = [];
      });
    }
  }

  Future<void> _connectPrinter() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih printer dari daftar terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool success = await PrintBluetoothThermal.connect(
        macPrinterAddress: _selectedDevice!.macAdress,
      );
      if (!mounted) return;
      setState(() {
        _isConnected = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terhubung ke printer ${_selectedDevice!.name}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal terhubung: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _printReceipt() async {
    if (!_isConnected) {
      await _connectPrinter();
    }
    if (!_isConnected) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final createdAtData = widget.orderData['created_at'];
      final createdAtDateTime = createdAtData is Timestamp
          ? createdAtData.toDate()
          : DateTime.now();
      final createdAtLabel = DateFormat(
        'dd MMM yyyy HH:mm',
      ).format(createdAtDateTime);
      final items = (widget.orderData['items'] as List<dynamic>?) ?? [];

      // Lebar karakter printer thermal 58mm umumnya adalah 32 karakter
      const int maxChars = 32;

      // Helper fungsi untuk membuat teks rata kiri-kanan (Justified)
      String formatRow(String left, String right) {
        int spaceLength = maxChars - left.length - right.length;
        if (spaceLength < 1) spaceLength = 1;
        return '$left${' ' * spaceLength}$right\n';
      }

      // 1. HEADER OUTLET (Rata Tengah Manual)
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 3,
          text: '${_outletName.toUpperCase()}\n',
        ),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(size: 1, text: '$_outletAddress\n'),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(size: 1, text: '${'=' * maxChars}\n'),
      );

      // 2. DATA TRANSAKSI
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: 'Invoice : ${widget.orderData['invoice_no'] ?? '-'}\n',
        ),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: 'Dibuat Oleh : ${widget.orderData['created_by'] ?? '-'}\n',
        ),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(size: 1, text: 'Tanggal : $createdAtLabel\n'),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: 'Pelanggan: ${widget.orderData['customer_name'] ?? '-'}\n',
        ),
      );
      // await PrintBluetoothThermal.writeString(
      //   printText: PrintTextSize(
      //     size: 1,
      //     text: 'No Telp  : ${widget.orderData['customer_phone'] ?? '-'}\n',
      //   ),
      // );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(size: 1, text: '${'-' * maxChars}\n'),
      );

      // 3. DAFTAR ITEM/LAYANAN LAUNDRY
      for (final item in items) {
        final name = item['product_name'] ?? '-';
        final service = _capitalize(
          item['service_type']?.toString() ?? 'regular',
        );
        final qty = item['qty'] ?? 0;
        final pricePerUnit = item['price_per_unit'] ?? 0;
        final totalLine = (qty is num ? qty * pricePerUnit : 0);

        // Baris 1: Nama Layanan + Jenis Service
        await PrintBluetoothThermal.writeString(
          printText: PrintTextSize(size: 1, text: '$name ($service)\n'),
        );

        // Baris 2: Detail Qty x Harga unit -------- Total Harga Item (Rata Kanan)
        String leftDetail = '  $qty x ${_formatCurrency(pricePerUnit)}';
        String rightDetail = _formatCurrency(totalLine);
        await PrintBluetoothThermal.writeString(
          printText: PrintTextSize(
            size: 1,
            text: formatRow(leftDetail, rightDetail),
          ),
        );
      }

      // 4. DETAIL PARFUM
      final perfumePrice = widget.orderData['perfume_price'] ?? 0;
      final perfumeName = widget.orderData['perfume'] ?? 'Tidak Ada';
      if (perfumeName.toLowerCase() != 'tidak ada' && perfumePrice > 0) {
        await PrintBluetoothThermal.writeString(
          printText: PrintTextSize(
            size: 1,
            text: formatRow(
              '  Parfum: $perfumeName',
              _formatCurrency(perfumePrice),
            ),
          ),
        );
      }

      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(size: 1, text: '${'-' * maxChars}\n'),
      );

      // 5. TOTAL BIAYA & STATUS
      final totalPrice = widget.orderData['total_price'] ?? 0;
      final paymentStatus = widget.orderData['payment_status'] ?? 'Belum Bayar';
      final orderStatus = widget.orderData['status'] ?? 'Baru';

      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: formatRow('TOTAL BIAYA', _formatCurrency(totalPrice)),
        ),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: formatRow('Pembayaran', paymentStatus.toUpperCase()),
        ),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: formatRow('Status Order', orderStatus.toUpperCase()),
        ),
      );

      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(size: 1, text: '${'=' * maxChars}\n'),
      );

      // 6. FOOTER / TERIMA KASIH
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: 'Terima kasih atas kepercayaan Anda\n',
        ),
      );
      await PrintBluetoothThermal.writeString(
        printText: PrintTextSize(
          size: 1,
          text: '\n\n\n',
        ), // Jeda kertas kertas kosong saat sobek
      );

      await PrintBluetoothThermal.disconnect;

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nota berhasil dicetak.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mencetak nota: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  String _formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cetak Nota',
          style: TextStyle(
            color: Color(0xFF152C4A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.amber,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Ikuti langkah berikut sebelum mencetak nota:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text('1. Nyalakan printer thermal.'),
                  Text('2. Aktifkan Bluetooth di HP.'),
                  Text('3. Pastikan HP sudah terhubung dengan printer.'),
                  Text('4. Pilih printer dari daftar di bawah.'),
                  Text('5. Tekan tombol cetak untuk mengirim nota.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Printer Thermal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BluetoothInfo>(
                      isExpanded: true,
                      value: _selectedDevice,
                      items: _devices.map((device) {
                        return DropdownMenuItem(
                          value: device,
                          child: Text(
                            '${device.name} (${device.macAdress})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (device) {
                        setState(() {
                          _selectedDevice = device;
                        });
                      },
                      hint: const Text('Pilih printer'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_devices.isEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tidak ada printer terdaftar. Silakan pair printer terlebih dahulu di pengaturan Bluetooth HP.',
                            style: TextStyle(color: Colors.red),
                          ),
                          SizedBox(height: 12),
                        ],
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _connectPrinter,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _isConnected
                                  ? 'Printer Terhubung'
                                  : 'Hubungkan Printer',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _printReceipt,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cetak Nota'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isConnected
                                ? 'Printer terhubung ke ${_selectedDevice?.name ?? 'printer yang dipilih'}.'
                                : 'Status koneksi: Belum terhubung',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _isConnected
                                  ? Colors.green
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedDevice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.bluetooth, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Dipilih: ${_selectedDevice!.name} (${_selectedDevice!.macAdress})',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
