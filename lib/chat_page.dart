import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/chat_service.dart'; // Ensure this exists and is correctly implemented

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final List<String> filterTags = ['All', 'General', 'Sleep', 'Stress', 'Diet', 'Exercise'];
  final List<String> tags = ['General', 'Sleep', 'Stress', 'Diet', 'Exercise'];
  String filterTag = 'All';
  String selectedTag = 'General';

  late stt.SpeechToText _speech;
  bool _isListening = false;

  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      _controller.clear();
    });

    try {
      // Get user profile data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();
      String profileContext = "";

      if (userData != null) {
        final age = userData['age'] ?? 'unknown age';
        final goal = userData['goal'] ?? 'general wellness';
        final sleepHours = userData['sleepHours'] ?? 'not tracked';
        profileContext =
        "Patient is $age years old with a health goal of '$goal'. Average sleep duration is $sleepHours hours.";
      }

      // Get previous chat history
      final previousChats = await FirebaseFirestore.instance
          .collection('chats')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      String conversationHistory = previousChats.docs.isEmpty
          ? "Doctor: Hello, I’m your AI health assistant. How can I help today?\n"
          : previousChats.docs.reversed.map((doc) {
        final data = doc.data();
        return "Patient: ${data['message']}\nDoctor: ${data['response']}";
      }).join("\n");

      // Construct the AI prompt
      final fullPrompt = """
You are a senior doctor and wellness expert. Respond with brief, clear, and medically relevant advice. Use the patient profile and recent conversation to reply thoughtfully. Avoid repeating questions and stay professional. Also, end your response with a follow-up question to keep the conversation going.

Profile:
$profileContext

Conversation so far:
$conversationHistory

Patient: $userInput
""";

      // Send to AI and get response
      final aiResponse = await _chatService.sendMessage(fullPrompt);

      // Save chat to Firestore
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': uid,
        'message': userInput,
        'response': aiResponse,
        'timestamp': Timestamp.now(),
        'tag': selectedTag,
      });

    } catch (e) {
      print("Error during sending message: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Widget _buildMessage(String sender, String content) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$sender: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(content)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Health Assistant')),
      body: Column(
        children: [
          // Tag selectors
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("Filter by: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: filterTag,
                  items: filterTags.map((tag) =>
                      DropdownMenuItem(value: tag, child: Text(tag))).toList(),
                  onChanged: (value) => setState(() => filterTag = value!),
                ),
                const Spacer(),
                const Text("Tag: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedTag,
                  items: tags.map((tag) =>
                      DropdownMenuItem(value: tag, child: Text(tag))).toList(),
                  onChanged: (value) => setState(() => selectedTag = value!),
                ),
              ],
            ),
          ),

          // Chat stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: (filterTag == 'All')
                  ? FirebaseFirestore.instance
                  .collection('chats')
                  .where('uid', isEqualTo: uid)
                  .orderBy('timestamp')
                  .snapshots()
                  : FirebaseFirestore.instance
                  .collection('chats')
                  .where('uid', isEqualTo: uid)
                  .where('tag', isEqualTo: filterTag)
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final chat = docs[index].data() as Map<String, dynamic>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tag: ${chat['tag'] ?? 'General'}",
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        _buildMessage("You", chat['message']),
                        const SizedBox(height: 4),
                        const Text("AI:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Card(
                          color: Colors.green[50],
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(chat['response'] ?? 'No response'),
                          ),
                        ),
                        const Divider(),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input + Send + Mic
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask something...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _listen,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
