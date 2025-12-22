import 'dart:convert';

import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'models/room.dart';
import 'models/call_session.dart';
import 'models/chat_message.dart';
import 'services/api_service.dart';
import 'services/p2p_tcp_server.dart';
import 'services/webrtc_p2p_chat.dart';
import 'services/local_message_storage.dart';

class P2PCallPage extends StatefulWidget {
  final Room room;
  final CallSession callSession;
  final int currentUserId;
  final bool? initialMicMuted;
  final bool? initialCamEnabled;
  final String? displayName;

  const P2PCallPage({
    super.key,
    required this.room,
    required this.callSession,
    required this.currentUserId,
    this.initialMicMuted,
    this.initialCamEnabled,
    this.displayName,
  });

  @override
  State<P2PCallPage> createState() => _P2PCallPageState();
}

// 🌐 Peer info
class PeerInfo {
  final String uid;
  final String name;
  final RTCVideoRenderer renderer;
  RTCPeerConnection? pc;

  PeerInfo({required this.uid, required this.name, required this.renderer});
}

class _P2PCallPageState extends State<P2PCallPage> {
  final _localRenderer = RTCVideoRenderer();

  // 🌐 MESH: Map từ uid -> PeerInfo
  final Map<String, PeerInfo> _peers = {};

  MediaStream? _localStream;
  MediaStream? _screenStream; // 🖥️ Screen share stream

  WebSocketChannel? _ws;
  late final String _myUid;

  // P2P Chat - TCP cho mobile/desktop
  P2PTcpServer? _p2pServer;
  final Map<String, Map<String, dynamic>> _roomPeers =
      {}; // uid -> {name, ip, port}
  String? _myLocalIp;

  // WebRTC P2P Chat cho web (true P2P)
  WebRTCP2PChat? _webrtcP2PChat;

  bool micMuted = false;
  bool camEnabled = true;
  bool _isAudioOnlyMode = false; // 🎤 Flag cho chế độ audio-only
  bool _isScreenSharing = false; // 🖥️ Flag cho screen sharing
  // UI panels
  String _activePanel = 'none'; // none | participants | chat | settings
  final List<ChatMessage> _messages = []; // room chat messages
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  String? _awaitEchoText; // suppress duplicate echo of our sent message
  // View state
  String _viewMode = 'grid'; // grid | list (placeholder)
  bool _isFullscreen = false; // placeholder
  String? _currentScreenSharerUid; // uid của người đang chia sẻ màn hình

  @override
  void initState() {
    super.initState();
    _myUid = '${widget.currentUserId}-${DateTime.now().microsecondsSinceEpoch}';
    if (widget.initialMicMuted != null) {
      micMuted = widget.initialMicMuted!;
    }
    if (widget.initialCamEnabled != null) {
      camEnabled = widget.initialCamEnabled!;
    }
    _initAll();
  }

