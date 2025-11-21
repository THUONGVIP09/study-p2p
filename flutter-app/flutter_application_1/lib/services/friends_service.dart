import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class FriendsService {
  static Future<List<Map<String, dynamic>>> getFriends({String q = ''}) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/friends').replace(
      queryParameters: {if (q.isNotEmpty) 'q': q},
    );
    final token = await ApiService.getToken();
    final res = await http.get(uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {});
    if (res.statusCode != 200)
      throw Exception('Failed to load friends: ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getFriendRequests(
      {String q = ''}) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/friend-requests').replace(
      queryParameters: {if (q.isNotEmpty) 'q': q},
    );
    final token = await ApiService.getToken();
    final res = await http.get(uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {});
    if (res.statusCode != 200)
      throw Exception('Failed to load friend requests: ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers(
      {String q = ''}) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/blocked-users').replace(
      queryParameters: {if (q.isNotEmpty) 'q': q},
    );
    final token = await ApiService.getToken();
    final res = await http.get(uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {});
    if (res.statusCode != 200)
      throw Exception('Failed to load blocked users: ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> findFriends(
      {required String q}) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/find-friends').replace(
      queryParameters: {'q': q},
    );
    final token = await ApiService.getToken();
    final res = await http.get(uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {});
    if (res.statusCode != 200)
      throw Exception('Failed to search users: ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }
}
