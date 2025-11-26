import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ChatApiService {
  static String get baseUrl => AppConfig.httpBaseUrl;

  static Future<void> registerPeer(
      {required int userId, required String ip, required int port}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/chat/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'ip': ip, 'port': port}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Register failed: ${resp.body}');
    }
  }

  static Future<void> heartbeat({required int userId}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/chat/heartbeat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Heartbeat failed: ${resp.body}');
    }
  }

  static Future<Map<String, dynamic>> getFriendPeerInfo(int friendId) async {
    final resp = await http.get(Uri.parse('$baseUrl/api/chat/peer/$friendId'));
    if (resp.statusCode != 200) {
      throw Exception('Get peer failed: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
