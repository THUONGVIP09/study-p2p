import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lưu tin nhắn locally + track sync status
class LocalMessageStorage {
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String _roomKey(String roomCode) => 'room_messages_$roomCode';
  static String _unsyncedKey(String roomCode) => 'room_unsynced_$roomCode';

  /// Save message locally (synced = false for P2P messages)
  static Future<void> saveMessage({
    required String roomCode,
    required int senderId,
    required String senderName,
    required String text,
    required DateTime timestamp,
    bool synced = false,
  }) async {
    await initialize();

    final key = _roomKey(roomCode);
    final messageId = '${timestamp.microsecondsSinceEpoch}';

    final messageData = {
      'id': messageId,
      'roomCode': roomCode,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'synced': synced,
    };

    final messages = _prefs?.getStringList(key) ?? [];
    messages.add(jsonEncode(messageData));
    await _prefs?.setStringList(key, messages);

    // Track unsynced
    if (!synced) {
      final unsyncedKey = _unsyncedKey(roomCode);
      final unsynced = _prefs?.getStringList(unsyncedKey) ?? [];
      unsynced.add(messageId);
      await _prefs?.setStringList(unsyncedKey, unsynced);
    }

    debugPrint('💾 Saved message: $messageId');
  }

  /// Get all messages for room
  static Future<List<Map<String, dynamic>>> getMessages(String roomCode) async {
    await initialize();

    final key = _roomKey(roomCode);
    final messages = _prefs?.getStringList(key) ?? [];

    return messages.map((m) => jsonDecode(m) as Map<String, dynamic>).toList();
  }

  /// Get unsynced messages (for syncing to server later)
  static Future<List<Map<String, dynamic>>> getUnsyncedMessages(
      String roomCode) async {
    await initialize();

    final allMessages = await getMessages(roomCode);
    return allMessages.where((m) => m['synced'] != true).toList();
  }

  /// Mark messages as synced
  static Future<void> markAsSynced(
      String roomCode, List<String> messageIds) async {
    await initialize();

    final key = _roomKey(roomCode);
    final messages = _prefs?.getStringList(key) ?? [];

    final updated = messages.map((m) {
      final decoded = jsonDecode(m) as Map<String, dynamic>;
      if (messageIds.contains(decoded['id'])) {
        decoded['synced'] = true;
      }
      return jsonEncode(decoded);
    }).toList();

    await _prefs?.setStringList(key, updated);

    // Clear unsynced
    final unsyncedKey = _unsyncedKey(roomCode);
    await _prefs?.remove(unsyncedKey);

    debugPrint('✅ Marked ${messageIds.length} messages as synced');
  }

  /// Clear all messages for room
  static Future<void> clearRoom(String roomCode) async {
    await initialize();
    await _prefs?.remove(_roomKey(roomCode));
    await _prefs?.remove(_unsyncedKey(roomCode));
  }
}
