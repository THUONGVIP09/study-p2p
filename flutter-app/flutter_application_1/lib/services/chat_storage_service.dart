import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service quản lý lưu/đọc lịch sử chat local (JSON)
class ChatStorageService {
  static const String _fileNamePrefix = 'p2p_chat_history';
  static final List<Future<void>> _pendingWrites = []; // Track pending writes
  static int _writeCount = 0; // Debug counter

  /// Lấy đường dẫn file JSON cho user cụ thể
  static Future<File> _getFile(int userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${_fileNamePrefix}_user_$userId.json';
    print('📁 Storage file path: $filePath');
    return File(filePath);
  }

  /// Xóa file JSON cũ (user cụ thể)
  static Future<void> deleteStorageFile(int userId) async {
    try {
      final file = await _getFile(userId);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted old chat history file for user $userId');
      }
    } catch (e) {
      print('Error deleting storage file: $e');
    }
  }

  /// Đọc toàn bộ lịch sử chat của user
  /// Format: { "peer_id_1": [messages...], "peer_id_2": [messages...] }
  static Future<Map<String, List<Map<String, dynamic>>>> loadHistory(
      int userId) async {
    try {
      // Wait for all pending writes to complete before reading
      if (_pendingWrites.isNotEmpty) {
        print('⏳ Waiting for ${_pendingWrites.length} pending writes...');
        await Future.wait(_pendingWrites);
        _pendingWrites.clear();
      }

      final file = await _getFile(userId);
      if (!await file.exists()) {
        print('📂 Storage file does not exist, returning empty');
        return {};
      }

      final content = await file.readAsString();
      if (content.isEmpty) {
        print('⚠️ Storage file is empty');
        return {};
      }

      final Map<String, dynamic> decoded = jsonDecode(content);
      print(
          '📖 Loaded history: ${decoded.keys.length} peers, ${content.length} bytes');

      // Convert to proper type
      Map<String, List<Map<String, dynamic>>> result = {};
      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = value.cast<Map<String, dynamic>>();
          print('   Peer $key: ${result[key]!.length} messages');
        }
      });

      return result;
    } catch (e) {
      print('❌ Error loading chat history: $e');
      print('   Stack trace: ${StackTrace.current}');
      return {};
    }
  }

  /// Lưu lịch sử chat của user - SYNCHRONIZED
  static Future<void> saveHistory(
      int userId, Map<String, List<Map<String, dynamic>>> history) async {
    final writeId = ++_writeCount;
    print(
        '💾 [Write #$writeId] Starting save for user $userId: ${history.keys.length} peers');

    try {
      final file = await _getFile(userId);
      final encoded = jsonEncode(history);

      print('💾 [Write #$writeId] Writing ${encoded.length} bytes...');
      await file.writeAsString(encoded, flush: true);

      print('✅ [Write #$writeId] Save completed successfully');

      // Log summary
      history.forEach((key, messages) {
        print('   Peer $key: ${messages.length} messages');
      });
    } catch (e) {
      print('❌ [Write #$writeId] Error saving: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Thêm 1 message vào lịch sử với peer - FULLY SYNCHRONIZED
  /// userId: ID của user hiện tại
  /// peerId: ID hoặc IP:Port của peer
  /// message: { "sender": "me|peer", "content": "...", "timestamp": "..." }
  static Future<void> addMessage(
      int userId, String peerId, Map<String, dynamic> message) async {
    final operationId = ++_writeCount;
    print('');
    print('🔵 [Op #$operationId] ADD MESSAGE for user $userId to peer $peerId');
    print('   Sender: ${message['sender']}, Content: ${message['content']}');

    // Create future for this write operation
    final writeFuture =
        _addMessageInternal(operationId, userId, peerId, message);
    _pendingWrites.add(writeFuture);

    try {
      await writeFuture;
    } finally {
      _pendingWrites.remove(writeFuture);
    }
  }

  static Future<void> _addMessageInternal(int operationId, int userId,
      String peerId, Map<String, dynamic> message) async {
    print(
        '🔵 [Op #$operationId] START - Adding message for user $userId to peer $peerId');
    print('   Content: ${message['content']}');
    print('   Sender: ${message['sender']}');
    try {
      // Wait for all previous writes to complete
      final previousWrites = List<Future<void>>.from(_pendingWrites);
      if (previousWrites.length > 1) {
        print(
            '⏳ [Op #$operationId] Waiting for ${previousWrites.length - 1} previous writes...');
        await Future.wait(
            previousWrites.where((f) => f != _pendingWrites.last));
        print('✅ [Op #$operationId] Previous writes completed');
      }

      print('📖 [Op #$operationId] Loading current history from file...');

      // Load fresh data from file
      final file = await _getFile(userId);
      Map<String, List<Map<String, dynamic>>> history = {};

      if (await file.exists()) {
        final content = await file.readAsString();
        print(
            '📄 [Op #$operationId] File exists, size: ${content.length} bytes');
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            if (value is List) {
              history[key] = value.cast<Map<String, dynamic>>();
            }
          });
          print(
              '📚 [Op #$operationId] Loaded ${history.keys.length} peers from file');
        }
      } else {
        print('📂 [Op #$operationId] File does not exist yet');
      }

      final beforeCount = history[peerId]?.length ?? 0;
      print(
          '📊 [Op #$operationId] Peer $peerId current messages: $beforeCount');

      if (!history.containsKey(peerId)) {
        history[peerId] = [];
        print('   Created new peer entry for $peerId');
      }

      // Thêm timestamp nếu chưa có
      if (!message.containsKey('timestamp')) {
        message['timestamp'] = DateTime.now().toIso8601String();
      }

      history[peerId]!.add(message);
      final afterCount = history[peerId]!.length;

      print(
          '💾 [Op #$operationId] Saving: $beforeCount → $afterCount messages for peer $peerId');
      await saveHistory(userId, history);

      print('✅ [Op #$operationId] COMPLETED');
    } catch (e) {
      print('❌ [Op #$operationId] ERROR: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Lấy lịch sử chat của user với 1 peer cụ thể
  static Future<List<Map<String, dynamic>>> getMessagesWithPeer(
      int userId, String peerId) async {
    final history = await loadHistory(userId);
    return history[peerId] ?? [];
  }

  /// Xóa lịch sử của user với 1 peer
  static Future<void> clearPeerHistory(int userId, String peerId) async {
    final history = await loadHistory(userId);
    history.remove(peerId);
    await saveHistory(userId, history);
  }

  /// Xóa toàn bộ lịch sử của user
  static Future<void> clearAllHistory(int userId) async {
    final file = await _getFile(userId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Lấy danh sách tất cả peers đã chat của user
  static Future<List<String>> getAllPeerIds(int userId) async {
    final history = await loadHistory(userId);
    return history.keys.toList();
  }
}
