import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service quản lý lưu/đọc lịch sử chat local (JSON)
/// Thiết kế để tránh xung đột khi:
/// - Nhiều instance chạy trên cùng máy (demo)
/// - Các máy khác nhau (production)
class FriendChatStorageService {
  static const String _dirName = 'p2p_friend_chats';
  static String? _instanceId;
  
  /// Tạo unique instance ID cho mỗi lần chạy app
  /// Dùng để phân biệt các instance trên cùng máy
  static Future<String> _getInstanceId() async {
    if (_instanceId != null) return _instanceId!;
    
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    
    // Instance ID = userId + timestamp để tránh xung đột
    // Mỗi user có file riêng, nhưng trên cùng máy các instance khác nhau
    // sẽ sử dụng userId làm phân biệt
    _instanceId = 'user_${userId ?? 0}';
    return _instanceId!;
  }

  /// Lấy thư mục lưu trữ chat
  static Future<Directory> _getStorageDir() async {
    if (kIsWeb) {
      throw UnsupportedError('File storage not supported on web');
    }
    
    final appDir = await getApplicationDocumentsDirectory();
    final chatDir = Directory('${appDir.path}/$_dirName');
    
    if (!await chatDir.exists()) {
      await chatDir.create(recursive: true);
      debugPrint('📁 Created chat storage directory: ${chatDir.path}');
    }
    
    return chatDir;
  }

  /// Tạo file path cho conversation giữa 2 users
  /// Format: chat_{minId}_{maxId}_user_{currentUserId}.json
  /// 
  /// Giải thích:
  /// - minId_maxId: đảm bảo 2 user luôn có cùng conversation ID (1_5 không phải 5_1)
  /// - user_{currentUserId}: mỗi user có file riêng để tránh xung đột khi demo nhiều instance
  static Future<File> _getChatFile(int currentUserId, int friendId) async {
    final dir = await _getStorageDir();
    
    // Sắp xếp ID để tạo conversation ID nhất quán
    final minId = currentUserId < friendId ? currentUserId : friendId;
    final maxId = currentUserId > friendId ? currentUserId : friendId;
    
    // File riêng cho mỗi user để tránh xung đột
    final fileName = 'chat_${minId}_${maxId}_user_$currentUserId.json';
    final file = File('${dir.path}/$fileName');
    
    debugPrint('📁 Chat file: ${file.path}');
    return file;
  }

