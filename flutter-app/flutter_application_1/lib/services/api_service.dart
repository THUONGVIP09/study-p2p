import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room.dart';
class ApiService {
 static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:8080',
  );
  // Đăng ký
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          jsonDecode(response.body)['message'] ?? 'Đăng ký thất bại');
    }
  }

  // Đăng nhập
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Lưu token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return data;
    } else {
      throw Exception(
          jsonDecode(response.body)['message'] ?? 'Đăng nhập thất bại');
    }
  }

  // Lấy token cho API sau
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
    Future<List<Room>> fetchRooms({String q = '', int limit = 50, int offset = 0}) async {
    final uri = Uri.parse('$baseUrl/api/rooms')
        .replace(queryParameters: {
          if (q.isNotEmpty) 'q': q,
          'limit': '$limit',
          'offset': '$offset',
        });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Fetch rooms failed: ${res.statusCode} ${res.body}');
    }
    final payload = json.decode(res.body) as Map<String, dynamic>;
    final list = (payload['data'] as List).cast<Map<String, dynamic>>();
    return list.map((e) => Room.fromJson(e)).toList();
  }
}
