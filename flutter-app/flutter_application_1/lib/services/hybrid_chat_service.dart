import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'p2p_chat_service.dart';
import 'chat_api_service.dart';
import 'chat_storage_service.dart';

class HybridChatService {
  final P2PChatService p2p;
  IOWebSocketChannel? relay;
  StreamController<Map<String, dynamic>> _stream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get stream => _stream.stream;

  final int currentUserId;
  HybridChatService({required this.currentUserId, required this.p2p});

  Future<void> start(
      {required String myIp, int port = P2PChatService.DEFAULT_PORT}) async {
    await p2p.startListening(port: port);
    await ChatApiService.registerPeer(
        userId: currentUserId, ip: myIp, port: port);
    // heartbeat loop
    Timer.periodic(const Duration(seconds: 30), (_) {
      ChatApiService.heartbeat(userId: currentUserId).catchError((_) {});
    });
    // pipe P2P messages to hybrid stream
    p2p.messageStream.listen(_stream.add);
  }

  Future<bool> connectToFriend(int friendId) async {
    final info = await ChatApiService.getFriendPeerInfo(friendId);
    if (info['online'] == true) {
      final ok = await p2p.connectToPeer(info['ip'], info['port']);
      if (ok) return true;
    }
    // fallback: relay
    final ws = await WebSocket.connect(
        'ws://127.0.0.1:8082/chat-relay/$currentUserId');
    relay = IOWebSocketChannel(ws);
    relay!.stream.listen((data) {
      try {
        final obj = jsonDecode(data);
        _stream.add({
          'peerId': obj['from']?.toString() ?? 'relay',
          'sender': 'friend',
          'content': obj['content'],
          'timestamp': DateTime.now().toIso8601String(),
        });
        ChatStorageService.addMessage(obj['from'].toString(), {
          'sender': 'friend',
          'content': obj['content'],
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    });
    return false; // indicates relay mode
  }

  Future<void> sendToFriend(int friendId, String content) async {
    // try P2P first
    if (p2p.isConnectedTo(friendId.toString())) {
      await p2p.sendMessage(friendId.toString(), content);
      return;
    }
    // relay
    final ch = relay;
    if (ch != null) {
      ch.sink.add(jsonEncode(
          {'from': currentUserId, 'to': friendId, 'content': content}));
    }
  }

  void dispose() {
    relay?.sink.close();
    _stream.close();
  }
}
