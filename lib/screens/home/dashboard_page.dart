import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../kasir/cashier_page.dart';
import '../product/product_page.dart';
import '../customer/customer_page.dart';
import '../transaction/transaction_page.dart';
import '../orders/order_page.dart';
import '../parfum/parfum_page.dart';
import '../report/report_page.dart';
import '../setting/setting_page.dart';
import '/services/session_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String role = '';
  String userName = '';
  String cashierId = '';
  String outletName = '';
  String outletCode = '';
  String outletId = '';
  int dailyRevenue = 0;
  int dailyOrders = 0;
  int openOrdersCount = 0;
  int monthlyRevenue = 0;
  int unpaidOrdersCount = 0;
  bool isLoading = true;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    role = await SessionService.getRole();
    userName = await SessionService.getUserName();
    outletName = await SessionService.getOutletName();
    outletCode = await SessionService.getOutletCode();
    outletId = await SessionService.getOutletId();

    // Jika yang login kasir, ambil juga ID kasir (field 'cashier_id')
    if (role == 'cashier' && outletId.isNotEmpty) {
      try {
        final storedUserId = await SessionService.getUserId();
        if (storedUserId.isNotEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('outlets')
              .doc(outletId)
              .collection('cashiers')
              .doc(storedUserId)
              .get();
          if (doc.exists) {
            cashierId = doc.data()?['cashier_id']?.toString() ?? '';
          }
        }
      } catch (_) {
        // ignore errors
      }
    }

    // Debug: ensure outletId loaded
    // ignore: avoid_print
    print('Dashboard: outletId=$outletId');

    _listenDailyMetrics();
    _listenOpenOrdersCount();
    _listenMonthlyRevenue();
    _listenUnpaidOrdersCount();
  }

  void _listenDailyMetrics() {
    if (outletId.isEmpty) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final query = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('orders')
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(tomorrowStart));

    final subscription = query.snapshots().listen((snapshot) {
      var revenue = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final totalPrice = data['total_price'];
        if (totalPrice is num) {
          revenue += totalPrice.toInt();
        } else {
          revenue += int.tryParse(totalPrice?.toString() ?? '') ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        dailyRevenue = revenue;
        dailyOrders = snapshot.docs.length;
        isLoading = false;
      });
    });

    _subscriptions.add(subscription);
  }

  void _listenOpenOrdersCount() {
    if (outletId.isEmpty) return;

    final query = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('orders')
        .where('status', isNotEqualTo: 'Selesai');

    final subscription = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        openOrdersCount = snapshot.docs.length;
      });
    });

    _subscriptions.add(subscription);
  }

  void _listenMonthlyRevenue() {
    if (outletId.isEmpty) return;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    final query = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('orders')
        .where(
          'created_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('created_at', isLessThan: Timestamp.fromDate(nextMonthStart));

    final subscription = query.snapshots().listen((snapshot) {
      var revenue = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawStatus = data['status'];
        final statusStr = rawStatus?.toString().trim().toLowerCase() ?? '';
        final totalPrice = data['total_price'];

        // Debug: print each doc's status and total_price
        // ignore: avoid_print
        print(
          'monthlyRevenue doc ${doc.id}: status="$rawStatus" normalized="$statusStr" total_price=$totalPrice',
        );

        if (statusStr != 'selesai') continue;

        int price = 0;
        if (totalPrice is num) {
          price = totalPrice.toInt();
        } else {
          price = int.tryParse(totalPrice?.toString() ?? '') ?? 0;
        }

        revenue += price;
      }

      // Debug: log monthly snapshot details
      // ignore: avoid_print
      print(
        'monthlyRevenue snapshot: docs=${snapshot.docs.length}, revenue=$revenue',
      );

      if (!mounted) return;
      setState(() {
        monthlyRevenue = revenue;
      });
    });

    _subscriptions.add(subscription);
  }

  void _listenUnpaidOrdersCount() {
    if (outletId.isEmpty) return;

    final query = FirebaseFirestore.instance
        .collection('outlets')
        .doc(outletId)
        .collection('orders')
        .where('payment_status', isEqualTo: 'Belum Bayar');

    final subscription = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        unpaidOrdersCount = snapshot.docs.length;
      });
    });

    _subscriptions.add(subscription);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade100,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Dashboard Laundry',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF152C4A),
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout),
        //     onPressed: () async {
        //       await SessionService.logout();
        //       if (!mounted) return;
        //       Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        //     },
        //   ),
        // ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopSection(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // child: _buildSummaryCards(),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Menu Cepat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF152C4A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildMenuGrid(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTopSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xfffbb040), Color(0xfff7a600)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // const CircleAvatar(
              //   radius: 28,
              //   backgroundColor: Colors.white24,
              //   child: Icon(
              //     Icons.local_laundry_service,
              //     size: 30,
              //     color: Colors.white,
              //   ),
              // ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Image.asset('assets/logo3.png', height: 80),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            outletName.isEmpty
                                ? 'Nama Outlet'
                                : (outletCode.isNotEmpty
                                      ? '$outletName ($outletCode)'
                                      : outletName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName.isEmpty
                          ? 'Halo, User'
                          : (role == 'cashier' && cashierId.isNotEmpty
                                ? 'Halo, $userName (ID: $cashierId)'
                                : 'Halo, $userName'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Ringkasan Hari Ini',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pendapatan Harian',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(dailyRevenue),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Total Order: $dailyOrders',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildSummaryCards() {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Expanded(
  //         child: _buildInfoCard(
  //           Icons.shopping_cart,
  //           'Pesanan',
  //           openOrdersCount.toString(),
  //           Colors.deepPurple,
  //         ),
  //       ),
  //       const SizedBox(width: 12),
  //       Expanded(
  //         child: _buildInfoCard(
  //           Icons.payments,
  //           'Omset',
  //           _currencyFormat.format(monthlyRevenue),
  //           Colors.teal,
  //         ),
  //       ),
  //       const SizedBox(width: 12),
  //       Expanded(
  //         child: _buildInfoCard(
  //           Icons.pending_actions,
  //           'Belum Bayar',
  //           unpaidOrdersCount.toString(),
  //           Colors.redAccent,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildInfoCard(
  //   IconData icon,
  //   String label,
  //   String value,
  //   Color color,
  // ) {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(22),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.06),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.center,
  //       children: [
  //         Container(
  //           decoration: BoxDecoration(
  //             color: color.withOpacity(0.15),
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           padding: const EdgeInsets.all(10),
  //           child: Icon(icon, color: color, size: 24),
  //         ),
  //         const SizedBox(height: 14),
  //         Text(
  //           label,
  //           style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           value,
  //           style: TextStyle(
  //             fontSize: 14,
  //             // fontWeight: FontWeight.bold,
  //             color: Colors.grey.shade900,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildMenuGrid() {
    final items = role == 'owner'
        ? [
            _DashboardMenu(
              'Riwayat',
              icon: Icons.history,
              page: OrderPage(outletId: outletId),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            _DashboardMenu(
              'Laporan',
              icon: Icons.bar_chart,
              page: ReportPage(),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            _DashboardMenu(
              'Kasir',
              icon: Icons.person,
              page: CashierPage(),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            _DashboardMenu(
              'Produk',
              icon: Icons.shopping_bag,
              page: ProductPage(),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            _DashboardMenu(
              'Pelanggan',
              icon: Icons.people,
              page: CustomerPage(),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            _DashboardMenu(
              'Parfum',
              icon: Icons.spa,
              page: ParfumPage(),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ]
        : [
            _DashboardMenu(
              'Transaksi',
              icon: Icons.add_circle,
              page: TransactionPage(),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            _DashboardMenu(
              'Riwayat',
              icon: Icons.history,
              page: OrderPage(outletId: outletId),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
            _DashboardMenu(
              'Pelanggan',
              icon: Icons.people,
              page: CustomerPage(),
              textStyle: const TextStyle(
                color: Color(0xFF152C4A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            return SizedBox(width: itemWidth, child: _buildMenuCard(item));
          }).toList(),
        );
      },
    );
  }

  Widget _buildMenuCard(_DashboardMenu item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => item.page));
      },
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(item.icon, color: Colors.amber, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style:
                  item.textStyle ??
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle),
        label: 'Transaksi',
      ),
      if (role == 'owner')
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Pengaturan',
        )
      else
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Pengaturan',
        ),
    ];

    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: Colors.amber,
      unselectedItemColor: Colors.grey.shade600,
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionPage()),
          );
        } else if (index == 2) {
          if (role == 'owner') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingPage()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingPage()),
            );
          }
        }
      },
      items: items,
    );
  }
}

class _DashboardMenu {
  final String title;
  final IconData icon;
  final Widget page;
  final TextStyle? textStyle;

  const _DashboardMenu(
    this.title, {
    required this.icon,
    required this.page,
    this.textStyle,
  });
}