  // ===== Chat panel =====
  Widget _buildChatPanel() {
    return Column(
      children: [
        // Chat Summary Button with Back Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            border: Border(bottom: BorderSide(color: Colors.purple.shade100)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.purple,
                tooltip: 'Quay lại',
                onPressed: () {
                  setState(() {
                    _activePanel = 'none';
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Chat trong cuộc gọi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            controller: _chatScrollController,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final align =
                  m.isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start;
              final bubbleColor =
                  m.isSelf ? Colors.purple.shade700 : Colors.blueGrey.shade700;
              return Container(
                alignment:
                    m.isSelf ? Alignment.centerRight : Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.text,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(m.timestamp),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Emoji',
                icon: const Icon(Icons.emoji_emotions_outlined,
                    color: Colors.orangeAccent),
                onPressed: _openEmojiPicker,
              ),
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    hintText: 'Gửi tin nhắn...',
                    hintStyle: TextStyle(color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                color: Colors.black87,
                onPressed: _onSendChat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openEmojiPicker() async {
    final emojis = [
      '😀',
      '😁',
      '😂',
      '🤣',
      '😊',
      '😍',
      '😘',
      '😎',
      '🤔',
      '😢',
      '😭',
      '😡',
      '👍',
      '👎',
      '🙏',
      '🔥',
      '🎉',
      '❤️',
      '💔',
      '⚡',
      '🎶',
      '📌',
      '✅',
      '❌'
    ];
    final res = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black87,
      builder: (ctx) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, i) {
            final e = emojis[i];
            return InkWell(
              onTap: () => Navigator.pop(context, e),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          },
        );
      },
    );
    if (res != null && res.isNotEmpty) {
      _chatController.text += res;
      _chatController.selection = TextSelection.fromPosition(
        TextPosition(offset: _chatController.text.length),
      );
    }
  }

  void _onSendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();

    final timestamp = DateTime.now();
    final msg = ChatMessage(
      id: '${timestamp.microsecondsSinceEpoch}',
      senderId: widget.currentUserId,
      senderName: widget.displayName ?? 'You',
      text: text,
      timestamp: timestamp,
      isSelf: true,
    );

    setState(() {
      _messages.add(msg);
    });
    _scrollChatToBottom();

    // Save locally
    LocalMessageStorage.saveMessage(
      roomCode: widget.room.roomCode,
      senderId: widget.currentUserId,
      senderName: widget.displayName ?? 'You',
      text: text,
      timestamp: timestamp,
      synced: false,
    );

    // Track this message to avoid duplicate echo
    _awaitEchoText = text;

    // Send via P2P to all peers in room
    _broadcastToPeersP2P(
        text, widget.currentUserId, widget.displayName ?? 'You', timestamp);
  }

  Future<void> _broadcastToPeersP2P(
      String text, int senderId, String senderName, DateTime timestamp) async {
    debugPrint('🔊 P2P Broadcast to ${_roomPeers.length} peers');

    final message = {
      'type': 'chat',
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };

    // Web: WebRTC DataChannel P2P (pure P2P, NO server relay)
    if (kIsWeb) {
      if (_webrtcP2PChat != null) {
        await _webrtcP2PChat!.broadcast(message);
        debugPrint('✅ P2P sent via WebRTC DataChannel');
      } else {
        debugPrint('⚠️ WebRTC P2P Chat not initialized');
      }
    }
    // Mobile/Desktop: TCP socket P2P (pure P2P, NO server relay)
    else {
      if (_roomPeers.isEmpty) {
        debugPrint('⚠️ No peers - message NOT sent (pure P2P mode)');
        return;
      }

      final peerIps = _roomPeers.values.map((p) => p['ip'] as String).toList();

      if (_p2pServer != null) {
        await _p2pServer!.broadcastToPeers(peerIps, message);
        debugPrint('✅ P2P sent via TCP socket');
      } else {
        debugPrint('❌ TCP P2P server not initialized');
      }
    }
  }

  void _handleIncomingChat(
      int senderId, String senderName, String text, DateTime ts,
      {int? messageId}) {
    final msg = ChatMessage(
      id: '${ts.microsecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      text: text,
      timestamp: ts,
      isSelf: senderId == widget.currentUserId,
      messageId: messageId,
    );
    setState(() {
      _messages.add(msg);
    });
    _scrollChatToBottom();
  }

  void _sendChatSignal(String text) {
    try {
      final payload = {
        't': 'chat',
        'roomCode': widget.room.roomCode,
        'fromUserId': widget.currentUserId,
        'fromName': widget.displayName ?? 'You',
        'text': text,
        'ts': DateTime.now().toIso8601String(),
      };
      _send(payload);
    } catch (e) {
      debugPrint('chat send error: $e');
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _scrollChatToBottom() {
    if (!_chatScrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ================== P2P TCP SERVER ==================

  Future<void> _initP2PServer() async {
    try {
      final info = NetworkInfo();
      _myLocalIp = await info.getWifiIP();

      if (_myLocalIp == null) {
        debugPrint('⚠️ Cannot get local IP');
        return;
      }

      _p2pServer = P2PTcpServer();
      _p2pServer!.onMessageReceived = (msg) {
        // Nhận tin nhắn từ peer khác
        if (msg['type'] == 'chat') {
          final senderId = msg['senderId'] as int?;
          final senderName = msg['senderName'] as String?;
          final text = msg['text'] as String?;
          final timestamp = msg['timestamp'] as String?;

          if (senderId != null &&
              senderName != null &&
              text != null &&
              timestamp != null) {
            final ts = DateTime.tryParse(timestamp) ?? DateTime.now();

            // Avoid duplicate echo from server when it relays back
            if (senderId == widget.currentUserId && _awaitEchoText == text) {
              debugPrint('⏭️ Skipping duplicate echo from TCP');
              _awaitEchoText = null;
              return;
            }

            _handleIncomingChat(senderId, senderName, text, ts);

            // Lưu vào local storage
            LocalMessageStorage.saveMessage(
              roomCode: widget.room.roomCode,
              senderId: senderId,
              senderName: senderName,
              text: text,
              timestamp: ts,
              synced: false, // Chưa sync lên server
            );
          }
        }
      };

      final started = await _p2pServer!.start();
      if (started) {
        debugPrint('✅ P2P server started on $_myLocalIp:9999');
      }
    } catch (e) {
      debugPrint('❌ Failed to init P2P server: $e');
    }
  }

  // Legacy WebRTC offline manager removed in pure P2P mode

  Future<void> _initAll() async {
    await _localRenderer.initialize();

    // Khởi tạo P2P Chat
    if (kIsWeb) {
      _initWebRTCP2PChat();
    } else {
      // Init P2P TCP server cho mobile/desktop
      await _initP2PServer();
    }

    // Luôn bật local trước
    await _startLocalStream();

    // Sau đó connect WS
    await _connectWs();
  }

  /// Initialize WebRTC P2P Chat for web (pure P2P)
  void _initWebRTCP2PChat() {
    debugPrint('🌐 Initializing WebRTC P2P Chat for web');
    _webrtcP2PChat = WebRTCP2PChat(
      myUid: _myUid,
      sendSignal: (payload) {
        // Gửi signaling message qua WebSocket
        if (_ws != null) {
          try {
            _ws!.sink.add(jsonEncode(payload));
          } catch (e) {
            debugPrint('⚠️ Failed to send signal: $e');
          }
        }
      },
      onMessageReceived: (peerId, message) {
        // Nếu là message chia sẻ màn hình thì cập nhật UI, không ảnh hưởng chat
        if (message['type'] == 'screen_share') {
          final sharerUid = message['uid'] as String?;
          final active = message['active'] as bool?;
          if (active == true && sharerUid != null) {
            setState(() {
              _currentScreenSharerUid = sharerUid;
            });
          } else if (active == false && sharerUid != null) {
            if (_currentScreenSharerUid == sharerUid) {
              setState(() {
                _currentScreenSharerUid = null;
              });
            }
          }
          return;
        }
        // ...existing code chat...
        final senderId = message['senderId'] as int?;
        final senderName = message['senderName'] as String?;
        final text = message['text'] as String?;
        final timestamp = message['timestamp'] as String?;

        if (senderId != null &&
            senderName != null &&
            text != null &&
            timestamp != null) {
          final ts = DateTime.tryParse(timestamp) ?? DateTime.now();
          _handleIncomingChat(senderId, senderName, text, ts);
        }
      },
    );
  }

  // ================== MEDIA ==================

  Future<void> _startLocalStream({bool allowFailure = false}) async {
    if (_localStream != null) return;

    try {
      // 🎥 Thử lấy cả video + audio
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
          'frameRate': 30,
        },
      });

      debugPrint(
          '🎥 getUserMedia (video+audio) OK: v=${stream.getVideoTracks().length} a=${stream.getAudioTracks().length}');

      _localStream = stream;
      _localRenderer.srcObject = stream;
      setState(() {});
      _applyPrejoinStates();

      // nếu đã có PC thì add track vào TẤT CẢ các peers
      if (_peers.isNotEmpty) {
        debugPrint(
            '➕ addTrack local vào ${_peers.length} PC(s) (sau getUserMedia)');
        for (final peer in _peers.values) {
          if (peer.pc != null) {
            for (final track in stream.getTracks()) {
              await peer.pc!.addTrack(track, stream);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ getUserMedia (video+audio) FAILED: $e');

      // 🎤 Fallback: Chỉ lấy audio (không có video)
      try {
        debugPrint('🔄 Fallback: Thử chỉ lấy audio...');
        final audioOnlyStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });

        debugPrint(
            '🎤 Audio-only mode: a=${audioOnlyStream.getAudioTracks().length}');

        _localStream = audioOnlyStream;
        _isAudioOnlyMode = true; // 🎤 Đánh dấu là audio-only
        // Không set srcObject vì không có video
        _localRenderer.srcObject = null;
        setState(() {});

        // Add audio track vào TẤT CẢ PC nếu đã có
        if (_peers.isNotEmpty) {
          debugPrint('➕ addTrack audio-only vào ${_peers.length} PC(s)');
          for (final peer in _peers.values) {
            if (peer.pc != null) {
              for (final track in audioOnlyStream.getTracks()) {
                await peer.pc!.addTrack(track, audioOnlyStream);
              }
            }
          }
        }

        // Thông báo user đang ở chế độ audio-only
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📞 Camera không khả dụng. Chế độ chỉ Audio.'),
              duration: Duration(seconds: 3),
            ),
          );
        }

        return; // Thành công với audio-only
      } catch (audioError) {
        debugPrint('❌ Audio-only cũng FAILED: $audioError');

        // Nếu cho phép fail thì không throw
        if (allowFailure) {
          _localStream = null;
          _localRenderer.srcObject = null;
          setState(() {});
          return;
        }

        rethrow; // Thất bại hoàn toàn
      }
    }
  }

  // Áp dụng trạng thái mic/cam sau khi có stream
  void _applyPrejoinStates() {
    if (_localStream == null) return;
    // mic
    for (final t in _localStream!.getAudioTracks()) {
      t.enabled = !micMuted;
    }
    // cam
    for (final t in _localStream!.getVideoTracks()) {
      t.enabled = camEnabled;
    }
  }

  // 🌐 Tạo PeerConnection cho 1 peer cụ thể
  Future<RTCPeerConnection> _createPeerConnection(String peerUid) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      // 🔥 bật Unified Plan để onTrack hoạt động đúng
      'sdpSemantics': 'unified-plan',
    });

    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      debugPrint('❄️ ICE for peer=$peerUid: ${c.candidate}');
      _send({
        't': 'ice',
        'from': _myUid,
        'to': peerUid,
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    // Unified Plan: nhận remote track
    pc.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        debugPrint(
            '📺 onTrack from peer=$peerUid stream=${e.streams[0].id} kind=${e.track.kind}');
        final peer = _peers[peerUid];
        if (peer != null) {
          setState(() {
            peer.renderer.srcObject = e.streams[0];
          });
        }
      } else {
        debugPrint('📺 onTrack nhưng streams rỗng, kind=${e.track.kind}');
      }
    };

    // fallback Plan-B nếu plugin còn bắn onAddStream
    pc.onAddStream = (MediaStream s) {
      debugPrint('📺 onAddStream from peer=$peerUid stream=${s.id}');
      final peer = _peers[peerUid];
      if (peer != null) {
        setState(() {
          peer.renderer.srcObject = s;
        });
      }
    };

    pc.onConnectionState = (st) {
      debugPrint('🔗 PC with peer=$peerUid state = $st');
    };

    // Add local tracks nếu đã có
    if (_localStream != null) {
      debugPrint('➕ addTrack local vào PC for peer=$peerUid');
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    return pc;
  }

  // ================== SCREEN SHARING ==================

  Future<void> _toggleScreenSharing() async {
    if (_isScreenSharing) {
      // Đang share → stop và quay về camera
      await _stopScreenSharing();
    } else {
      // Chưa share → bắt đầu share
      await _startScreenSharing();
    }
  }

  Future<void> _startScreenSharing() async {
    try {
      debugPrint('🖥️ Starting screen share...');

      // ⚠️ Check platform - Screen share chỉ hoạt động tốt trên Web
      if (!kIsWeb) {
        debugPrint('⚠️ Screen sharing on Desktop is experimental');

        if (mounted) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('⚠️ Chức năng thử nghiệm'),
              content: Text(
                'Screen sharing trên Windows Desktop có thể không hoạt động.\n\n'
                'Để sử dụng tốt nhất, vui lòng chạy ứng dụng trên Chrome:\n\n'
                'flutter run -d chrome\n\n'
                'Bạn có muốn thử tiếp không?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Hủy'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Thử'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) return;
        }
      }

      // Capture screen
      final screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'width': 1920,
          'height': 1080,
          'frameRate': 30,
        },
        'audio': false, // Screen audio có thể bật nếu cần
      });

