import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

String wsBase() {
  if (kIsWeb) return 'ws://127.0.0.1:8081/ws';
  if (defaultTargetPlatform == TargetPlatform.android) return 'ws://10.0.2.2:8081/ws'; // emulator
  return 'ws://127.0.0.1:8081/ws'; // desktop/iOS sim
}

class SignalingService {
  WebSocketChannel? _ch;

  final peers = <String, String>{}; // uid -> name
  bool joined = false;
  String status = 'idle'; // idle | connecting | joined | closed | error:...
  void Function(String from, Map<String,dynamic> sdp)? onOffer;
  void Function(String from, Map<String,dynamic> sdp)? onAnswer;
  void Function(String from, Map<String,dynamic> cand)? onIce;

  void Function()? onChanged; // gọi setState ở UI

  void join({required String roomCode, required String name, required String myUid}) {
    // đóng kênh cũ nếu có
    try { _ch?.sink.close(); } catch (_) {}

    status = 'connecting';
    onChanged?.call();

    final uri = Uri.parse(wsBase());
    _ch = WebSocketChannel.connect(uri);

    // gửi join ngay
    _ch!.sink.add(jsonEncode({
      't': 'join',
      'room': roomCode,
      'uid': myUid,
      'name': (name.isEmpty ? 'Guest' : name),
    }));

    _ch!.stream.listen((raw) {
      final m = jsonDecode(raw);
      switch (m['t']) {
        case 'peers':
          peers
            ..clear()
            ..addEntries((m['peers'] as List)
                .map((p) => MapEntry(p['uid'] as String, p['name'] as String)));
          joined = true;
          status = 'joined';       // Kể cả peers rỗng vẫn báo đã join
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
        case 'offer':  onOffer?.call(m['from'] ?? '', Map<String,dynamic>.from(m['sdp'])); break;
        case 'answer': onAnswer?.call(m['from'] ?? '', Map<String,dynamic>.from(m['sdp'])); break;
        case 'ice':    onIce?.call(m['from'] ?? '', Map<String,dynamic>.from(m['candidate'])); break;

        default:
          // offer/answer/ice sẽ xử ở bước sau
          break;
      }
    }, onError: (e) {
      status = 'error: $e';
      joined = false;
      onChanged?.call();
    }, onDone: () {
      status = 'closed';
      joined = false;
      peers.clear();
      onChanged?.call();
    });
  }

  void leave() {
    try { _ch?.sink.add(jsonEncode({'t': 'leave'})); } catch (_) {}
    try { _ch?.sink.close(); } catch (_) {}
    _ch = null;
    joined = false;
    status = 'closed';
    peers.clear();
    onChanged?.call();
  }
  void sendOffer(String to, Map<String, dynamic> sdp, String from) {
  _ch?.sink.add(jsonEncode({'t':'offer','to':to,'from':from,'sdp':sdp}));
}
void sendAnswer(String to, Map<String, dynamic> sdp, String from) {
  _ch?.sink.add(jsonEncode({'t':'answer','to':to,'from':from,'sdp':sdp}));
}
void sendIce(String to, Map<String, dynamic> cand, String from) {
  _ch?.sink.add(jsonEncode({'t':'ice','to':to,'from':from,'candidate':cand}));
}

}
