import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Service tìm kiếm peers trong mạng LAN qua UDP broadcast
class PeerDiscoveryService {
  static const int DISCOVERY_PORT = 9002;
  static const String BROADCAST_MESSAGE = 'STUDY_P2P_DISCOVER';

  RawDatagramSocket? _socket;
  final StreamController<Map<String, dynamic>> _peerController =
      StreamController.broadcast();

  final Set<String> _discoveredPeers = {};
  Timer? _broadcastTimer;

  /// Stream nhận peers mới được tìm thấy
  Stream<Map<String, dynamic>> get peerStream => _peerController.stream;

  /// Bắt đầu discovery (vừa broadcast vừa listen)
  Future<bool> startDiscovery({String? myDisplayName, int? myPort}) async {
    try {
      _socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, DISCOVERY_PORT);
      _socket!.broadcastEnabled = true;

      print('✅ Peer discovery started on port $DISCOVERY_PORT');

      // Lắng nghe broadcasts từ peers khác
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDiscoveryMessage(datagram);
          }
        }
      });

      // Broadcast định kỳ để announce mình
      _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _broadcast(myDisplayName ?? 'Anonymous', myPort ?? 9001);
      });

      return true;
    } catch (e) {
      print('❌ Error starting peer discovery: $e');
      return false;
    }
  }

  /// Xử lý message discovery nhận được
  void _handleDiscoveryMessage(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final decoded = jsonDecode(message) as Map<String, dynamic>;

      if (decoded['type'] == 'discovery') {
        final peerIp = datagram.address.address;
        final peerPort = decoded['port'] as int;
        final peerName = decoded['name'] as String;
        final peerId = '$peerIp:$peerPort';

        // Không add chính mình
        final myIp = _getMyIp();
        if (peerIp == myIp || peerIp == '127.0.0.1') {
          return;
        }

        // Peer mới
        if (!_discoveredPeers.contains(peerId)) {
          _discoveredPeers.add(peerId);

          print('🔍 Discovered peer: $peerName at $peerId');

          _peerController.add({
            'peerId': peerId,
            'ip': peerIp,
            'port': peerPort,
            'name': peerName,
          });
        }
      }
    } catch (e) {
      print('Error handling discovery message: $e');
    }
  }

  /// Broadcast thông tin của mình
  void _broadcast(String myName, int myPort) {
    try {
      final message = jsonEncode({
        'type': 'discovery',
        'name': myName,
        'port': myPort,
      });

      final data = utf8.encode(message);

      // Broadcast đến toàn bộ subnet
      _socket?.send(data, InternetAddress('255.255.255.255'), DISCOVERY_PORT);
    } catch (e) {
      print('Error broadcasting: $e');
    }
  }

  /// Lấy IP local
  String _getMyIp() {
    try {
      // Tạm thời dùng cách đơn giản, có thể cải thiện
      return '127.0.0.1';
    } catch (e) {
      return '127.0.0.1';
    }
  }

  /// Lấy danh sách peers đã discover
  List<String> getDiscoveredPeers() {
    return _discoveredPeers.toList();
  }

  /// Dừng discovery
  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _discoveredPeers.clear();
    print('🛑 Peer discovery stopped');
  }

  /// Dispose
  void dispose() {
    stop();
    _peerController.close();
  }
}