      debugPrint(
          '🖥️ Screen capture OK: ${screenStream.getVideoTracks().length} tracks');

      _screenStream = screenStream;
      _isScreenSharing = true;

      // Gửi message screen_share qua DataChannel cho các peer
      if (_webrtcP2PChat != null) {
        _webrtcP2PChat!.broadcast({
          'type': 'screen_share',
          'uid': _myUid,
          'active': true,
        });
      }

      // Lắng nghe sự kiện user stop share từ browser UI
      final videoTrack = screenStream.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.onEnded = () {
          debugPrint('🖥️ Screen share ended by user');
          _stopScreenSharing();
        };
      }

      // Replace video track trong local renderer
      _localRenderer.srcObject = screenStream;

      // Replace video track trong TẤT CẢ PeerConnections
      final screenVideoTrack = screenStream.getVideoTracks().first;
      for (final peer in _peers.values) {
        if (peer.pc != null) {
          // Tìm sender của video track cũ
          final senders = await peer.pc!.getSenders();
          final videoSender = senders.firstWhere(
            (s) => s.track?.kind == 'video',
            orElse: () => throw Exception('No video sender found'),
          );

          // Replace track
          await videoSender.replaceTrack(screenVideoTrack);
          debugPrint('🖥️ Replaced video track for peer=${peer.uid}');
        }
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🖥️ Đang chia sẻ màn hình'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Screen share failed: $e');
      _isScreenSharing = false;
      setState(() {});

      if (mounted) {
        // Thông báo lỗi rõ ràng hơn
        String errorMessage;
        if (e.toString().contains('source not found') ||
            e.toString().contains('NotFoundError')) {
          errorMessage = kIsWeb
              ? '❌ Bạn đã hủy chia sẻ màn hình'
              : '❌ Screen sharing không được hỗ trợ trên Desktop.\n\nVui lòng chạy: flutter run -d chrome';
        } else if (e.toString().contains('Permission denied') ||
            e.toString().contains('NotAllowedError')) {
          errorMessage = '🚫 Bạn đã từ chối quyền chia sẻ màn hình';
        } else {
          errorMessage = '❌ Không thể chia sẻ màn hình: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 5),
            action: kIsWeb
                ? null
                : SnackBarAction(
                    label: 'Hướng dẫn',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('💡 Cách sử dụng Screen Sharing'),
                          content: SingleChildScrollView(
                            child: Text(
                              '🌐 Screen Sharing hoạt động tốt nhất trên Web Browser\n\n'
                              '1️⃣ Đóng ứng dụng hiện tại\n\n'
                              '2️⃣ Chạy lệnh sau:\n'
                              '   flutter run -d chrome\n\n'
                              '3️⃣ Hoặc:\n'
                              '   flutter run -d edge\n\n'
                              '4️⃣ Khi app mở trên browser, click nút Screen Share\n\n'
                              '5️⃣ Chọn màn hình/cửa sổ muốn chia sẻ\n\n'
                              '✅ Tất cả người trong room sẽ thấy màn hình của bạn!',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Đã hiểu'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      }
    }
  }

  Future<void> _stopScreenSharing() async {
    if (_screenStream == null) return;

    debugPrint('🖥️ Stopping screen share...');

    // Stop screen tracks
    for (final track in _screenStream!.getTracks()) {
      track.stop();
    }
    await _screenStream!.dispose();
    _screenStream = null;
    _isScreenSharing = false;

    // Gửi message screen_share qua DataChannel cho các peer
    if (_webrtcP2PChat != null) {
      _webrtcP2PChat!.broadcast({
        'type': 'screen_share',
        'uid': _myUid,
        'active': false,
      });
    }

    // Quay về camera stream
    if (_localStream != null) {
      _localRenderer.srcObject = _localStream;

      // Replace lại video track về camera trong TẤT CẢ PeerConnections
      final cameraVideoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (cameraVideoTrack != null) {
        for (final peer in _peers.values) {
          if (peer.pc != null) {
            final senders = await peer.pc!.getSenders();
            final videoSender = senders.firstWhere(
              (s) => s.track?.kind == 'video',
              orElse: () => throw Exception('No video sender found'),
            );

            await videoSender.replaceTrack(cameraVideoTrack);
            debugPrint('📹 Switched back to camera for peer=${peer.uid}');
          }
        }
      }
    }

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📹 Đã dừng chia sẻ màn hình'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ================== SIGNALING WS ==================

  Future<void> _connectWs() async {
    final httpBase = ApiService.baseUrl; // http://192.168.2.204:8080
    final wsBase = httpBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst(':8080', ':8081'); // signaling ở 8081

    final uri = Uri.parse('$wsBase/ws');
    debugPrint('🔌 WS connect: $uri');

    try {
      _ws = WebSocketChannel.connect(uri);

      _ws!.stream.listen(
        (data) {
          debugPrint('📩 WS recv: $data');
          final m = jsonDecode(data as String) as Map<String, dynamic>;
          _onWsMessage(m);
        },
        onDone: () => debugPrint('WS closed'),
        onError: (e) => debugPrint('WS error: $e'),
      );

      _send({
        't': 'join',
        'room': widget.room.roomCode, // "R000001"
        'uid': _myUid,
        'name': widget.displayName ?? 'User ${widget.currentUserId}',
        'userId': widget.currentUserId,
        'peerIp': _myLocalIp ?? '127.0.0.1',
        'peerPort': '9999',
      });
    } catch (e) {
      debugPrint('❌ WS connection failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Kết nối WebSocket thất bại: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _send(Map<String, dynamic> m) {
    if (_ws == null) return;
    final txt = jsonEncode(m);
    debugPrint('📤 WS send: $txt');
    _ws!.sink.add(txt);
  }

  Future<void> _onWsMessage(Map<String, dynamic> m) async {
    final t = m['t'] as String? ?? '';

    switch (t) {
      case 'peers':
        // 🌐 Backend gửi danh sách peers đang có trong room (bao gồm P2P info)
        final peersList = (m['peers'] as List<dynamic>? ?? []);
        debugPrint('📋 Received peers: ${peersList.length}');
        debugPrint('📋 Full peers response: ${jsonEncode(m)}');

        if (peersList.isEmpty) {
          debugPrint('⚠️ NO PEERS RECEIVED - You are alone in room');
        }

        for (final p in peersList) {
          final peerData = p as Map<String, dynamic>;
          final uid = peerData['uid'] as String;
          final name = peerData['name'] as String? ?? uid;
          final ip = peerData['ip'] as String?;
          final port = peerData['port'] as String?;

          debugPrint(
              '🔍 Processing peer: uid=$uid, name=$name, ip=$ip, port=$port');

          // Skip nếu đây là chính mình (duplicate connection)
          if (uid == _myUid ||
              uid.startsWith('${widget.currentUserId}-') ||
              uid.startsWith('host_${widget.currentUserId}_')) {
            debugPrint(
                '⚠️ Skip duplicate peer in peers list: $uid (same user)');
            continue;
          }

          // Store peer info for P2P
          if (ip != null) {
            setState(() {
              _roomPeers[uid] = {
                'name': name,
                'ip': ip,
                'port': port ?? '9999'
              };
            });
            debugPrint(
                '👤 Peer added to P2P list: $name ($uid) at $ip:${port ?? "9999"}');

            // Web: offline legacy WebRTC removed in pure P2P mode
          } else {
            debugPrint('⚠️ Peer $uid has no IP info');
          }

          // Initialize WebRTC P2P Chat connection on web
          if (kIsWeb && _webrtcP2PChat != null) {
            try {
              await _webrtcP2PChat!.initPeerConnection(uid);
              debugPrint('✅ WebRTC P2P Chat peer init for $uid');
            } catch (e) {
              debugPrint('❌ Failed to init WebRTC P2P for $uid: $e');
            }
          }

          await _addPeer(uid, name);

          // Mình vào sau → mình gọi offer cho từng peer có sẵn
          await _createOfferForPeer(uid);
        }
        debugPrint('✅ Total P2P peers in _roomPeers: ${_roomPeers.length}');
        break;

      case 'peer.joined':
        // 🌐 Có người mới join vào room (kèm P2P info)
        final uid = m['uid'] as String?;
        final name = m['name'] as String?;
        final ip = m['ip'] as String?;
        final port = m['port'] as String?;
        if (uid == null || name == null) return;

        // Skip nếu đây là chính mình (duplicate connection)
        if (uid == _myUid ||
            uid.startsWith('${widget.currentUserId}-') ||
            uid.startsWith('host_${widget.currentUserId}_')) {
          debugPrint('⚠️ Skip duplicate peer: $uid (same user)');
          return;
        }

        // Store peer info for P2P
        if (ip != null) {
          setState(() {
            _roomPeers[uid] = {'name': name, 'ip': ip, 'port': port ?? '9999'};
          });
          debugPrint(
              '👤 New peer for P2P: $name ($uid) at $ip:${port ?? "9999"}');

          // Web: offline legacy WebRTC removed in pure P2P mode
        }

        debugPrint('🚪 Peer joined: $uid ($name)');
        await _addPeer(uid, name);

        // Người mới join sẽ tự gửi offer cho mình; mình không chủ động tạo offer để tránh glare
        break;

      case 'offer':
        await _handleOffer(m);
        break;

      case 'answer':
        await _handleAnswer(m);
        break;

      case 'ice':
        await _handleIce(m);
        break;

      // WebRTC P2P Chat signaling handlers
      case 'webrtc.offer':
        if (kIsWeb && _webrtcP2PChat != null) {
          final peerId = m['fromUid'] as String?;
          final sdp = m['sdp'] as String?;
          if (peerId != null && sdp != null) {
            debugPrint('📥 Received WebRTC offer from $peerId');
            await _webrtcP2PChat!.handleOffer(peerId, sdp);
          }
        }
        break;

      case 'webrtc.answer':
        if (kIsWeb && _webrtcP2PChat != null) {
          final peerId = m['fromUid'] as String?;
          final sdp = m['sdp'] as String?;
          if (peerId != null && sdp != null) {
            debugPrint('📥 Received WebRTC answer from $peerId');
            await _webrtcP2PChat!.handleAnswer(peerId, sdp);
          }
        }
        break;

      case 'webrtc.ice':
        if (kIsWeb && _webrtcP2PChat != null) {
          final peerId = m['fromUid'] as String?;
          final candidate = m['candidate'] as String?;
          final sdpMid = m['sdpMid'] as String?;
          final sdpMLineIndex = m['sdpMLineIndex'] as int?;
          if (peerId != null && candidate != null) {
            debugPrint('📥 Received ICE candidate from $peerId');
            await _webrtcP2PChat!.handleIceCandidate(
              peerId,
              candidate,
              sdpMid ?? '',
              sdpMLineIndex ?? 0,
            );
          }
        }
        break;

      case 'peer.left':
        final uid = m['uid'] as String?;
        if (uid != null) {
          debugPrint('🚪 Peer left: $uid');
          await _removePeer(uid);
        }
        break;

      case 'peer.kicked':
        final uid = m['uid'] as String?;
        if (uid == null) break;
        if (uid == _myUid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bạn đã bị kick khỏi phòng')),
            );
          }
          await _leave();
        } else {
          await _removePeer(uid);
        }
        break;

      case 'chat':
        // Handle both old format (fromUserId, fromName, ts) and new format (senderId, senderName, timestamp)
        final senderId = (m['fromUserId'] ?? m['senderId']) as int?;
        final senderName = (m['fromName'] ?? m['senderName']) as String?;
        final text = m['text'] as String?;
        final tsStr = (m['ts'] ?? m['timestamp']) as String?;
        final mid = m['messageId'] as int?;
        if (senderId != null &&
            senderName != null &&
            text != null &&
            tsStr != null) {
          final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
          // avoid duplicating our own optimistic message
          if (senderId == widget.currentUserId && _awaitEchoText == text) {
            _awaitEchoText = null;
            break;
          }
          _handleIncomingChat(senderId, senderName, text, ts, messageId: mid);
        }
        break;

      case 'chat_history':
        final list = m['messages'] as List<dynamic>?;
        if (list != null) {
          for (final raw in list) {
            if (raw is Map<String, dynamic>) {
              final senderId =
                  raw['fromUserId'] is int ? raw['fromUserId'] as int : 0;
              final senderName = raw['fromName'] as String? ?? 'Unknown';
              final text = raw['text'] as String? ?? '';
              final tsStr = raw['ts'] as String?;
              final ts = tsStr != null
                  ? DateTime.tryParse(tsStr) ?? DateTime.now()
                  : DateTime.now();
              _handleIncomingChat(senderId, senderName, text, ts);
            }
          }
        }
        break;
    }
  }

  // Helper: Kiểm tra xem uid có phải là approval connection không
  bool _isApprovalConnection(String uid) {
    // Approval connections: host_{userId}_{timestamp} hoặc {userId}_{timestamp} (từ RoomsPage)
    // Call connections: {userId}-{timestamp} (dùng dấu -)
    return uid.startsWith('host_') || uid.contains('_');
  }

  // 🌐 Thêm peer mới vào map
  Future<void> _addPeer(String uid, String name) async {
    if (_peers.containsKey(uid)) return;

    // Skip approval connections - chỉ giữ call connections
    if (_isApprovalConnection(uid)) {
      debugPrint('⚠️ Skip approval connection: $uid (not a call connection)');
      return;
    }

    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    _peers[uid] = PeerInfo(uid: uid, name: name, renderer: renderer);
    setState(() {});

    debugPrint('✅ Added peer: $uid ($name)');
  }

  // 🌐 Xóa peer khỏi map
  Future<void> _removePeer(String uid) async {
    final peer = _peers.remove(uid);
    if (peer == null) return;

    await peer.pc?.close();
    peer.renderer.srcObject = null;
    await peer.renderer.dispose();

    setState(() {});
    debugPrint('❌ Removed peer: $uid');
  }

  // ================== OFFER / ANSWER ==================

  // 🌐 Tạo offer cho peer cụ thể
  Future<void> _createOfferForPeer(String peerUid) async {
    // ⚠️ Cho phép lỗi cam nhưng vẫn tiếp tục call
    await _startLocalStream(allowFailure: true);

    final peer = _peers[peerUid];
    if (peer == null) return;

    // Tạo PC nếu chưa có
    peer.pc ??= await _createPeerConnection(peerUid);

    final offer = await peer.pc!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await peer.pc!.setLocalDescription(offer);

    debugPrint('📤 send OFFER to=$peerUid');
    _send({
      't': 'offer',
      'from': _myUid,
      'to': peerUid,
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  Future<void> _handleOffer(Map<String, dynamic> m) async {
    final fromUid = m['from'] as String?;
    if (fromUid == null) return;

    // ⚠️ Cho phép lỗi cam nhưng vẫn nhận remote video
    await _startLocalStream(allowFailure: true);

    // Lấy hoặc tạo peer
    var peer = _peers[fromUid];
    if (peer == null) {
      // Peer chưa tồn tại → tạo mới
      await _addPeer(fromUid, 'User-${fromUid.substring(0, 6)}');
      peer = _peers[fromUid];
    }
    if (peer == null) return;

    // Tạo PC nếu chưa có
    peer.pc ??= await _createPeerConnection(fromUid);

    final remoteDesc = RTCSessionDescription(
      m['sdp'] as String,
      m['type'] as String,
    );
    debugPrint('📥 setRemoteDescription(offer) from=$fromUid');
    await peer.pc!.setRemoteDescription(remoteDesc);

    final answer = await peer.pc!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await peer.pc!.setLocalDescription(answer);

    debugPrint('📤 send ANSWER to=$fromUid');
    _send({
      't': 'answer',
      'from': _myUid,
      'to': fromUid,
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> m) async {
    final fromUid = m['from'] as String?;
    if (fromUid == null) return;

    final peer = _peers[fromUid];
    if (peer?.pc == null) return;

    final remoteDesc = RTCSessionDescription(
      m['sdp'] as String,
      m['type'] as String,
    );
    debugPrint('📥 setRemoteDescription(answer) from=$fromUid');
    await peer!.pc!.setRemoteDescription(remoteDesc);
  }

  Future<void> _handleIce(Map<String, dynamic> m) async {
    final fromUid = m['from'] as String?;
    if (fromUid == null) return;

    final peer = _peers[fromUid];
    if (peer?.pc == null) return;

    final cand = RTCIceCandidate(
      m['candidate'] as String?,
      m['sdpMid'] as String?,
      m['sdpMLineIndex'] as int?,
    );
    debugPrint('❄️ addCandidate from=$fromUid');
    await peer!.pc!.addCandidate(cand);
  }

  // ================== LEAVE / CLEANUP ==================

  Future<void> _leave() async {
    try {
      _send({'t': 'leave', 'uid': _myUid});
    } catch (_) {}

    try {
      await _ws?.sink.close();
    } catch (_) {}

    // 🌐 Đóng tất cả PeerConnections
    for (final peer in _peers.values) {
      try {
        await peer.pc?.close();
      } catch (_) {}

      peer.renderer.srcObject = null;
      try {
        await peer.renderer.dispose();
      } catch (_) {}
    }
    _peers.clear();

    // 🖥️ Stop screen sharing nếu đang share
    if (_screenStream != null) {
      for (final t in _screenStream!.getTracks()) {
        t.stop();
      }
      await _screenStream!.dispose();
    }

    if (_localStream != null) {
      for (final t in _localStream!.getTracks()) {
        t.stop();
      }
      await _localStream!.dispose();
    }

    _localRenderer.srcObject = null;
    await _localRenderer.dispose();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _ws?.sink.close();

    for (final peer in _peers.values) {
      peer.pc?.close();
      peer.renderer.dispose();
    }

    _screenStream?.dispose(); // 🖥️ Dispose screen stream
    _localStream?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    // 🌐 Tổng số ô trong grid = local (1) + remote peers
    final totalParticipants = 1 + _peers.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEBFF),
      appBar: AppBar(
        title: Text('P2P Mesh: ${widget.room.name} ($totalParticipants)'),
        backgroundColor: Colors.purple[100],
      ),
      body: Row(
        children: [
          // Left taskbar
          Container(
            width: 64,
            color: Colors.purple[50],
            child: Column(
              children: [
                const SizedBox(height: 12),
                IconButton(
                  tooltip: 'Participants',
                  icon: Icon(
                    Icons.people_alt,
                    color: _activePanel == 'participants'
                        ? Colors.purple
                        : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() => _activePanel = _activePanel == 'participants'
                        ? 'none'
                        : 'participants');
                  },
                ),
                IconButton(
                  tooltip: 'Chat',
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color:
                        _activePanel == 'chat' ? Colors.purple : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() => _activePanel == 'chat'
                        ? _activePanel = 'none'
                        : _activePanel = 'chat');
                  },
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: Icon(
                    Icons.settings,
                    color: _activePanel == 'settings'
                        ? Colors.purple
                        : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() => _activePanel =
                        _activePanel == 'settings' ? 'none' : 'settings');
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Leave',
                  icon: const Icon(Icons.call_end, color: Colors.red),
                  onPressed: _leave,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Main content + right panel
          Expanded(
            child: Column(
              children: [
                // Video grid
                Expanded(child: _buildVideoGrid()),
                // Controls
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(micMuted ? Icons.mic_off : Icons.mic),
                        onPressed: () {
                          setState(() => micMuted = !micMuted);
                          final enabled = !micMuted;
                          _localStream?.getAudioTracks().forEach((t) {
                            t.enabled = enabled;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                            camEnabled ? Icons.videocam : Icons.videocam_off),
                        onPressed: () {
                          setState(() => camEnabled = !camEnabled);
                          final enabled = camEnabled;
                          _localStream?.getVideoTracks().forEach((t) {
                            t.enabled = enabled;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isScreenSharing
                              ? Icons.stop_screen_share
                              : Icons.screen_share,
                          color: _isScreenSharing ? Colors.green : null,
                        ),
                        onPressed: _toggleScreenSharing,
                        tooltip: _isScreenSharing
                            ? 'Dừng chia sẻ màn hình'
                            : 'Chia sẻ màn hình',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Right side panel
          Container(
            width: _activePanel == 'none' ? 0 : 280,
            color: Colors.white,
            child: _buildSidePanel(),
          ),
        ],
      ),
    );
  }

  // 🌐 Build grid layout cho tất cả participants
  Widget _buildVideoGrid() {
    final totalParticipants = 1 + _peers.length;

    // Sử dụng _currentScreenSharerUid cho UI
    if (_isScreenSharing) {
      final peersList = _peers.values.toList();
      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _buildLocalVideoTile(),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final peer in peersList)
                  Container(
                    width: 120,
                    height: 68,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.blueGrey.shade700, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildRemoteVideoTile(peer),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if (_currentScreenSharerUid != null && _currentScreenSharerUid != _myUid) {
      final screenSharer = _peers[_currentScreenSharerUid!];
      if (screenSharer != null) {
        final peersList =
            _peers.values.where((p) => p.uid != screenSharer.uid).toList();
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildRemoteVideoTile(screenSharer),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 68,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.purple, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildLocalVideoTile(),
                    ),
                  ),
                  for (final peer in peersList)
                    Container(
                      width: 120,
                      height: 68,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.blueGrey.shade700, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _buildRemoteVideoTile(peer),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }
    }

    // Default: grid layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Responsive breakpoints by width
        // <=600: 1-2 cols, <=900: 2-3 cols, <=1200: 3 cols, >1200: 4 cols
        int baseCols;
        if (w <= 600)
          baseCols = 1;
        else if (w <= 900)
          baseCols = 2;
        else if (w <= 1200)
          baseCols = 3;
        else
          baseCols = 4;

        // Also limit by participant count
        int crossAxisCount =
            baseCols.clamp(1, (totalParticipants <= 1) ? 1 : 4);
        if (totalParticipants <= 2) crossAxisCount = crossAxisCount.clamp(1, 2);
        if (totalParticipants <= 4) crossAxisCount = crossAxisCount.clamp(1, 2);

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 16 / 9,
          ),
          itemCount: totalParticipants,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildLocalVideoTile();
            } else {
              final peersList = _peers.values.toList();
              final peer = peersList[index - 1];
              return _buildRemoteVideoTile(peer);
            }
          },
        );
      },
    );
  }

  // 🌐 Local video tile
  Widget _buildLocalVideoTile() {
    final showPlaceholder = !_isLocalVideoActive();
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.purple, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          if (showPlaceholder)
            _buildLocalAvatarPlaceholder()
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: RTCVideoView(_localRenderer, mirror: true),
            ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _isScreenSharing
                    ? '🖥️ You (Sharing Screen)'
                    : (showPlaceholder ? 'You (Cam Off)' : 'You (Local)'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎤 Audio-only placeholder widget
  Widget _buildAudioOnlyPlaceholder(String name, IconData icon) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🎤 Chỉ Audio',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌐 Remote avatar placeholder
  Widget _buildRemoteAvatar(String name) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blueGrey,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Đang kết nối...',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌐 Remote peer video tile
  Widget _buildRemoteVideoTile(PeerInfo peer) {
    final showPlaceholder = !_isPeerVideoActive(peer);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.blueGrey.shade700, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          if (showPlaceholder)
            _buildRemoteAvatar(peer.name)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: RTCVideoView(peer.renderer),
            ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                showPlaceholder ? '${peer.name} (Cam Off)' : peer.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Right panel builder =====
  Widget _buildSidePanel() {
    switch (_activePanel) {
      case 'participants':
        return _buildParticipantsPanel();
      case 'chat':
        return _buildChatPanel();
      case 'settings':
        return _buildSettingsPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLocalAvatarPlaceholder() {
    final name = widget.displayName ?? 'You';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.purple,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'Y',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAudioOnlyMode
                ? 'Chỉ Audio'
                : (!camEnabled
                    ? 'Camera tắt'
                    : (_localStream == null ? 'Chưa khởi tạo' : '')),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  bool _isLocalVideoActive() {
    if (_isScreenSharing) return true; // screen sharing coi như active
    if (_localStream == null) return false;
    if (_isAudioOnlyMode) return false;
    if (!camEnabled) return false;
    final tracks = _localStream!.getVideoTracks();
    if (tracks.isEmpty) return false;
    // Nếu tất cả track disabled → coi như off
    final anyEnabled = tracks.any((t) => t.enabled);
    return anyEnabled;
  }

  bool _isPeerVideoActive(PeerInfo peer) {
    final stream = peer.renderer.srcObject;
    if (stream == null) return false;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return false;
    return tracks.any((t) => t.enabled);
  }

  Widget _buildParticipantsPanel() {
    final items = [
      {
        'uid': _myUid,
        'name': widget.displayName ?? 'Bạn',
        'role':
            widget.room.createdBy == widget.currentUserId ? 'host' : 'member',
      },
      ..._peers.values.map((p) => {
            'uid': p.uid,
            'name': p.name,
            'role': p.uid.split('-').first == widget.room.createdBy.toString()
                ? 'host'
                : 'member',
          }),
    ];
    final isHost = widget.room.createdBy == widget.currentUserId;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
          child: const Text('Participants',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = items[i];
              final uid = it['uid']!;
              final name = it['name']!;
              final role = it['role']!;
              final isSelf = uid == _myUid;
              String subtitle = '';
              if (role == 'host') {
                subtitle = isSelf ? 'Bạn (Chủ phòng)' : 'Chủ phòng';
              } else {
                subtitle = isSelf ? 'Bạn' : 'Thành viên';
              }
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(role == 'host' ? Icons.star : Icons.person,
                      color: role == 'host' ? Colors.amber : null),
                  backgroundColor: role == 'host' ? Colors.yellow[50] : null,
                ),
                title: Text(name),
                subtitle: Text(subtitle),
                trailing: isHost && !isSelf && role != 'host'
                    ? TextButton.icon(
                        onPressed: () => _kickMember(uid),
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        label: const Text('Kick',
                            style: TextStyle(color: Colors.red)),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  void _kickMember(String uid) {
    // Send kick command over signaling; also remove locally
    _send({'t': 'kick', 'uid': uid, 'room': widget.room.roomCode});
    // Optimistic remove locally
    _removePeer(uid);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Đã kick $uid')));
  }

  // (removed legacy _buildChatPanel with _chatMessages)

  Widget _buildSettingsPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
          child: const Text('Cài đặt phòng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.view_comfy),
          title: const Text('Chuyển chế độ xem'),
          onTap: () {
            setState(() {
              _viewMode = _viewMode == 'grid' ? 'list' : 'grid';
            });
          },
          subtitle:
              Text('Hiện tại: ${_viewMode == 'grid' ? 'Lưới' : 'Danh sách'}'),
        ),
        ListTile(
          leading: const Icon(Icons.fullscreen),
          title: const Text('Toàn màn hình'),
          onTap: () {
            setState(() {
              _isFullscreen = !_isFullscreen;
            });
          },
          subtitle: Text(_isFullscreen ? 'Đang fullscreen' : 'Bình thường'),
        ),
      ],
    );
  }
}
