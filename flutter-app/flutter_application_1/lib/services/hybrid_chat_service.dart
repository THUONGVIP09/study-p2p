import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'p2p_chat_service.dart';
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

    // Register to server
    await ChatApiService.registerPeer(
        userId: currentUserId, ip: myIp, port: _myPort);

    // Subscribe to online list WebSocket
    _subscribeToOnlineList();

    // heartbeat loop
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ChatApiService.heartbeat(userId: currentUserId).catchError((_) {});
    });

    // pipe P2P messages to hybrid stream with friendId conversion
    p2p.messageStream.listen((msg) {
      // msg có thể chứa 'from' (userId của người gửi) hoặc chỉ có 'peerId'
      var friendId = msg['from'] as int?; // ưu tiên lấy từ payload nếu có
      final peerId = msg['peerId'] as String?;
      final content = msg['content'] as String?;
      final timestamp = msg['timestamp'] as String?;

      // Nếu payload không chứa friendId, thử dùng mapping peerId -> friendId
      if (friendId == null && peerId != null && _peerIdToFriend.containsKey(peerId)) {
        friendId = _peerIdToFriend[peerId];
        print('ℹ️ Resolved friendId from peerId mapping: $peerId -> $friendId');
      }

      if (content == null || friendId == null) {
        print(
            '⚠️ P2P message thiếu thông tin: friendId=$friendId, peerId=$peerId, content=$content');
        return; // Skip if still missing critical data
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

  Future<bool> connectToFriend(int friendId) async {
    // ALWAYS open relay connection first as backup (defense in depth)
    if (relay == null) {
      try {
        print('🔌 [HYBRID] Opening relay connection as backup...');
        final relayUrl = AppConfig.chatRelayUrl(currentUserId);
        print('   URL: $relayUrl');
        final ws = await WebSocket.connect(relayUrl);
        relay = IOWebSocketChannel(ws);
        relay!.stream.listen((data) {
          try {
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
        }, onError: (error) {
          print('❌ [HYBRID] Relay WebSocket error: $error');
        }, onDone: () {
          print('⚠️ [HYBRID] Relay WebSocket closed');
        });
        print('✅ [HYBRID] Relay connection opened successfully');
      } catch (e) {
        print('❌ [HYBRID] Failed to open relay: $e');
      }
    }

    // Now check if friend is online from broadcast list
    if (_friendToPeerId.containsKey(friendId)) {
      print('✅ [HYBRID] Friend $friendId is online (from broadcast)');
      final peerId = _friendToPeerId[friendId]!;
      _peerIdToFriend[peerId] = friendId;
      return true; // We have their IP:Port from online list
    }

    // Fallback: query server
    final info = await ChatApiService.getFriendPeerInfo(friendId);
    if (info['online'] == true) {
      final ip = info['ip'];
      final port = info['port'];
      final peerId = '$ip:$port';
      _friendToPeerId[friendId] = peerId;
      _peerIdToFriend[peerId] = friendId;
      print('🔵 [HYBRID] Got friend $friendId info from API: $peerId');
      return true;
    }

    print('⚠️ [HYBRID] Friend $friendId offline, relay-only mode');
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

    // Fallback: relay
    final ch = relay;
    if (ch != null) {
      print('📤 [HYBRID] Sending via Relay to friend $friendId');
      ch.sink.add(jsonEncode(
          {'from': currentUserId, 'to': friendId, 'content': content}));

      // Lưu tin nhắn relay gửi đi vào storage
      print(
          '💾 [HYBRID] Calling ChatStorageService.addMessage for sent relay...');
      await ChatStorageService.addMessage(currentUserId, friendId.toString(), {
        'sender': 'me',
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void _subscribeToOnlineList() {
    try {
      final url = AppConfig.onlineListUrl;
      print('📡 [HYBRID] Subscribing to online list: $url');
      final ws = WebSocket.connect(url);
      ws.then((socket) {
        onlineListChannel = IOWebSocketChannel(socket);
        onlineListChannel!.stream.listen((data) {
          try {
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
        }, onDone: () {
          print('⚠️ Online list WebSocket closed');
        });
      }).catchError((error) {
        print('❌ Failed to connect to online list: $error');
      });
    } catch (e) {
      print('❌ Failed to subscribe to online list: $e');
    }
  }

  Future<void> dispose() async {
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
}
