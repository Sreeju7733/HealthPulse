import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiChatService {
  final String apiKey = '70k79qb7xr7spq7tvir7pxzxp8cs0aou';

  Future<String> sendMessages(List<Map<String, String>> messages) async {
    final prompt = messages.map((m) => "${m['role']}: ${m['text']}").join("\n");

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$70k79qb7xr7spq7tvir7pxzxp8cs0aou',
    );

    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final reply = decoded['candidates'][0]['content']['parts'][0]['text'];
      return reply;
    } else {
      throw Exception("Gemini API error: ${response.body}");
    }
  }
}
