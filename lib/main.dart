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
import 'chat_service.dart'; // ✅ Chat service

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

  // conversation list holds each message as a map: {'question': userText, 'answer': botText}
  final List<Map<String, String>> conversation = [];

  final ChatService chatService = ChatService();
  String currentBotMessage = "Hello! I’m your health assistant. How can I help you today?";
  bool isLoading = false;
  bool chatComplete = false;

  @override
  void initState() {
    super.initState();
    // Initialize conversation with the first bot message only (no user question yet)
    conversation.add({'answer': currentBotMessage});
  }

  Future<void> _handleSubmit() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty || isLoading || chatComplete) return;

    setState(() {
      // Add the user's question as a new entry (without answer yet)
      conversation.add({'question': userInput});
      _controller.clear();
      isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'guestUser';

    try {
      // Send the full conversation to chatService for context
      final botReply = await chatService.sendMessage(userInput, userId);


      setState(() {
        // Update the last conversation entry with the bot's answer
        conversation[conversation.length - 1]['answer'] = botReply;
        currentBotMessage = botReply;
        isLoading = false;
      });

      // If bot reply indicates end of chat, save session & lock input
      if (botReply.toLowerCase().contains("thank you") ||
          botReply.toLowerCase().contains("consult a doctor")) {
        setState(() {
          chatComplete = true;
        });

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

    for (var entry in conversation) {
      if (entry.containsKey('question')) {
        widgets.add(_buildBubble(entry['question']!, isBot: false));
      }
      if (entry.containsKey('answer')) {
        widgets.add(_buildBubble(entry['answer']!, isBot: true));
      }
    }


    // Show current bot message if chat not complete and no latest bot message shown yet
    if (!chatComplete && currentBotMessage.isNotEmpty && (conversation.isEmpty || conversation.last['answer'] != currentBotMessage)) {
      widgets.add(_buildBubble(currentBotMessage, isBot: true));
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
          if (isLoading)
            const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
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
              child: Text(
                "Thank you! Your session is complete.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
