import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

/// Global singleton chat service that maintains a single WebSocket connection
/// to the chat-relay server for the entire app lifetime.
/// 
/// This prevents connection conflicts when multiple screens try to connect.
class GlobalChatService {
  static GlobalChatService? _instance;
  static GlobalChatService get instance {
    _instance ??= GlobalChatService._();
    return _instance!;
  }
  
  GlobalChatService._();
  
  int? _currentUserId;
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  
  /// Stream of incoming messages
  Stream<Map<String, dynamic>> get stream => _messageController.stream;
  
  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Get current user ID
  int? get currentUserId => _currentUserId;
  
  /// Initialize and connect with userId
  /// Only connects if not already connected or if userId changed
  Future<void> connect(int userId) async {
    if (_isConnected && _currentUserId == userId) {
      debugPrint('🔌 [GlobalChat] Already connected for user $userId');
      return;
    }
    
    // Disconnect existing connection if userId changed
    if (_currentUserId != null && _currentUserId != userId) {
      debugPrint('🔄 [GlobalChat] User changed, reconnecting...');
      await disconnect();
    }
    
    _currentUserId = userId;
    
    try {
      final relayUrl = AppConfig.chatRelayUrl(userId);
      debugPrint('🔌 [GlobalChat] Connecting to relay: $relayUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(relayUrl));
      
      // Listen for incoming messages
      _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          debugPrint('❌ [GlobalChat] WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('⚠️ [GlobalChat] WebSocket closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
      
      _isConnected = true;
      debugPrint('✅ [GlobalChat] Connected for user $userId');
      
      // Start heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _sendHeartbeat();
      });
    } catch (e) {
      debugPrint('❌ [GlobalChat] Failed to connect: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }
  
  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      debugPrint('📥 [GlobalChat] Received: $msg');
      
      final fromUserId = msg['from'];
      final content = msg['content'] as String?;
      
      // Parse fromUserId as int (could be int or num from JSON)
      int? fromId;
      if (fromUserId is int) {
        fromId = fromUserId;
      } else if (fromUserId is num) {
        fromId = fromUserId.toInt();
      }
      
      if (fromId != null && content != null) {
        // Skip messages from self
        if (fromId == _currentUserId) {
          debugPrint('⚠️ [GlobalChat] Skipping message from self');
          return;
        }
        
        _messageController.add({
          'friendId': fromId,
          'sender': 'peer',
          'content': content,
          'timestamp': msg['timestamp'] ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('❌ [GlobalChat] Error parsing message: $e');
    }
  }
  
  void _sendHeartbeat() {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode({
          'type': 'heartbeat',
          'from': _currentUserId,
        }));
      } catch (e) {
        debugPrint('❌ [GlobalChat] Heartbeat failed: $e');
      }
    }
  }
  
  void _scheduleReconnect() {
    if (_currentUserId != null) {
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isConnected && _currentUserId != null) {
          debugPrint('🔄 [GlobalChat] Attempting reconnect...');
          connect(_currentUserId!);
        }
      });
    }
  }
  
  /// Send message to a friend
  Future<bool> sendToFriend(int friendId, String content) async {
    if (!_isConnected || _channel == null || _currentUserId == null) {
      debugPrint('❌ [GlobalChat] Not connected, cannot send');
      return false;
    }
    
    try {
      final message = {
        'type': 'message',
        'from': _currentUserId,
        'to': friendId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _channel!.sink.add(jsonEncode(message));
      debugPrint('📤 [GlobalChat] Sent to friend $friendId: $content');
      return true;
    } catch (e) {
      debugPrint('❌ [GlobalChat] Send failed: $e');
      return false;
    }
  }
  
  /// Disconnect and cleanup
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    try {
      await _channel?.sink.close();
    } catch (e) {
      debugPrint('⚠️ [GlobalChat] Error closing channel: $e');
    }
    
    _channel = null;
    _isConnected = false;
    _currentUserId = null;
    
    debugPrint('🛑 [GlobalChat] Disconnected');
  }
  
  /// Dispose the service (call on app exit)
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    _instance = null;
  }
}
