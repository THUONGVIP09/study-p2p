import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

class JoinApprovalService {
  WebSocketChannel? _ws;
  final _approvalController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get approvalStream => _approvalController.stream;

  Future<void> connect({
    required String roomCode,
    required int userId,
    required String uid,
    required String name,
  }) async {
    final signalingUrl = AppConfig.httpBaseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst(':8080', ':8081');

    final uri = Uri.parse('$signalingUrl/ws');
    _ws = WebSocketChannel.connect(uri);

    // Join room qua signaling
    _ws!.sink.add(jsonEncode({
      't': 'join',
      'room': roomCode,
      'uid': uid,
      'name': name,
      'userId': userId,
    }));

    // Lắng nghe events
    _ws!.stream.listen((data) {
      try {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        final type = msg['t'];

        if (type == 'join_request' ||
            type == 'join_approved' ||
            type == 'join_rejected' ||
            type == 'join_request_sent') {
          _approvalController.add(msg);
        }
      } catch (e) {
        print('Error parsing WS message: $e');
      }
    });
  }

  void joinRoom({
    required String roomCode,
    required String uid,
    required String name,
    required int userId,
  }) {
    _ws?.sink.add(jsonEncode({
      't': 'join',
      'room': roomCode,
      'uid': uid,
      'name': name,
      'userId': userId,
    }));
  }

  void requestJoin(String roomCode) {
    _ws?.sink.add(jsonEncode({
      't': 'join_request',
      'room': roomCode,
    }));
  }

  void approveRequest(String requestId, String roomCode) {
    _ws?.sink.add(jsonEncode({
      't': 'join_approved',
      'requestId': requestId,
      'room': roomCode,
    }));
  }

  void rejectRequest(String requestId, String roomCode) {
    _ws?.sink.add(jsonEncode({
      't': 'join_rejected',
      'requestId': requestId,
      'room': roomCode,
    }));
  }

  void dispose() {
    _ws?.sink.close();
    _approvalController.close();
  }
}
