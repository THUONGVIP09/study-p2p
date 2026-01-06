import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

/// Web-compatible chat service using WebSocket relay only
/// On web platform, we can't use raw TCP sockets, so we use WebSocket relay
class WebChatService {
  final int currentUserId;
  WebSocketChannel? _relayChannel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get stream => _messageController.stream;
  bool get isConnected => _isConnected;

  WebChatService({required this.currentUserId});

  /// Start the web chat service - connects to WebSocket relay
  Future<void> start() async {
    if (_isConnected) {
      debugPrint('WebChatService already connected');
      return;
    }

    try {
      final relayUrl = AppConfig.chatRelayUrl(currentUserId);
      debugPrint('🔌 [WebChat] Connecting to relay: $relayUrl');

      _relayChannel = WebSocketChannel.connect(Uri.parse(relayUrl));

      // Listen for incoming messages
      _relayChannel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            debugPrint('📥 [WebChat] Received: $msg');

            final fromUserId = msg['from'] as int?;
            final content = msg['content'] as String?;

            if (fromUserId != null && content != null) {
              _messageController.add({
                'friendId': fromUserId,
                'sender': 'peer',
                'content': content,
                'timestamp': msg['timestamp'] ?? DateTime.now().toIso8601String(),
              });
            }
          } catch (e) {
            debugPrint('❌ [WebChat] Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ [WebChat] WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('⚠️ [WebChat] WebSocket closed');
          _isConnected = false;
        },
      );

      _isConnected = true;
      debugPrint('✅ [WebChat] Connected to relay');

      // Start heartbeat
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _sendHeartbeat();
      });
    } catch (e) {
      debugPrint('❌ [WebChat] Failed to connect: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void _sendHeartbeat() {
    if (_relayChannel != null && _isConnected) {
      try {
        _relayChannel!.sink.add(jsonEncode({
          'type': 'heartbeat',
          'userId': currentUserId,
        }));
      } catch (e) {
        debugPrint('❌ [WebChat] Heartbeat failed: $e');
      }
    }
  }

  /// Send message to a friend via relay
  Future<bool> sendToFriend(int friendId, String content) async {
    if (!_isConnected || _relayChannel == null) {
      debugPrint('❌ [WebChat] Not connected, cannot send');
      return false;
    }

    try {
      final message = {
        'type': 'message',
        'from': currentUserId,
        'to': friendId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _relayChannel!.sink.add(jsonEncode(message));
      debugPrint('📤 [WebChat] Sent to friend $friendId: $content');
      return true;
    } catch (e) {
      debugPrint('❌ [WebChat] Send failed: $e');
      return false;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    await _relayChannel?.sink.close();
    await _messageController.close();
    _isConnected = false;
    debugPrint('🛑 [WebChat] Disposed');
  }
}
