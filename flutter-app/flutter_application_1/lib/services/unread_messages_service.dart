import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service quản lý tin nhắn chưa đọc từ bạn bè
/// Lưu trữ bằng JSON (không dùng database)
/// 
/// Features:
/// - Đếm số tin nhắn chưa đọc từ mỗi friend
/// - Lưu tin nhắn khi user chưa vào giao diện chat
/// - Xóa tin nhắn chưa đọc khi user mở chat
/// - Mỗi user có file riêng để tránh xung đột khi demo nhiều instance
class UnreadMessagesService {
  static const String _storageKeyPrefix = 'unread_messages_user_';
  static const String _fileNamePrefix = 'unread_messages_user_';
  
  // Current user ID for file separation
  static int? _currentUserId;
  
  // In-memory cache
  static Map<int, List<Map<String, dynamic>>>? _cache;
  
  // Callback khi có thay đổi (để update UI)
  static final List<Function(Map<int, int>)> _listeners = [];
  
  /// Khởi tạo service với userId (gọi khi user login)
  static Future<void> initialize(int userId) async {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _cache = null; // Clear cache khi đổi user
      debugPrint('📦 UnreadMessagesService initialized for user $userId');
    }
  }
  
  /// Lấy userId hiện tại (từ SharedPreferences nếu chưa set)
  static Future<int> _getCurrentUserId() async {
    if (_currentUserId != null) return _currentUserId!;
    
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId') ?? 0;
    return _currentUserId!;
  }
  
  /// Đăng ký listener để nhận thông báo khi có thay đổi
  static void addListener(Function(Map<int, int>) listener) {
    _listeners.add(listener);
  }
  
  /// Hủy listener
  static void removeListener(Function(Map<int, int>) listener) {
    _listeners.remove(listener);
  }
  
  /// Thông báo cho tất cả listeners
  static void _notifyListeners() async {
    final counts = await getUnreadCounts();
    for (final listener in _listeners) {
      listener(counts);
    }
  }
  
  /// Lấy file storage - mỗi user có file riêng
  static Future<File> _getStorageFile() async {
    if (kIsWeb) {
      throw UnsupportedError('Use SharedPreferences on web');
    }
    final userId = await _getCurrentUserId();
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileNamePrefix$userId.json');
  }
  
  /// Lấy storage key cho web - mỗi user có key riêng
  static Future<String> _getStorageKey() async {
    final userId = await _getCurrentUserId();
    return '$_storageKeyPrefix$userId';
  }
  
  /// Load dữ liệu từ storage
  static Future<Map<int, List<Map<String, dynamic>>>> _loadData() async {
    if (_cache != null) return _cache!;
    
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final key = await _getStorageKey();
        final json = prefs.getString(key);
        if (json == null || json.isEmpty) {
          _cache = {};
          return _cache!;
        }
        _cache = _parseJson(json);
      } else {
        final file = await _getStorageFile();
        if (!await file.exists()) {
          _cache = {};
          return _cache!;
        }
        final json = await file.readAsString();
        if (json.isEmpty) {
          _cache = {};
          return _cache!;
        }
        _cache = _parseJson(json);
      }
    } catch (e) {
      debugPrint('❌ Error loading unread messages: $e');
      _cache = {};
    }
    
    return _cache!;
  }
  
  /// Parse JSON thành Map
  static Map<int, List<Map<String, dynamic>>> _parseJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final result = <int, List<Map<String, dynamic>>>{};
    
    data.forEach((key, value) {
      final friendId = int.tryParse(key);
      if (friendId != null && value is List) {
        result[friendId] = value.cast<Map<String, dynamic>>();
      }
    });
    
    return result;
  }
  
  /// Lưu dữ liệu vào storage
  static Future<void> _saveData() async {
    if (_cache == null) return;
    
    try {
      // Convert Map<int, List> to Map<String, List> for JSON
      final jsonMap = <String, dynamic>{};
      _cache!.forEach((key, value) {
        jsonMap[key.toString()] = value;
      });
      
      final json = jsonEncode(jsonMap);
      
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final key = await _getStorageKey();
        await prefs.setString(key, json);
      } else {
        final file = await _getStorageFile();
        await file.writeAsString(json, flush: true);
      }
      
      final userId = await _getCurrentUserId();
      debugPrint('💾 Saved unread messages for user $userId');
    } catch (e) {
      debugPrint('❌ Error saving unread messages: $e');
    }
  }
  
  /// Thêm tin nhắn chưa đọc từ một friend
  static Future<void> addUnreadMessage({
    required int friendId,
    required String senderName,
    required String content,
    String? timestamp,
  }) async {
    final data = await _loadData();
    
    if (!data.containsKey(friendId)) {
      data[friendId] = [];
    }
    
    final message = {
      'friendId': friendId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp ?? DateTime.now().toIso8601String(),
    };
    
    data[friendId]!.add(message);
    
    await _saveData();
    _notifyListeners();
    
    debugPrint('📩 Added unread message from friend $friendId. Total: ${data[friendId]!.length}');
  }
  
  /// Lấy số tin nhắn chưa đọc từ mỗi friend
  static Future<Map<int, int>> getUnreadCounts() async {
    final data = await _loadData();
    final counts = <int, int>{};
    
    data.forEach((friendId, messages) {
      counts[friendId] = messages.length;
    });
    
    return counts;
  }
  
  /// Lấy tổng số tin nhắn chưa đọc
  static Future<int> getTotalUnreadCount() async {
    final counts = await getUnreadCounts();
    return counts.values.fold<int>(0, (int sum, int count) => sum + count);
  }
  
  /// Lấy số tin nhắn chưa đọc từ một friend cụ thể
  static Future<int> getUnreadCountForFriend(int friendId) async {
    final data = await _loadData();
    return data[friendId]?.length ?? 0;
  }
  
  /// Lấy danh sách tin nhắn chưa đọc từ một friend
  static Future<List<Map<String, dynamic>>> getUnreadMessages(int friendId) async {
    final data = await _loadData();
    return data[friendId] ?? [];
  }
  
  /// Đánh dấu tất cả tin nhắn từ friend là đã đọc
  static Future<void> markAsRead(int friendId) async {
    final data = await _loadData();
    
    if (data.containsKey(friendId)) {
      data.remove(friendId);
      await _saveData();
      _notifyListeners();
      debugPrint('✅ Marked all messages from friend $friendId as read');
    }
  }
  
  /// Xóa tất cả tin nhắn chưa đọc
  static Future<void> clearAll() async {
    _cache = {};
    await _saveData();
    _notifyListeners();
    debugPrint('🗑️ Cleared all unread messages');
  }
  
  /// Force reload từ storage (bỏ cache)
  static Future<void> refresh() async {
    _cache = null;
    await _loadData();
    _notifyListeners();
  }
}