  /// Load tin nhắn với một friend
  static Future<List<Map<String, dynamic>>> loadMessages(
    int currentUserId,
    int friendId,
  ) async {
    if (kIsWeb) {
      // Web: sử dụng SharedPreferences
      return _loadMessagesWeb(currentUserId, friendId);
    }
    
    try {
      final file = await _getChatFile(currentUserId, friendId);
      
      if (!await file.exists()) {
        debugPrint('📂 No chat history file exists');
        return [];
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) {
        return [];
      }
      
      final data = jsonDecode(content) as Map<String, dynamic>;
      final messages = (data['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      debugPrint('📖 Loaded ${messages.length} messages from file');
      return messages;
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      return [];
    }
  }

  /// Web: Load từ SharedPreferences
  static Future<List<Map<String, dynamic>>> _loadMessagesWeb(
    int currentUserId,
    int friendId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getWebStorageKey(currentUserId, friendId);
      final content = prefs.getString(key);
      
      if (content == null || content.isEmpty) {
        return [];
      }
      
      final data = jsonDecode(content) as Map<String, dynamic>;
      final messages = (data['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      debugPrint('📖 [Web] Loaded ${messages.length} messages');
      return messages;
    } catch (e) {
      debugPrint('❌ [Web] Error loading messages: $e');
      return [];
    }
  }

  static String _getWebStorageKey(int currentUserId, int friendId) {
    final minId = currentUserId < friendId ? currentUserId : friendId;
    final maxId = currentUserId > friendId ? currentUserId : friendId;
    return 'p2p_chat_${minId}_${maxId}_user_$currentUserId';
  }

  /// Lưu tin nhắn
  static Future<void> saveMessages(
    int currentUserId,
    int friendId,
    List<Map<String, dynamic>> messages,
  ) async {
    if (kIsWeb) {
      await _saveMessagesWeb(currentUserId, friendId, messages);
      return;
    }
    
    try {
      final file = await _getChatFile(currentUserId, friendId);
      
      final data = {
        'version': 1,
        'currentUserId': currentUserId,
        'friendId': friendId,
        'lastUpdated': DateTime.now().toIso8601String(),
        'messages': messages,
      };
      
      await file.writeAsString(jsonEncode(data), flush: true);
      debugPrint('💾 Saved ${messages.length} messages to file');
    } catch (e) {
      debugPrint('❌ Error saving messages: $e');
    }
  }

  /// Web: Save to SharedPreferences
  static Future<void> _saveMessagesWeb(
    int currentUserId,
    int friendId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getWebStorageKey(currentUserId, friendId);
      
      final data = {
        'version': 1,
        'currentUserId': currentUserId,
        'friendId': friendId,
        'lastUpdated': DateTime.now().toIso8601String(),
        'messages': messages,
      };
      
      await prefs.setString(key, jsonEncode(data));
      debugPrint('💾 [Web] Saved ${messages.length} messages');
    } catch (e) {
      debugPrint('❌ [Web] Error saving messages: $e');
    }
  }

  /// Thêm một tin nhắn mới
  static Future<void> addMessage(
    int currentUserId,
    int friendId,
    Map<String, dynamic> message,
  ) async {
    // Đảm bảo có timestamp và messageId
    if (!message.containsKey('timestamp')) {
      message['timestamp'] = DateTime.now().toIso8601String();
    }
    if (!message.containsKey('messageId')) {
      message['messageId'] = '${currentUserId}_${DateTime.now().microsecondsSinceEpoch}';
    }
    
    // Load existing messages
    final messages = await loadMessages(currentUserId, friendId);
    
    // Check for duplicate (bằng messageId hoặc content+timestamp)
    final isDuplicate = messages.any((m) => 
      m['messageId'] == message['messageId'] ||
      (m['content'] == message['content'] && 
       m['timestamp'] == message['timestamp'] &&
       m['sender'] == message['sender'])
    );
    
    if (isDuplicate) {
      debugPrint('⚠️ Duplicate message detected, skipping save');
      return;
    }
    
    // Add new message
    messages.add(message);
    
    // Save
    await saveMessages(currentUserId, friendId, messages);
  }

  /// Xóa toàn bộ lịch sử chat với một friend
  static Future<void> clearChat(int currentUserId, int friendId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = _getWebStorageKey(currentUserId, friendId);
      await prefs.remove(key);
      debugPrint('🗑️ [Web] Cleared chat history');
      return;
    }
    
    try {
      final file = await _getChatFile(currentUserId, friendId);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted chat history file');
      }
    } catch (e) {
      debugPrint('❌ Error clearing chat: $e');
    }
  }

  /// Merge messages từ 2 sources (khi sync từ server hoặc merge conflict)
  static List<Map<String, dynamic>> mergeMessages(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    final Map<String, Map<String, dynamic>> merged = {};
    
    // Add all local messages
    for (final msg in local) {
      final id = msg['messageId'] ?? '${msg['timestamp']}_${msg['sender']}';
      merged[id] = msg;
    }
    
    // Add remote messages (sẽ override nếu trùng ID)
    for (final msg in remote) {
      final id = msg['messageId'] ?? '${msg['timestamp']}_${msg['sender']}';
      if (!merged.containsKey(id)) {
        merged[id] = msg;
      }
    }
    
    // Sort by timestamp
    final result = merged.values.toList();
    result.sort((a, b) {
      final tsA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
      final tsB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
      return tsA.compareTo(tsB);
    });
    
    return result;
  }
}
