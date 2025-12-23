import 'dart:convert';

import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models/room.dart';
import 'models/call_session.dart';
import 'services/api_service.dart';
import 'services/webrtc_p2p_chat.dart';
// chat/messages removed: keep call/room and screen-share only

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

  // WebRTC P2P Chat cho web (used for screen-share signaling)
  WebRTCP2PChat? _webrtcP2PChat;

  bool micMuted = false;
  bool camEnabled = true;
  bool _isAudioOnlyMode = false; // 🎤 Flag cho chế độ audio-only
  bool _isScreenSharing = false; // 🖥️ Flag cho screen sharing
  // UI panels
  String _activePanel = 'none'; // none | participants | chat | settings
  // Room public chat messages
  final List<Map<String, dynamic>> _roomMessages = [];
  final TextEditingController _chatInputController = TextEditingController();
  String? _selectedIcon;
  // chat removed: no local chat storage or controllers
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

  // Chat UI removed — feature deprecated in this build

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ================== P2P TCP SERVER ==================

  // P2P TCP server removed with chat feature

  // Legacy WebRTC offline manager removed in pure P2P mode

  Future<void> _initAll() async {
    await _localRenderer.initialize();

    // Khởi tạo WebRTC P2P handler (dùng cho signaling like screen-share)
    if (kIsWeb) {
      _initWebRTCP2PChat();
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
        // Non-screen messages ignored (chat removed)
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

  Widget _buildChatPanel() {
    return Container(
      width: 320,
      color: Colors.grey[100],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Room chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: _roomMessages.length,
              itemBuilder: (context, idx) {
                final m = _roomMessages[idx];
                final from = m['fromName'] ?? m['fromUserId']?.toString() ?? 'User';
                final text = m['text'] ?? '';
                final icon = m['icon'] as String?;
                return ListTile(
                  leading: icon != null ? Text(icon, style: TextStyle(fontSize: 20)) : null,
                  title: Text(from),
                  subtitle: Text(text),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    decoration: InputDecoration(hintText: 'Type a message'),
                    onSubmitted: (_) => _sendRoomChat(),
                  ),
                ),
                IconButton(
                  tooltip: 'Pick icon',
                  icon: Icon(Icons.emoji_emotions_outlined),
                  onPressed: _showIconPickerDialog,
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendRoomChat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendRoomChat() {
    final txt = _chatInputController.text.trim();
    if (txt.isEmpty || _ws == null) return;
    final payload = {
      't': 'chat',
      'room': widget.room.roomCode,
      'text': txt,
    };
    if (_selectedIcon != null) payload['icon'] = _selectedIcon!;
    _send(payload);
    _chatInputController.clear();
    setState(() => _selectedIcon = null);
  }

  void _showIconPickerDialog() async {
    final icons = ['😀', '👍', '❤️', '🔥', '🎉', '😂', '😮', '👏', '🤝', '✨'];
    final picked = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn icon'),
        insetPadding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        content: SizedBox(
          width: 280,
          height: 140,
          child: GridView.count(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            children: icons.map((ic) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.all(6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(context).pop(ic),
                child: Text(ic, style: TextStyle(fontSize: 20)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text('Hủy')),
        ],
      ),
    );

    if (picked != null) {
      // Insert picked icon into text at caret position and mark selected
      final cur = _chatInputController;
      final text = cur.text;
      final sel = cur.selection;
      final int pos = (sel.isValid && sel.baseOffset >= 0) ? sel.baseOffset : text.length;
      final newText = text.replaceRange(pos, pos, picked);
      cur.text = newText;
      final newPos = pos + picked.length;
      cur.selection = TextSelection.collapsed(offset: newPos);
      setState(() {
        _selectedIcon = picked;
      });
      // bring focus back to input
      FocusScope.of(context).requestFocus(FocusNode());
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
          // ip/port (P2P TCP) removed

            debugPrint('🔍 Processing peer: uid=$uid, name=$name');

          // Skip nếu đây là chính mình (duplicate connection)
          if (uid == _myUid ||
              uid.startsWith('${widget.currentUserId}-') ||
              uid.startsWith('host_${widget.currentUserId}_')) {
            debugPrint(
                '⚠️ Skip duplicate peer in peers list: $uid (same user)');
            continue;
          }

          // P2P TCP info removed: just log peer
          debugPrint('👤 Peer info: $name ($uid)');

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
        debugPrint('✅ Processed peers list: ${peersList.length}');
        break;

      case 'peer.joined':
        // 🌐 Có người mới join vào room (kèm P2P info)
        final uid = m['uid'] as String?;
        final name = m['name'] as String?;
        if (uid == null || name == null) return;

        // Skip nếu đây là chính mình (duplicate connection)
        if (uid == _myUid ||
            uid.startsWith('${widget.currentUserId}-') ||
            uid.startsWith('host_${widget.currentUserId}_')) {
          debugPrint('⚠️ Skip duplicate peer: $uid (same user)');
          return;
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

      // Chat history (sent by server on join)
      case 'chat_history':
        final msgs = (m['messages'] as List<dynamic>?) ?? [];
        _roomMessages.clear();
        for (final it in msgs) {
          if (it is Map<String, dynamic>) _roomMessages.add(Map.from(it));
        }
        setState(() {});
        break;

      // New chat message broadcasted by server
      case 'chat.message':
      case 'chat.new':
        final msg = m['message'] as Map<String, dynamic>?;
        if (msg != null) {
          _roomMessages.add(Map.from(msg));
          // scroll or update UI
          setState(() {});
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

    _chatInputController.dispose();

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
                    Icons.chat_bubble,
                    color: _activePanel == 'chat' ? Colors.purple : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() => _activePanel = _activePanel == 'chat' ? 'none' : 'chat');
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
