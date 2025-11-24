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

  static Future<Map<String, dynamic>> sendFriendRequest(int toUserId) async {
    final uri = Uri.parse('${_base()}/api/friend-requests');
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'toUserId': toUserId}),
    );

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to send friend request');
    }
    return body;
  }

  static Future<Map<String, dynamic>> acceptFriendRequest(int requestId) async {
    final uri = Uri.parse('${_base()}/api/friend-requests/$requestId/accept');
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.post(uri, headers: headers);

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to accept friend request');
    }
    return body;
  }

  static Future<Map<String, dynamic>> rejectFriendRequest(int requestId) async {
    final uri = Uri.parse('${_base()}/api/friend-requests/$requestId/reject');
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.post(uri, headers: headers);

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to reject friend request');
    }
    return body;
  }

  static Future<Map<String, dynamic>> cancelFriendRequest(int requestId) async {
    final uri = Uri.parse('${_base()}/api/friend-requests/$requestId');
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.delete(uri, headers: headers);

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to cancel friend request');
    }
    return body;
  }

  static Future<Map<String, dynamic>> removeFriend(int userId) async {
    final uri = Uri.parse('${_base()}/api/friends/$userId');
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.delete(uri, headers: headers);

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to remove friend');
    }
    return body;
  }

  static Future<Map<String, dynamic>> blockUser(int blockedUserId) async {
    final uri = Uri.parse('${_base()}/api/blocked-users');
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'blockedUserId': blockedUserId}),
    );

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to block user');
    }
    return body;
  }

  static Future<Map<String, dynamic>> unblockUser(int userId) async {
    final uri = Uri.parse('${_base()}/api/blocked-users/$userId');
    final token = await ApiService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';

    final res = await http.delete(uri, headers: headers);

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to unblock user');
    }
    return body;
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
