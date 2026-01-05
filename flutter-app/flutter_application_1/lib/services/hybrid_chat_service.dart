import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'p2p_chat_service.dart';
import 'p2p_websocket_server.dart';
import 'chat_api_service.dart';
import 'chat_storage_service.dart';
import '../config/app_config.dart';

class HybridChatService {
  final P2PChatService p2p;
  IOWebSocketChannel? relay;
  IOWebSocketChannel? onlineListChannel;
  StreamController<Map<String, dynamic>> _stream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get stream => _stream.stream;

  final int currentUserId;
  final Map<int, String> _friendToPeerId = {}; // friendId -> peerId (IP:Port)
  final Map<String, int> _peerIdToFriend = {}; // peerId (IP:Port) -> friendId
  final Map<int, bool> _onlineStatus = {}; // friendId -> online status
  int _myPort = P2PChatService.DEFAULT_PORT;
  Timer? _heartbeatTimer; // Track timer to cancel on dispose
  final List<Future<void>> _pendingSaves = []; // Track pending storage saves
  bool _isDisposed = false; // Track if service is disposed
  bool offlineMode =
      false; // Khi server tắt: chạy hoàn toàn P2P, không dùng WS server

  StreamController<Map<int, bool>> _onlineController =
      StreamController.broadcast();
  Stream<Map<int, bool>> get onlineStream => _onlineController.stream;

  HybridChatService({required this.currentUserId, required this.p2p});

