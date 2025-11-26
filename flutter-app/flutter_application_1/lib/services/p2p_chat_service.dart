import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Service quản lý P2P chat qua TCP socket
/// Mỗi peer sẽ:
/// 1. Lắng nghe (listen) trên 1 port
/// 2. Kết nối (connect) đến peer khác khi cần chat
class P2PChatService {
  static const int DEFAULT_PORT = 9001;

  ServerSocket? _serverSocket;
  final Map<String, Socket> _activeSockets = {}; // peerId -> Socket
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();

  String? _myPeerId; // IP:Port của mình
  bool _isListening = false;

  /// Stream nhận messages từ peers
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Bắt đầu lắng nghe connections từ peers khác
  Future<bool> startListening({int port = DEFAULT_PORT}) async {
    if (_isListening) {
      print('Already listening');
      return true;
    }

    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isListening = true;

      // Lấy IP của mình
      final myIp = await _getLocalIp();
      _myPeerId = '$myIp:$port';

      print('✅ P2P Chat listening on $_myPeerId');

      // Lắng nghe connections
      _serverSocket!.listen((Socket socket) {
        final peerId = '${socket.remoteAddress.address}:${socket.remotePort}';
        print('📥 Peer connected: $peerId');

        _activeSockets[peerId] = socket;
        _handleSocket(socket, peerId);
      });

      return true;
    } catch (e) {
      print('❌ Error starting P2P listener: $e');
      _isListening = false;
      return false;
    }
  }

  /// Kết nối đến 1 peer khác
  Future<bool> connectToPeer(String peerIp, int peerPort) async {
    final peerId = '$peerIp:$peerPort';

    // Đã kết nối rồi
    if (_activeSockets.containsKey(peerId)) {
      print('Already connected to $peerId');
      return true;
    }

    try {
      final socket = await Socket.connect(peerIp, peerPort,
          timeout: const Duration(seconds: 5));
      _activeSockets[peerId] = socket;

      print('✅ Connected to peer: $peerId');
      _handleSocket(socket, peerId);

      return true;
    } catch (e) {
      print('❌ Error connecting to $peerId: $e');
      return false;
    }
  }

  /// Xử lý socket (nhận messages)
  void _handleSocket(Socket socket, String peerId) {
    socket.listen(
      (data) {
        try {
          final message = utf8.decode(data);
          final decoded = jsonDecode(message) as Map<String, dynamic>;

          print('📨 Received from $peerId: ${decoded['content']}');

          // KHÔNG lưu storage ở đây nữa - để HybridChatService xử lý
          // vì cần convert peerId -> friendId trước khi lưu

          // Emit event với peerId và FROM (userId của người gửi)
          _messageController.add({
            'peerId': peerId,
            'from': decoded['from'], // ✅ Lấy userId từ tin nhắn!
            'sender': 'peer',
            'content': decoded['content'],
            'timestamp':
                decoded['timestamp'] ?? DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('Error decoding message from $peerId: $e');
        }
      },
      onDone: () {
        print('🔌 Peer disconnected: $peerId');
        _activeSockets.remove(peerId);
        socket.destroy();
      },
      onError: (error) {
        print('Socket error with $peerId: $error');
        _activeSockets.remove(peerId);
        socket.destroy();
      },
    );
  }

  /// Gửi message đến 1 peer
  Future<bool> sendMessage(String peerId, String content) async {
    final socket = _activeSockets[peerId];

    if (socket == null) {
      print('❌ Not connected to $peerId');
      return false;
    }

    try {
      final message = jsonEncode({
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      });

      socket.write(message);
      await socket.flush();

      // KHÔNG lưu storage ở đây nữa - để HybridChatService xử lý
      // vì cần friendId để lưu, không phải peerId

      print('📤 Sent to $peerId: $content');
      return true;
    } catch (e) {
      print('❌ Error sending message to $peerId: $e');
      return false;
    }
  }

  /// Ngắt kết nối với 1 peer
  void disconnectPeer(String peerId) {
    final socket = _activeSockets[peerId];
    if (socket != null) {
      socket.destroy();
      _activeSockets.remove(peerId);
      print('🔌 Disconnected from $peerId');
    }
  }

  /// Dừng lắng nghe và đóng tất cả connections
  void stop() {
    _serverSocket?.close();
    _serverSocket = null;

    for (var socket in _activeSockets.values) {
      socket.destroy();
    }
    _activeSockets.clear();

    _isListening = false;
    print('🛑 P2P Chat service stopped');
  }

  /// Lấy IP local của device
  Future<String> _getLocalIp() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);

      // Ưu tiên WiFi hoặc Ethernet (không phải loopback)
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }

      return '127.0.0.1'; // fallback
    } catch (e) {
      print('Error getting local IP: $e');
      return '127.0.0.1';
    }
  }

  /// Lấy danh sách peers đang kết nối
  List<String> getActivePeers() {
    return _activeSockets.keys.toList();
  }

  bool isConnectedTo(String peerId) {
    return _activeSockets.containsKey(peerId);
  }

  /// Lấy peer ID của mình
  String? get myPeerId => _myPeerId;

  /// Dispose
  void dispose() {
    stop();
    _messageController.close();
  }
}
