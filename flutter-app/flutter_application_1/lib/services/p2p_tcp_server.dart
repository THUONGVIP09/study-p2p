import 'dart:convert';
import 'package:flutter/foundation.dart';

// Conditional import - dart:io not available on web
import 'dart:io' as io show ServerSocket, Socket;

/// Local TCP server để nhận tin nhắn P2P từ các peers
class P2PTcpServer {
  dynamic _server; // ServerSocket on mobile/desktop, null on web
  final int port;
  Function(Map<String, dynamic>)? onMessageReceived;

  P2PTcpServer({this.port = 9999});

  /// Start TCP server
  Future<bool> start() async {
    // P2P TCP không hoạt động trên web
    if (kIsWeb) {
      debugPrint('⚠️ P2P TCP Server disabled on web platform');
      return false;
    }

    try {
      _server = await io.ServerSocket.bind('0.0.0.0', port);
      debugPrint('✅ P2P TCP Server started on port $port');

      // Accept connections
      _server!.listen(
        (io.Socket socket) {
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
  void _handlePeerSocket(dynamic socket) {
    final buffer = StringBuffer();

    socket.listen(
      (List<int> data) {
        try {
          final chunk = String.fromCharCodes(data);
          buffer.write(chunk);

          // Split by newline delimiter
          final lines = buffer.toString().split('\n');

          // Keep the last incomplete line in buffer
          buffer.clear();
          buffer.write(lines.last);

          // Process complete messages
          for (int i = 0; i < lines.length - 1; i++) {
            final line = lines[i].trim();
            if (line.isNotEmpty) {
              try {
                final decoded = jsonDecode(line) as Map<String, dynamic>;
                debugPrint('📨 Received from peer: $decoded');
                onMessageReceived?.call(decoded);
              } catch (e) {
                debugPrint('❌ Failed to decode message: $line, Error: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Socket error processing data: $e');
        }
      },
      onDone: () {
        debugPrint('🔌 Peer disconnected');
        socket.close();
      },
      onError: (e) => debugPrint('❌ Socket error: $e'),
    );
  }

  /// Send message to peer
  Future<bool> sendToPeer(String peerIp, Map<String, dynamic> message) async {
    if (kIsWeb) {
      debugPrint('⚠️ P2P send disabled on web');
      return false;
    }

    try {
      final socket = await io.Socket.connect(peerIp, port).timeout(
        const Duration(seconds: 5),
      );

      final json = jsonEncode(message);
      socket.write('$json\n'); // Add newline delimiter
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