  Future<void> start({required String myIp, int port = 0}) async {
    // LEARN FROM bt2ltm: Use port 0 for random available port!
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _myPort = server.port;
    server.close();

    // Start P2P listener on the random port
    bool started = await p2p.startListening(port: _myPort);
    if (!started) {
      throw Exception('Failed to start P2P listener on port $_myPort');
    }

    print('🟢 Hybrid Chat started on port $_myPort for userId $currentUserId');

    // Phát hiện chế độ offline (server tắt)
    offlineMode = false;
    try {
      await ChatApiService.heartbeat(userId: currentUserId)
          .timeout(const Duration(seconds: 2));
      offlineMode = false;
      print('🟢 [HYBRID] Server reachable → online mode');
    } catch (_) {
      offlineMode = true;
      print('🟠 [HYBRID] Server unreachable → OFFLINE P2P mode');
    }

    if (!offlineMode) {
      // Register to server
      await ChatApiService.registerPeer(
          userId: currentUserId, ip: myIp, port: _myPort);

      // Subscribe to online list WebSocket
      _subscribeToOnlineList();
    } else {
      print(
          '🟠 [HYBRID] Skip server registration and online list in offline mode');
    }

    // ✅ Relay sẽ được mở on-demand (khi cần), không reconnect liên tục
    // Điều này giúp P2P hoạt động mà không bị ảnh hưởng bởi relay

    // heartbeat loop (chỉ chạy khi online)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!offlineMode) {
        ChatApiService.heartbeat(userId: currentUserId).catchError((_) {});
      }
    });

    // pipe P2P messages to hybrid stream with friendId conversion
    p2p.messageStream.listen((msg) {
      // msg có 'from' là userId của người gửi (friendId)
      final friendId = msg['from'] as int?; // ✅ Lấy trực tiếp từ tin nhắn!
      final peerId = msg['peerId'] as String?;
      final content = msg['content'] as String?;
      final timestamp = msg['timestamp'] as String?;

      if (content == null || friendId == null) {
        print(
            '⚠️ P2P message thiếu thông tin: friendId=$friendId, content=$content');
        return; // Skip if missing critical data
      }

      print('');
      print('🔵 [HYBRID] Received P2P from friend $friendId');
      print('   Content: $content');
      print('   Timestamp: $timestamp');

      // Lưu vào storage với key friendId - TRACK để đảm bảo save xong!
      print(
          '💾 [HYBRID] Calling ChatStorageService.addMessage for peer message...');
      print('   📊 Current pending saves: ${_pendingSaves.length}');
      final saveFuture =
          ChatStorageService.addMessage(currentUserId, friendId.toString(), {
        'sender': 'peer',
        'content': content,
        'timestamp': timestamp ?? DateTime.now().toIso8601String(),
      }).then((_) {
        print('✅ [HYBRID] Storage save completed for peer message: $content');
        print('   📊 Remaining pending saves: ${_pendingSaves.length - 1}');
      }).catchError((e) {
        print('❌ [HYBRID] Storage save FAILED for peer message: $e');
        print('   Stack trace: $e');
      });
      _pendingSaves.add(saveFuture);
      print('   📊 After add - pending saves: ${_pendingSaves.length}');
      saveFuture.whenComplete(() {
        _pendingSaves.remove(saveFuture);
        print(
            '   ✂️ [HYBRID] Removed from pending saves, remaining: ${_pendingSaves.length}');
      });

      // Update reverse mapping nếu chưa có
      if (peerId != null && !_peerIdToFriend.containsKey(peerId)) {
        _peerIdToFriend[peerId] = friendId;
        _friendToPeerId[friendId] = peerId;
        print('✅ [HYBRID] Updated mapping: $peerId <-> friend $friendId');
      }

      // Emit ra stream với friendId
      print('📤 [HYBRID] Emitting to UI stream...');
      _stream.add({
        'friendId': friendId,
        'sender': 'peer',
        'content': content,
        'timestamp': timestamp ?? DateTime.now().toIso8601String(),
      });
    });
  }

  /// ✅ Check if friend is online and get their peer info
  /// Separate từ relay connection - relay là global, friend check là per-message
  Future<bool> connectToFriend(int friendId) async {
    print('');
    print('🤝 [HYBRID] Checking if friend $friendId is online...');

    // Check if we have friend's IP:Port from online broadcast
    if (_friendToPeerId.containsKey(friendId)) {
      print('✅ [HYBRID] Friend $friendId found in broadcast');
      return true;
    }

    // Fallback: query server for friend's info (chỉ khi online)
    if (!offlineMode) {
      try {
        final info = await ChatApiService.getFriendPeerInfo(friendId);
        if (info['online'] == true) {
          final ip = info['ip'];
          final port = info['port'];
          final peerId = '$ip:$port';
          _friendToPeerId[friendId] = peerId;
          _peerIdToFriend[peerId] = friendId;
          print('✅ [HYBRID] Friend $friendId is online: $peerId');
          return true;
        }
      } catch (e) {
        print('⚠️ [HYBRID] Could not get friend info: $e');
      }
    }

    print('⚠️ [HYBRID] Friend $friendId offline or unreachable');
    return false;
  }

  Future<void> sendToFriend(int friendId, String content) async {
    print('');
    print('📨 [HYBRID] SEND to friend $friendId: $content');

    // LEARN FROM bt2ltm: Use short-lived P2P sockets!
    final peerId = _friendToPeerId[friendId];
    if (peerId != null) {
      print('   Attempting P2P to $peerId...');
      // Extract IP and port from peerId "IP:Port"
      final parts = peerId.split(':');
      if (parts.length == 2) {
        try {
          final ip = parts[0];
          final port = int.parse(parts[1]);

          // Short-lived socket: connect, send, close
          final socket = await Socket.connect(ip, port,
              timeout: const Duration(seconds: 3));
          final message = jsonEncode({
            'from': currentUserId,
            'content': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
          socket.write(message);
          await socket.flush();
          socket.destroy();

          // Lưu tin nhắn gửi đi vào storage với key friendId
          print(
              '💾 [HYBRID] Calling ChatStorageService.addMessage for sent P2P...');
          await ChatStorageService.addMessage(
              currentUserId, friendId.toString(), {
            'sender': 'me',
            'content': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('✅ [HYBRID] Sent via P2P to $peerId');
          return;
        } catch (e) {
          print('❌ [HYBRID] P2P send failed: $e, trying relay...');
        }
      }
    }

    // Fallback 1: relay (open on-demand nếu chưa có) — bỏ qua khi offline
    if (!offlineMode) {
      var ch = relay;
      if (ch == null) {
        // Relay chưa mở, thử mở on-demand
        print('🔌 [HYBRID] Relay closed, opening on-demand...');
        ch = await _openRelayConnection();
      }

      if (ch != null) {
        try {
          print('📤 [HYBRID] Sending via Relay to friend $friendId');
          ch.sink.add(jsonEncode(
              {'from': currentUserId, 'to': friendId, 'content': content}));

          // Lưu tin nhắn relay gửi đi vào storage
          print(
              '💾 [HYBRID] Calling ChatStorageService.addMessage for sent relay...');
          await ChatStorageService.addMessage(
              currentUserId, friendId.toString(), {
            'sender': 'me',
            'content': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('✅ [HYBRID] Sent via Relay');
          return;
        } catch (e) {
          print('❌ [HYBRID] Relay send failed: $e');
          relay = null; // Reset relay để retry lần sau
        }
      }
    } else {
      print('🟠 [HYBRID] Offline mode: relay disabled, using P2P fallbacks');
    }

    // Fallback 2: P2P WebSocket (khi server down)
    // Nếu peer có IP, thử connect qua WebSocket port 8899
    if (peerId != null && peerId.contains(':')) {
      try {
        print('📡 [HYBRID] Fallback to P2P WebSocket...');
        final parts = peerId.split(':');
        final ip = parts[0];

        // ✅ Sử dụng P2P WebSocket Server
        final p2pServer = P2PWebSocketServer.getInstance();
        final connKey = friendId.toString();
        final connected = await p2pServer.connectToPeer(connKey, ip);

        if (connected) {
          // Gửi trực tiếp tới friend thay vì broadcast
          final ok = p2pServer.sendToPeer(connKey, {
            't': 'chat',
            'peerId': p2pServer.peerId,
            'senderId': currentUserId,
            'senderName': 'You',
            'text': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
          if (ok) {
            print(
                '💾 [HYBRID] Calling ChatStorageService.addMessage for sent P2P-WS...');
            await ChatStorageService.addMessage(
                currentUserId, friendId.toString(), {
              'sender': 'me',
              'content': content,
              'timestamp': DateTime.now().toIso8601String(),
            });
            print('✅ [HYBRID] Sent via P2P WebSocket');
            return;
          } else {
            print('⚠️ [HYBRID] P2P WebSocket send failed (no conn)');
          }
        }
      } catch (e) {
        print('⚠️ [HYBRID] P2P WebSocket fallback failed: $e');
      }
    }

    print('❌ [HYBRID] All send methods failed for friend $friendId');
  }

  void _subscribeToOnlineList() {
    try {
      final url = AppConfig.onlineListUrl;
      print('📡 [HYBRID] Subscribing to online list: $url');
      final ws = WebSocket.connect(url);
      ws.then((socket) {
        onlineListChannel = IOWebSocketChannel(socket);

        // ✅ Client-side heartbeat: gửi ping mỗi 20 giây để keep-alive
        Timer? heartbeatTimer;
        heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
          if (!_isDisposed && onlineListChannel != null) {
            try {
              onlineListChannel!.sink.add('{"type":"ping"}');
              print('💓 [HYBRID] Sent ping to online list server');
            } catch (e) {
              print('⚠️ [HYBRID] Failed to send ping: $e');
              heartbeatTimer?.cancel();
            }
          } else {
            heartbeatTimer?.cancel();
          }
        });

        onlineListChannel!.stream.listen((data) {
          try {
            // Skip ping responses
            if (data.toString().contains('ping')) {
              return;
            }

            final obj = jsonDecode(data);
            if (obj['type'] == 'ONLINE_LIST') {
              final peers = obj['peers'] as List<dynamic>;
              _onlineStatus.clear();
              for (var peer in peers) {
                final userId = peer['userId'] as int?;
                final ip = peer['ip'] as String?;
                final port = peer['port'] as int?;
                if (userId != null && ip != null && port != null) {
                  final peerId = '$ip:$port';
                  _onlineStatus[userId] = true;
                  _friendToPeerId[userId] = peerId;
                  _peerIdToFriend[peerId] = userId; // Reverse mapping
                }
              }
              print('📡 Received online list: ${_onlineStatus.length} peers');
              _onlineController.add(Map.from(_onlineStatus));
            }
          } catch (e) {
            print('Error parsing online list: $e');
          }
        }, onError: (error) {
          print('❌ Online list WebSocket error: $error');
          onlineListChannel = null;
          // Chuyển sang chế độ offline, không reconnect nữa
          offlineMode = true;
          print('🟠 [HYBRID] Switch to OFFLINE mode due to online list error');
        }, onDone: () {
          print('⚠️ Online list WebSocket closed');
          onlineListChannel = null;
          // Chuyển sang chế độ offline, không reconnect nữa
          offlineMode = true;
          print('🟠 [HYBRID] Switch to OFFLINE mode due to online list closed');
        });
      }).catchError((error) {
        print('❌ Failed to connect to online list: $error');
        // Chuyển sang offline, không retry liên tục
        offlineMode = true;
        print('🟠 [HYBRID] OFFLINE mode: skip online list reconnect');
      });
    } catch (e) {
      print('❌ Failed to subscribe to online list: $e');
    }
  }

  /// ✅ Open relay connection on-demand (chỉ khi cần)
  /// Không reconnect liên tục, P2P vẫn chạy độc lập
  /// Return relay channel nếu thành công, null nếu thất bại
  Future<IOWebSocketChannel?> _openRelayConnection() async {
    if (offlineMode) {
      print('🟠 [HYBRID] Offline mode: not opening relay connection');
      return null;
    }
    if (relay != null) {
      return relay; // Relay đã mở rồi
    }

    try {
      print('🔌 [HYBRID] Opening relay connection on-demand...');
      final relayUrl = AppConfig.chatRelayUrl(currentUserId);
      print('   URL: $relayUrl');

      final socket =
          await WebSocket.connect(relayUrl).timeout(const Duration(seconds: 3));
      relay = IOWebSocketChannel(socket);
      print('✅ [HYBRID] Relay connection opened');

      // ✅ Client-side heartbeat: gửi ping mỗi 25 giây để keep-alive
      Timer? relayHeartbeatTimer;
      relayHeartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (!_isDisposed && relay != null) {
          try {
            relay!.sink.add('{"type":"ping"}');
            print('💓 [HYBRID] Sent ping to relay server');
          } catch (e) {
            print('⚠️ [HYBRID] Failed to send relay ping: $e');
            relayHeartbeatTimer?.cancel();
          }
        } else {
          relayHeartbeatTimer?.cancel();
        }
      });

      relay!.stream.listen(
        (data) {
          // Handle incoming relay message
          try {
            // ✅ Ignore ping messages từ server
            if (data.toString().contains('ping')) {
              print('💓 [HYBRID] Received relay heartbeat ping');
              return;
            }

            final obj = jsonDecode(data);
            final fromUserId = obj['from'] as int?;
            final content = obj['content'] as String?;

            if (content == null) return;

            print('');
            print('📥 [HYBRID] Received RELAY from friend $fromUserId');
            print('   Content: $content');

            if (fromUserId != null) {
              print(
                  '💾 [HYBRID] Calling ChatStorageService.addMessage for relay message...');
              final saveFuture = ChatStorageService.addMessage(
                  currentUserId, fromUserId.toString(), {
                'sender': 'peer',
                'content': content,
                'timestamp': DateTime.now().toIso8601String(),
              }).then((_) {
                print('✅ [HYBRID] Relay message storage completed');
              }).catchError((e) {
                print('❌ [HYBRID] Relay message storage FAILED: $e');
              });
              _pendingSaves.add(saveFuture);
              saveFuture.whenComplete(() => _pendingSaves.remove(saveFuture));
            }

            _stream.add({
              'friendId': fromUserId,
              'sender': 'peer',
              'content': content,
              'timestamp': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            print('❌ [HYBRID] Error parsing relay message: $e');
          }
        },
        onError: (error) {
          print('❌ [HYBRID] Relay WebSocket error: $error');
          relayHeartbeatTimer?.cancel();
          relay = null; // Reset
          // Chuyển sang chế độ offline, không reconnect relay nữa
          offlineMode = true;
          print('🟠 [HYBRID] Switch to OFFLINE mode due to relay error');
        },
        onDone: () {
          print('⚠️ [HYBRID] Relay WebSocket closed');
          print('   ✅ P2P socket (port 8899) vẫn độc lập, không bị ảnh hưởng');
          relayHeartbeatTimer?.cancel();
          relay = null; // Reset
          // Chuyển sang chế độ offline, không reconnect relay nữa
          offlineMode = true;
          print('🟠 [HYBRID] OFFLINE mode: relay closed, no reconnect');
        },
      );

      return relay;
    } catch (e) {
      print('❌ [HYBRID] Failed to open relay: $e');
      print('   → Will use P2P WebSocket instead');
      relay = null;
      return null;
    }
  }

  Future<void> dispose() async {
    _isDisposed = true; // ✅ Mark as disposed to stop reconnect attempts

    // Đợi tất cả pending saves hoàn thành trước khi dispose!
    if (_pendingSaves.isNotEmpty) {
      print(
          '⏳ [HYBRID] Waiting for ${_pendingSaves.length} pending saves before dispose...');
      await Future.wait(_pendingSaves);
      print('✅ [HYBRID] All pending saves completed');
    }

    _heartbeatTimer?.cancel();
    relay?.sink.close();
    onlineListChannel?.sink.close();
    _stream.close();
    _onlineController.close();
  }

  /// Thiết lập địa chỉ peer thủ công khi ở chế độ offline
  void setPeerAddressForFriend(int friendId, String ip, int port) {
    final peerId = '$ip:$port';
    _friendToPeerId[friendId] = peerId;
    _peerIdToFriend[peerId] = friendId;
    _onlineStatus[friendId] = true;
    _onlineController.add(Map.from(_onlineStatus));
    print('✅ [HYBRID] Set peer address for friend $friendId: $peerId');
  }
}
