import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service quản lý lưu/đọc lịch sử chat local (JSON)
class ChatStorageService {
  static const String _fileName = 'p2p_chat_history.json';

  /// Lấy đường dẫn file JSON
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Đọc toàn bộ lịch sử chat
  /// Format: { "peer_id_1": [messages...], "peer_id_2": [messages...] }
  static Future<Map<String, List<Map<String, dynamic>>>> loadHistory() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return {};
      }

      final content = await file.readAsString();
      if (content.isEmpty) return {};

      final Map<String, dynamic> decoded = jsonDecode(content);

      // Convert to proper type
      Map<String, List<Map<String, dynamic>>> result = {};
      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = value.cast<Map<String, dynamic>>();
        }
      });

      return result;
    } catch (e) {
      print('Error loading chat history: $e');
      return {};
    }
  }

  /// Lưu lịch sử chat
  static Future<void> saveHistory(
      Map<String, List<Map<String, dynamic>>> history) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode(history);
      await file.writeAsString(encoded);
    } catch (e) {
      print('Error saving chat history: $e');
    }
  }

  /// Thêm 1 message vào lịch sử với peer
  /// peerId: ID hoặc IP:Port của peer
  /// message: { "sender": "me|peer", "content": "...", "timestamp": "..." }
  static Future<void> addMessage(
      String peerId, Map<String, dynamic> message) async {
    final history = await loadHistory();

    if (!history.containsKey(peerId)) {
      history[peerId] = [];
    }

    // Thêm timestamp nếu chưa có
    if (!message.containsKey('timestamp')) {
      message['timestamp'] = DateTime.now().toIso8601String();
    }

    history[peerId]!.add(message);

    await saveHistory(history);
  }

  /// Lấy lịch sử chat với 1 peer cụ thể
  static Future<List<Map<String, dynamic>>> getMessagesWithPeer(
      String peerId) async {
    final history = await loadHistory();
    return history[peerId] ?? [];
  }

  /// Xóa lịch sử với 1 peer
  static Future<void> clearPeerHistory(String peerId) async {
    final history = await loadHistory();
    history.remove(peerId);
    await saveHistory(history);
  }

  /// Xóa toàn bộ lịch sử
  static Future<void> clearAllHistory() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Lấy danh sách tất cả peers đã chat
  static Future<List<String>> getAllPeerIds() async {
    final history = await loadHistory();
    return history.keys.toList();
  }
}
