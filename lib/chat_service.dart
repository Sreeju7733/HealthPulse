import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // Replace with your Firebase Cloud Function URL after deploy
  final String cloudFunctionUrl;

  ChatService({
    required this.cloudFunctionUrl,
  });

  /// Sends chat messages to your Firebase Cloud Function which
  /// internally calls Gemini API and returns AI's reply.
  Future<String> sendMessage(List<Map<String, String>> messages) async {
    final url = Uri.parse(cloudFunctionUrl);

    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({'messages': messages});

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] ?? 'No response from AI assistant.';
        return reply;
      } else {
        return 'Error ${response.statusCode}: ${response.reasonPhrase}';
      }
    } catch (e) {
      return 'Request failed: $e';
    }
  }
}
