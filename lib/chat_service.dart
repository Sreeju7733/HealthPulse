import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String apiKey;

  // Constructor with default API key
  ChatService({
    this.apiKey = 'AIzaSyDepgy1N9cUQh61EUu-dYRZxahG2f_5by0',
  });

  Future<String> sendMessage(String message) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final headers = {
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": message}
          ]
        }
      ]
    });

    print("Sending message to Gemini...");

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      print("Response received: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Response body: $data");
        return data['candidates'][0]['content']['parts'][0]['text'] ??
            'No response from Gemini.';
      } else {
        return 'Failed: ${response.statusCode} - ${response.reasonPhrase}';
      }
    } catch (e) {
      print("Caught error: $e");
      return 'Error: $e';
    }
  }
}
