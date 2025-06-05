import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String apiUrl = 'https://7r9l50e2v2.execute-api.us-east-1.amazonaws.com/PROD/ORCAchat';

  ChatService();

  Future<String> sendMessage(String userMessage, String userId) async {
    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({
      "text": userMessage,  // ✅ Only user input
      "userId": userId      // ✅ Used by Lex for session tracking
    });

    try {
      print('📤 Sending to Lambda: $body');

      final response = await http.post(Uri.parse(apiUrl), headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      print('✅ Status: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'No response from AI.';
      } else {
        return 'Error ${response.statusCode}: ${response.reasonPhrase}';
      }
    } catch (e) {
      return 'Request failed: $e';
    }
  }
}
