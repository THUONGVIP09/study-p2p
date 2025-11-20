import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = "http://localhost:8080/api/auth";

  static Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/register');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": email,
          "password": password,
          "displayName": displayName,
        }),
      );
      if (res.statusCode == 201) return true;
      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/login');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email, "password": password}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }
}
