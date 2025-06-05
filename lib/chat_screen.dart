import 'package:flutter/material.dart';
import 'chat_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts flutterTts = FlutterTts();
  final List<Map<String, String>> messages = [];

  bool isLoading = false;

  final String apiUrl = 'https://7r9l50e2v2.execute-api.us-east-1.amazonaws.com/PROD/ORCAchat';

  late ChatService chatService;

  @override
  void initState() {
    super.initState();
    chatService = ChatService(apiUrl: apiUrl);
  }

  Future<void> speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  String inferTag(String text) {
    text = text.toLowerCase();
    if (text.contains('fever') || text.contains('pain') || text.contains('nausea')) {
      return 'symptom';
    } else if (text.contains('drink water') || text.contains('take rest') || text.contains('consult')) {
      return 'advice';
    } else if (text.contains('hello') || text.contains('hi')) {
      return 'greeting';
    } else {
      return 'general';
    }
  }

  Color _getColorForTag(String tag) {
    switch (tag) {
      case 'symptom':
        return Colors.yellow[100]!;
      case 'advice':
        return Colors.green[100]!;
      case 'greeting':
        return Colors.purple[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Future<void> _sendMessage() async {
    final userInput = _controller.text.trim();
    if (userInput.isEmpty || isLoading) return;

    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'text': userInput});
      _controller.clear();
    });

    try {
      final reply = await chatService.sendMessage(messages);
      final tag = inferTag(reply);

      setState(() {
        messages.add({
          'role': 'assistant',
          'text': reply,
          'tag': tag,
        });
        isLoading = false;
      });

      await speak(reply);

      await Future.delayed(const Duration(milliseconds: 300));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        messages.add({'role': 'assistant', 'text': 'Error: ${e.toString()}', 'tag': 'error'});
      });
    }
  }

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    final tag = message['tag'] ?? 'general';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : _getColorForTag(tag),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['text'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            if (!isUser && tag != 'general')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tag: $tag',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
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
            child: messages.isEmpty
                ? const Center(child: Text("Ask me anything about your health."))
                : ListView.builder(
              controller: _scrollController,
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
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !isLoading,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
