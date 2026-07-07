import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_cashier_page.dart';
import 'cashier_detail_page.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  String outletId = '';

  @override
  void initState() {
    super.initState();
    loadOutlet();
  }

  Future<void> loadOutlet() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('outletId') ?? '';

    print("OUTLET ID LOGIN = $id");

    setState(() {
      outletId = id;
    });

    // setState(() {
    //   outletId = prefs.getString('outletId') ?? '';
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Manajemen Kasir",
          style: TextStyle(color: Color(0xFF152C4A)),
        ),
        backgroundColor: Colors.amber,
      ),

      body: outletId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('outlets')
                  .doc(outletId)
                  .collection('cashiers')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Belum ada kasir'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final cashier = snapshot.data!.docs[index];
                    final cashierData =
                        cashier.data() as Map<String, dynamic>? ?? {};
                    final name = cashierData['name']?.toString() ?? '';
                    final phone = cashierData['phone']?.toString() ?? '';
                    final role = cashierData['role']?.toString() ?? '';
                    final isActive = cashierData['isActive'] ?? true;

                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CashierDetailPage(
                                outletId: outletId,
                                cashier: cashier,
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isActive
                                ? Colors.green.shade100
                                : Colors.grey.shade300,
                            child: Icon(
                              Icons.person,
                              color: isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(phone),
                          trailing: IconButton(
                            icon: Icon(
                              isActive ? Icons.toggle_on : Icons.toggle_off,
                              color: isActive ? Colors.green : Colors.grey,
                              size: 30,
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('outlets')
                                  .doc(outletId)
                                  .collection('cashiers')
                                  .doc(cashier.id)
                                  .update({'isActive': !isActive});
                            },
                            tooltip: isActive ? 'Set non active' : 'Set active',
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCashierPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
