import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'onboarding_screen.dart';
import 'dashboard_page.dart';
import 'admin_dashboard.dart';
import 'chat_service.dart';

// Add ChatScreen here directly
class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];

  bool isLoading = false;

  void _sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'text': userInput});
      _controller.clear();
    });

    final reply = await chatService.sendMessage(userInput);

    setState(() {
      messages.add({'role': 'bot', 'text': reply});
      isLoading = false;
    });
  }

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message['text'] ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Healthpulse AI')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (_, index) => _buildMessage(messages[index]),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                    const InputDecoration(hintText: 'Type your message...'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final role = doc.data()?['role'] ?? 'user';

        setState(() {
          _isLoggedIn = true;
          _isAdmin = role == 'admin';
          _seenOnboard = prefs.getBool('seenOnboard') ?? false;
          _loading = false;
        });
      } catch (e) {
        print("Error checking user role: $e");
        setState(() {
          _loading = false;
        });
      }
    } else {
      setState(() {
        _isLoggedIn = false;
        _loading = false;
      });
    }
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

    if (!_isLoggedIn) {
      homeWidget = const LoginPage();
    } else if (!_seenOnboard) {
      homeWidget = const OnboardingScreen();
    } else if (_isAdmin) {
      homeWidget = const AdminDashboard();
    } else {
      homeWidget = const DashboardPage();
    }

    return MaterialApp(
      title: 'Healthpulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: homeWidget,
      routes: {
        '/login': (context) => const LoginPage(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const DashboardPage(),
        '/adminDashboard': (context) => const AdminDashboard(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
