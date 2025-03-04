import 'dart:convert';
import 'package:http/http.dart' as http;

class MedicalBotService {
  // Replace with your actual GPU endpoint
  final String _apiUrl = 'http://YOUR_SERVER_IP:PORT/api/chat';

  /// Sends userMessage to the server and returns the bot's reply
  Future<String> sendMessageToBot(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': userMessage}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? '(No response from bot)';
      } else {
        return '(Error: ${response.statusCode} ${response.reasonPhrase})';
      }
    } catch (e) {
      return '(Error communicating with server: $e)';
    }
  }
}
