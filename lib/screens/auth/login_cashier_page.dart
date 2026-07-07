import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/session_service.dart';
import '../home/dashboard_page.dart';

class LoginCashierPage extends StatefulWidget {
  const LoginCashierPage({super.key});

  @override
  State<LoginCashierPage> createState() => _LoginCashierPageState();
}

class _LoginCashierPageState extends State<LoginCashierPage> {
  final _outletCodeController = TextEditingController();
  final _cashierIdController = TextEditingController();

  bool isLoading = false;

  Future<void> loginCashier() async {
    setState(() {
      isLoading = true;
    });

    try {
      final outletResult = await FirebaseFirestore.instance
          .collection('outlets')
          .where('outlet_code', isEqualTo: _outletCodeController.text.trim())
          .limit(1)
          .get();

      if (outletResult.docs.isEmpty) {
        throw Exception('Kode outlet tidak ditemukan');
      }

      final outletDoc = outletResult.docs.first;
      final outletId = outletDoc.id;

      final cashierResult = await FirebaseFirestore.instance
          .collection('outlets')
          .doc(outletId)
          .collection('cashiers')
          .where('cashier_id', isEqualTo: _cashierIdController.text.trim())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (cashierResult.docs.isEmpty) {
        throw Exception('ID Kasir salah');
      }

      final cashierDoc = cashierResult.docs.first;
      final cashierData = cashierDoc.data();

      await SessionService.saveLogin(
        outletId: outletId,
        userId: cashierDoc.id,
        userName: cashierData['name'],
        role: 'cashier',
        outletName: outletDoc['name'],
        outletCode: outletDoc['outlet_code'],
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // const Icon(Icons.badge, size: 80, color: Colors.amber),
                Image.asset('assets/logo2.png', height: 80),
                const SizedBox(height: 20),

                const Text(
                  "LOGIN KASIR",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF152C4A),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _outletCodeController,
                  decoration: const InputDecoration(
                    labelText: "Kode Outlet",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: _cashierIdController,
                  decoration: const InputDecoration(
                    labelText: "ID Kasir",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginCashier,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text("MASUK"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
