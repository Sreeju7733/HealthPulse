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
      } catch (_) {
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
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
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
        '/login': (_) => const LoginPage(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/dashboard': (_) => const DashboardPage(),
        '/adminDashboard': (_) => const AdminDashboard(),
        '/chat': (_) => const ChatScreen(),
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> conversation = [];

  String? currentBotMessage = "Hello! I’m your health assistant. How can I help you today?";
  bool isLoading = false;
  bool chatComplete = false;

  Future<String> sendToGeminiAI(List<Map<String, String>> conversation) async {
    await Future.delayed(const Duration(seconds: 2));

    final lastUserInput = conversation.isNotEmpty ? conversation.last['user'] ?? '' : '';

    // Replace this with your actual Gemini API integration
    if (conversation.length > 5 || lastUserInput.toLowerCase().contains("no") || lastUserInput.toLowerCase().contains("that's all")) {
      return "Thank you. Based on your responses, you should consult a doctor if symptoms persist. Stay hydrated and rest.";
    }

    return "Can you tell me more about your symptoms or how you're feeling?";
  }

  Future<void> _handleSubmit() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty || isLoading || chatComplete) return;

    setState(() {
      conversation.add({'user': userInput, 'bot': currentBotMessage!});
      _controller.clear();
      isLoading = true;
    });

    try {
      final botReply = await sendToGeminiAI(conversation);
      setState(() {
        currentBotMessage = botReply;
        isLoading = false;
      });

      if (botReply.toLowerCase().contains("thank you") || botReply.toLowerCase().contains("consult a doctor")) {
        setState(() {
          chatComplete = true;
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('user_chats')
              .doc(user.uid)
              .collection('sessions')
              .add({
            'conversation': conversation,
            'final_advice': botReply,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      setState(() {
        currentBotMessage = "Error getting AI response: $e";
        isLoading = false;
        chatComplete = true;
      });
    }
  }

  Widget _buildChat() {
    List<Widget> widgets = [];
    for (var qa in conversation) {
      widgets.add(_buildBubble(qa['bot']!, isBot: true));
      widgets.add(_buildBubble(qa['user']!, isBot: false));
    }
    if (!chatComplete && currentBotMessage != null) {
      widgets.add(_buildBubble(currentBotMessage!, isBot: true));
    }
    return ListView(padding: const EdgeInsets.all(8), children: widgets);
  }

  Widget _buildBubble(String text, {required bool isBot}) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBot ? Colors.grey[300] : Colors.blue[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Healthpulse AI')),
      body: Column(
        children: [
          Expanded(child: _buildChat()),
          if (isLoading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          if (!chatComplete && !isLoading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: "Type your response..."),
                      onSubmitted: (_) => _handleSubmit(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _handleSubmit),
                ],
              ),
            ),
          if (chatComplete)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text("Thank you! Your session is complete.", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
