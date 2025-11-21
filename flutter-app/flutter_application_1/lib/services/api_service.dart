import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/room.dart';

class ApiService {
  /// Đổi bằng tham số --dart-define=API_BASE=... khi build nếu cần
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:8080',
  );

  // ================= AUTH =================

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
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final body = _safeJson(response.body);
      throw Exception(body['message'] ?? 'Đăng ký thất bại');
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

    final body = _safeJson(response.body);

    if (response.statusCode == 200) {
      // backend trả: { success, token, user: { id, name, ... } }
      final prefs = await SharedPreferences.getInstance();
      if (body['token'] != null) {
        await prefs.setString('token', body['token'] as String);
      }
      if (body['user']?['id'] != null) {
        await prefs.setInt('userId', body['user']['id'] as int);
      }
      return body;
    } else {
      throw Exception(body['message'] ?? 'Đăng nhập thất bại');
    }
  }

  // ================= COMMON =================

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  static Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ================= ROOMS =================

  /// Lấy danh sách phòng mà user đang tham gia
  /// map với GET /api/rooms?userId=...
  static Future<List<Room>> fetchRooms() async {
  final headers = await _authHeaders();
  final uri = Uri.parse('$baseUrl/api/rooms');

  final res = await http.get(uri, headers: headers);
  final rawBody = utf8.decode(res.bodyBytes);

  // log cho chắc, mở console lên coi
  print('GET /api/rooms status=${res.statusCode} body=$rawBody');

  final payload = _safeJson(rawBody);

  if (res.statusCode != 200 || payload['success'] != true) {
    throw Exception(payload['message'] ?? 'Lấy danh sách phòng thất bại');
  }

  final List<dynamic> data = payload['data'] ?? [];
  return data
      .map((e) => Room.fromJson(e as Map<String, dynamic>))
      .toList();
}


  /// Tạo phòng mới – POST /api/rooms
  static Future<Room> createRoom({
    required String name,
    String? description,
    String visibility = 'PUBLIC',
    String? passcode,
    int? maxParticipants,
    int? createdBy,
  }) async {
    final uid = createdBy ?? await getUserId();
    if (uid == null) {
      throw Exception('Chưa có userId – hãy đăng nhập trước');
    }

    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/api/rooms');

    final body = {
      'name': name,
      'description': description,
      'visibility': visibility,
      'passcode': passcode,
      'maxParticipants': maxParticipants,
      'createdBy': uid,
    };

    final res =
        await http.post(uri, headers: headers, body: jsonEncode(body));
    final payload = _safeJson(utf8.decode(res.bodyBytes));

    if (res.statusCode < 200 || res.statusCode >= 300 || payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Tạo phòng thất bại');
    }

    return Room.fromJson(payload['data'] as Map<String, dynamic>);
  }

  /// Join phòng bằng roomCode – POST /api/rooms/join
  static Future<Room> joinRoomByCode({
    required String roomCode,
    String? passcode,
    int? userId,
  }) async {
    final uid = userId ?? await getUserId();
    if (uid == null) {
      throw Exception('Chưa có userId – hãy đăng nhập trước');
    }

    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/api/rooms/join');

    final body = {
      'roomCode': roomCode,
      'userId': uid,
      'passcode': passcode,
    };

    final res =
        await http.post(uri, headers: headers, body: jsonEncode(body));
    final payload = _safeJson(utf8.decode(res.bodyBytes));

    if (res.statusCode < 200 || res.statusCode >= 300 || payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Join phòng thất bại');
    }

    return Room.fromJson(payload['data'] as Map<String, dynamic>);
  }
}
