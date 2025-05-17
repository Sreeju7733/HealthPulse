import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard.dart'; // Ensure this file exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _seenOnboard = false;
  bool _isLoggedIn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _seenOnboard = prefs.getBool('seenOnboard') ?? false;
      _isLoggedIn = user != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    Widget homeWidget;

    // ✅ Login check comes first
    if (!_isLoggedIn) {
      homeWidget = const LoginPage();
    } else if (!_seenOnboard) {
      homeWidget = const OnboardingScreen();
    } else {
      homeWidget = const DashboardScreen(); // You can replace with role check if needed
    }

    return MaterialApp(
      title: 'Healthpulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: homeWidget,
      routes: {
        '/login': (context) => const LoginPage(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/userDashboard': (context) => const DashboardScreen(),
        '/adminDashboard': (context) => const AdminDashboard(),
      },
    );
  }
}
