import 'package:cucikan_laundry_v4/screens/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/register_page.dart';
import 'screens/auth/splash_page.dart';
import 'package:cucikan_laundry_v4/screens/home/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cucikan Laundry',
      theme: ThemeData(primarySwatch: Colors.amber),
      home: const SplashPage(),
      routes: {
        '/login': (context) => const LoginOwnerPage(),
        '/register': (context) => const RegisterPage(),
        '/dashboard': (context) => const DashboardPage(),
      },
    );
  }
}
