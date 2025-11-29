import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'models/room.dart';
import 'models/call_session.dart';
import 'services/api_service.dart';

class P2PCallPage extends StatefulWidget {
  final Room room;
  final CallSession callSession;
  final int currentUserId;

  const P2PCallPage({
    super.key,
    required this.room,
    required this.callSession,
    required this.currentUserId,
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

  WebSocket? _ws;
  late final String _myUid;

  bool micMuted = false;
  bool camEnabled = true;
  bool _isAudioOnlyMode = false; // 🎤 Flag cho chế độ audio-only

  @override
  void initState() {
    super.initState();
    _myUid = '${widget.currentUserId}-${DateTime.now().microsecondsSinceEpoch}';
    _initAll();
  }

  Future<void> _initAll() async {
    await _localRenderer.initialize();

    // Luôn bật local trước
    await _startLocalStream();

    // Sau đó connect WS
    await _connectWs();
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

  // ================== SIGNALING WS ==================

  Future<void> _connectWs() async {
    final httpBase = ApiService.baseUrl; // http://192.168.2.204:8080
    final wsBase = httpBase
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst(':8080', ':8081'); // signaling ở 8081

    final uri = Uri.parse('$wsBase/ws');
    debugPrint('🔌 WS connect: $uri');

    _ws = await WebSocket.connect(uri.toString());
    _ws!.listen(
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
      'name': 'User $_myUid',
    });
  }

  void _send(Map<String, dynamic> m) {
    final txt = jsonEncode(m);
    debugPrint('📤 WS send: $txt');
    _ws?.add(txt);
  }

  Future<void> _onWsMessage(Map<String, dynamic> m) async {
    final t = m['t'] as String? ?? '';

    switch (t) {
      case 'peers':
        // 🌐 Backend gửi danh sách peers đang có trong room
        final peersList = (m['peers'] as List<dynamic>? ?? []);
        debugPrint('📋 Received peers: ${peersList.length}');

        for (final p in peersList) {
          final peerData = p as Map<String, dynamic>;
          final uid = peerData['uid'] as String;
          final name = peerData['name'] as String? ?? uid;

          await _addPeer(uid, name);

          // Mình vào sau → mình gọi offer cho từng peer có sẵn
          await _createOfferForPeer(uid);
        }
        break;

      case 'peer.joined':
        // 🌐 Có người mới join vào room
        final uid = m['uid'] as String?;
        final name = m['name'] as String?;
        if (uid == null || name == null) return;

        debugPrint('🚪 Peer joined: $uid ($name)');
        await _addPeer(uid, name);

        // Người mới join sẽ tự gửi offer, mình chỉ cần chờ
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

      case 'peer.left':
        final uid = m['uid'] as String?;
        if (uid != null) {
          debugPrint('🚪 Peer left: $uid');
          await _removePeer(uid);
        }
        break;
    }
  }

  // 🌐 Thêm peer mới vào map
  Future<void> _addPeer(String uid, String name) async {
    if (_peers.containsKey(uid)) return;

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
      await _ws?.close();
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
    _ws?.close();

    for (final peer in _peers.values) {
      peer.pc?.close();
      peer.renderer.dispose();
    }

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
      body: Column(
        children: [
          // 🌐 GridView hiển thị local + all remote peers
          Expanded(
            child: _buildVideoGrid(),
          ),

          const SizedBox(height: 8),
          Row(
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
                icon: Icon(camEnabled ? Icons.videocam : Icons.videocam_off),
                onPressed: () {
                  setState(() => camEnabled = !camEnabled);
                  final enabled = camEnabled;
                  _localStream?.getVideoTracks().forEach((t) {
                    t.enabled = enabled;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red),
                onPressed: _leave,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // 🌐 Build grid layout cho tất cả participants
  Widget _buildVideoGrid() {
    final totalParticipants = 1 + _peers.length;

    // Tính số cột dựa vào số người
    int crossAxisCount;
    if (totalParticipants == 1) {
      crossAxisCount = 1;
    } else if (totalParticipants == 2) {
      crossAxisCount = 2;
    } else if (totalParticipants <= 4) {
      crossAxisCount = 2;
    } else if (totalParticipants <= 9) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: totalParticipants,
      itemBuilder: (context, index) {
        if (index == 0) {
          // First tile = local video
          return _buildLocalVideoTile();
        } else {
          // Remote peers
          final peersList = _peers.values.toList();
          final peer = peersList[index - 1];
          return _buildRemoteVideoTile(peer);
        }
      },
    );
  }

  // 🌐 Local video tile
  Widget _buildLocalVideoTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.purple, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Video hoặc audio-only placeholder
          if (_localStream == null)
            Center(
              child: Text(
                'Đang bật camera...',
                style: TextStyle(color: Colors.white),
              ),
            )
          else if (_isAudioOnlyMode)
            _buildAudioOnlyPlaceholder('You', Icons.mic)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: RTCVideoView(_localRenderer, mirror: true),
            ),

          // Label
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
                'You (Local)',
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

  // 🌐 Remote peer video tile
  Widget _buildRemoteVideoTile(PeerInfo peer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Video hoặc avatar placeholder
          if (peer.renderer.srcObject != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: RTCVideoView(peer.renderer),
            )
          else
            _buildRemoteAvatar(peer.name),

          // Label
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
                peer.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

  Widget _buildRemoteAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(
              initial,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '🔊 Connecting...',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // 🎤 Widget cho audio-only mode (local)
  Widget _buildAudioOnlyPlaceholder(String label, IconData icon) {
    return Container(
      color: Colors.blueGrey[800],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '🎤 Audio Only Mode',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
