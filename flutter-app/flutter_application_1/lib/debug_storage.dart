import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Debug utility để kiểm tra nội dung file chat history
Future<void> debugChatStorage() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/p2p_chat_history.json');

    print('📁 Storage file path: ${file.path}');

    if (!await file.exists()) {
      print('❌ File does not exist');
      return;
    }

    final content = await file.readAsString();

    if (content.isEmpty) {
      print('⚠️ File is empty');
      return;
    }

    print('📊 File size: ${content.length} bytes');
    print('');
    print('📄 Raw content:');
    print(content);
    print('');

    try {
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      print('✅ Valid JSON');
      print('📦 Total peers: ${decoded.keys.length}');
      print('');

      decoded.forEach((peerId, messages) {
        if (messages is List) {
          print('👤 Peer ID: $peerId');
          print('   Messages: ${messages.length}');

          for (var i = 0; i < messages.length; i++) {
            final msg = messages[i];
            print('   [$i] ${msg['sender']}: ${msg['content']}');
            print('       Time: ${msg['timestamp']}');
          }
          print('');
        }
      });
    } catch (e) {
      print('❌ Invalid JSON format: $e');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

void main() async {
  await debugChatStorage();
}
