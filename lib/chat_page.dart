import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  late ChatService _chatService;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  String filterTag = 'All';
  final List<String> filterTags = ['All', 'General', 'Sleep', 'Stress', 'Diet', 'Exercise'];
  String selectedTag = 'General';
  final List<String> tags = ['General', 'Sleep', 'Stress', 'Diet', 'Exercise'];

  late stt.SpeechToText _speech;
  bool _isListening = false;

  // ✅ Chatbase credentials
  final String chatbaseApiKey = '70k79qb7xr7spq7tvir7pxzxp8cs0aou';
  final String chatbotId = 'xlD4I1S_Po_eQ3eke4dD8';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _chatService = ChatService(apiKey: chatbaseApiKey, chatbotId: chatbotId);
  }

  Future<void> _sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    _controller.clear();

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();

      String profileContext = "";
      if (userData != null) {
        final age = userData['age'] ?? 'unknown age';
        final goal = userData['goal'] ?? 'general wellness';
        final sleepHours = userData['sleepHours'] ?? 'not tracked';
        profileContext =
        "User is $age years old, with a health goal of '$goal', and average sleep duration is $sleepHours hours.";
      }

      final fullPrompt = "$profileContext\nUser: $userInput";

      // ✅ Send to Chatbase
      final aiResponse = await _chatService.sendMessage(fullPrompt);

      // ✅ Save to Firestore
      await FirebaseFirestore.instance.collection('chats').add({
        'uid': uid,
        'message': userInput,
        'response': aiResponse,
        'timestamp': Timestamp.now(),
        'tag': selectedTag,
      });
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get Chatbase response')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Health Assistant')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text("Filter by: ", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: filterTag,
                  items: filterTags.map((tag) {
                    return DropdownMenuItem(value: tag, child: Text(tag));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      filterTag = value!;
                    });
                  },
                ),
                Spacer(),
                Text("Tag message: ", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedTag,
                  items: tags.map((tag) {
                    return DropdownMenuItem(value: tag, child: Text(tag));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedTag = value!;
                    });
                  },
                ),
              ],
            ),
          ),

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
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final chat = docs[index].data() as Map<String, dynamic>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tag: ${chat['tag'] ?? 'General'}", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        _buildMessage("You", chat['message']),
                        SizedBox(height: 4),
                        Text("AI:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Card(
                          color: Colors.green[50],
                          elevation: 2,
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(chat['response']),
                          ),
                        ),
                        Divider(),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _listen,
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String sender, String content) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$sender: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(content)),
        ],
      ),
    );
  }
}
