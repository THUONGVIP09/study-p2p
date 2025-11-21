import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class FriendsService {
  static String _base() => ApiService.baseUrl;

  static Future<List<Map<String, dynamic>>> getFriends({String q = ''}) async {
    final uri = Uri.parse('${_base()}/api/friends')
        .replace(queryParameters: q.isNotEmpty ? {'q': q} : null);
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      final body = _safeJson(res.body);
      throw Exception(body['message'] ?? 'Failed to get friends');
    }
    final payload = _safeJson(res.body);
    final data = payload['data'] ?? payload['friends'] ?? [];
    return List<Map<String, dynamic>>.from(
        (data as List).map((e) => Map<String, dynamic>.from(e)));
  }

  static Future<List<Map<String, dynamic>>> getFriendRequests(
      {String q = ''}) async {
    final uri = Uri.parse('${_base()}/api/friend-requests')
        .replace(queryParameters: q.isNotEmpty ? {'q': q} : null);
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      final body = _safeJson(res.body);
      throw Exception(body['message'] ?? 'Failed to get friend requests');
    }
    final payload = _safeJson(res.body);
    final data = payload['data'] ?? payload['requests'] ?? [];
    return List<Map<String, dynamic>>.from(
        (data as List).map((e) => Map<String, dynamic>.from(e)));
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers(
      {String q = ''}) async {
    final uri = Uri.parse('${_base()}/api/blocked-users')
        .replace(queryParameters: q.isNotEmpty ? {'q': q} : null);
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      final body = _safeJson(res.body);
      throw Exception(body['message'] ?? 'Failed to get blocked users');
    }
    final payload = _safeJson(res.body);
    final data = payload['data'] ?? payload['blocked'] ?? [];
    return List<Map<String, dynamic>>.from(
        (data as List).map((e) => Map<String, dynamic>.from(e)));
  }

  static Future<List<Map<String, dynamic>>> findFriends({String q = ''}) async {
    final uri = Uri.parse('${_base()}/api/find-friends')
        .replace(queryParameters: q.isNotEmpty ? {'q': q} : null);
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      final body = _safeJson(res.body);
      throw Exception(body['message'] ?? 'Failed to find friends');
    }
    final payload = _safeJson(res.body);
    final data = payload['data'] ?? payload['users'] ?? [];
    return List<Map<String, dynamic>>.from(
        (data as List).map((e) => Map<String, dynamic>.from(e)));
  }

  static Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
