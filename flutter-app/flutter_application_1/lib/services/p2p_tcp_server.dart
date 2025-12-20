import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Local TCP server để nhận tin nhắn P2P từ các peers
class P2PTcpServer {
  ServerSocket? _server;
  final int port;
  Function(Map<String, dynamic>)? onMessageReceived;

  P2PTcpServer({this.port = 9999});

  /// Start TCP server
  Future<bool> start() async {
    try {
      _server = await ServerSocket.bind('0.0.0.0', port);
      debugPrint('✅ P2P TCP Server started on port $port');

      // Accept connections
      _server!.listen(
        (Socket socket) {
          debugPrint(
              '🔗 Peer connected: ${socket.remoteAddress.address}:${socket.remotePort}');
          _handlePeerSocket(socket);
        },
        onError: (e) => debugPrint('❌ Server error: $e'),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Failed to start P2P server: $e');
      return false;
    }
  }

  /// Handle incoming connection từ peer
  void _handlePeerSocket(Socket socket) {
    socket.listen(
      (List<int> data) {
        try {
          final message = String.fromCharCodes(data);
          final decoded = jsonDecode(message) as Map<String, dynamic>;
          debugPrint('📨 Received from peer: $decoded');

          onMessageReceived?.call(decoded);
        } catch (e) {
          debugPrint('❌ Failed to decode message: $e');
        }
      },
      onDone: () {
        debugPrint('🔌 Peer disconnected: ${socket.remoteAddress.address}');
        socket.close();
      },
      onError: (e) => debugPrint('❌ Socket error: $e'),
    );
  }

  /// Send message to peer
  Future<bool> sendToPeer(String peerIp, Map<String, dynamic> message) async {
    try {
      final socket = await Socket.connect(peerIp, port).timeout(
        const Duration(seconds: 5),
      );

      final json = jsonEncode(message);
      socket.write(json);
      await socket.close();

      debugPrint('📤 Sent to $peerIp: $message');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send to $peerIp: $e');
      return false;
    }
  }

  /// Broadcast message to multiple peers
  Future<void> broadcastToPeers(
    List<String> peerIps,
    Map<String, dynamic> message,
  ) async {
    final futures = peerIps.map((ip) => sendToPeer(ip, message));
    await Future.wait(futures, eagerError: false);
  }

  /// Shutdown server
  Future<void> stop() async {
    try {
      await _server?.close();
      debugPrint('🛑 P2P TCP Server stopped');
    } catch (e) {
      debugPrint('Error stopping server: $e');
    }
  }
}
