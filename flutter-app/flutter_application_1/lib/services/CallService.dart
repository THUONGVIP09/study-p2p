import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/call_session.dart';
import 'api_service.dart';

class CallService {
  const CallService();

  // ==== helpers chung ====

  Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiService.baseUrl}$path')
        .replace(queryParameters: query);
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    final payload = _safeJson(utf8.decode(res.bodyBytes));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET $path failed: ${res.statusCode} ${payload['message']}');
    }
    return payload;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    final res = await http.post(
      _uri(path, query),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    final payload = _safeJson(utf8.decode(res.bodyBytes));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST $path failed: ${res.statusCode} ${payload['message']}');
    }
    return payload;
  }

  // ==== API chính ====

  /// GET /api/calls/latest?roomId=...
  Future<CallSession?> getLatestForRoom(int roomId) async {
    final json =
        await _get('/api/calls/latest', query: {'roomId': '$roomId'});
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Lỗi tải call session');
    }
    if (json['data'] == null) return null;
    return CallSession.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// POST /api/calls/start
  Future<CallSession> startCall({
    required int roomId,
    required int userId,
    required String roomCode, // dùng làm sfuRoomId
  }) async {
    final body = {
      'roomId': roomId,
      'userId': userId,
      'topology': 'sfu',
      'sfuRegion': null,
      'sfuRoomId': roomCode,
    };
    final json = await _post('/api/calls/start', body);
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Lỗi start call');
    }
    return CallSession.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// POST /api/calls/join
  Future<void> joinCall({
    required int callId,
    required int userId,
    bool micMuted = false,
    bool camEnabled = true,
  }) async {
    final body = {
      'callId': callId,
      'userId': userId,
      'joinMode': 'SFU',
      'micMuted': micMuted,
      'camEnabled': camEnabled,
    };
    final json = await _post('/api/calls/join', body);
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Lỗi join call');
    }
  }

  /// POST /api/calls/heartbeat
  Future<void> heartbeat({
    required int callId,
    required int userId,
    bool? micMuted,
    bool? camEnabled,
    bool? screenshare,
    bool? handRaised,
    String? statsJson,
  }) async {
    final body = {
      'callId': callId,
      'userId': userId,
      'micMuted': micMuted,
      'camEnabled': camEnabled,
      'screenshare': screenshare,
      'handRaised': handRaised,
      'statsJson': statsJson,
    };
    final json = await _post('/api/calls/heartbeat', body);
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Lỗi heartbeat');
    }
  }

  /// POST /api/calls/leave
  Future<void> leave({
    required int callId,
    required int userId,
  }) async {
    final body = {
      'callId': callId,
      'userId': userId,
      'joinMode': 'SFU',
      'micMuted': true,
      'camEnabled': false,
    };
    final json = await _post('/api/calls/leave', body);
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Lỗi leave call');
    }
  }

  /// POST /api/calls/end (cho host)
  Future<void> endCall({
    required int callId,
    String? reason,
  }) async {
    final body = {
      'callId': callId,
      'endReason': reason ?? 'HOST_END',
    };
    final json = await _post('/api/calls/end', body);
    if (json['success'] != true) {
      throw Exception(json['message'] ?? 'Lỗi end call');
    }
  }
}
