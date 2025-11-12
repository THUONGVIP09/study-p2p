import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

String wsBase() {
  // chạy web/desktop → 127.0.0.1
  if (kIsWeb) return 'ws://127.0.0.1:8080/ws';
  // Android emulator → 10.0.2.2
  if (defaultTargetPlatform == TargetPlatform.android) return 'ws://10.0.2.2:8080/ws';
  // iOS sim / desktop
  return 'ws://127.0.0.1:8080/ws';
}

class SignalingService {
  WebSocketChannel? _ch;
  String? uid;
  String? room;

  final peers = <String, String>{}; // uid -> name
  void Function()? onChanged;

  void join({required String roomCode, required String name, required String myUid}) {
    room = roomCode; uid = myUid;
    _ch = WebSocketChannel.connect(Uri.parse(wsBase()));

    _ch!.sink.add(jsonEncode({
      't': 'join',
      'room': roomCode,
      'uid': myUid,
      'name': name.isEmpty ? 'Guest' : name,
    }));

    _ch!.stream.listen((raw) {
      final m = jsonDecode(raw);
      switch (m['t']) {
        case 'peers':
          peers
            ..clear()
            ..addEntries((m['peers'] as List)
                .map((p) => MapEntry(p['uid'] as String, p['name'] as String)));
          onChanged?.call();
          break;
        case 'peer.joined':
          peers[m['uid']] = m['name'];
          onChanged?.call();
          break;
        case 'peer.left':
          peers.remove(m['uid']);
          onChanged?.call();
          break;
        default:
          // offer/answer/ice sẽ xử ở bước sau
          break;
      }
    });
  }

  void leave() {
    try { _ch?.sink.add(jsonEncode({'t': 'leave'})); } catch (_) {}
    try { _ch?.sink.close(); } catch (_) {}
    _ch = null; peers.clear();
  }
}
