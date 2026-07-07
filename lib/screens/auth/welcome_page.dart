import 'package:flutter/material.dart';

import 'login_page.dart';
import 'login_cashier_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo2.png', height: 90),

                    // const Icon(
                    //   Icons.local_laundry_service,
                    //   size: 90,
                    //   color: Colors.amber,
                    // ),
                    const SizedBox(height: 20),

                    const Text(
                      "CUCIKAN",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF152C4A),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Aplikasi Kasir Laundry",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),

                    const SizedBox(height: 35),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person),
                        label: const Text(
                          "LOGIN OWNER",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginOwnerPage(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Color(0xFF152C4A)),
                        ),
                        icon: const Icon(Icons.badge, color: Color(0xFF152C4A)),
                        label: const Text(
                          "LOGIN KASIR",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF152C4A),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginCashierPage(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Divider(),

                    const SizedBox(height: 10),

                    const Text(
                      "Belum punya outlet?",
                      style: TextStyle(color: Color(0xFF152C4A)),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "DAFTAR OUTLET",
                        style: TextStyle(color: Color(0xFF152C4A)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
