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

class _P2PCallPageState extends State<P2PCallPage> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _remoteJoined = false;
String? _remoteName;


  MediaStream? _localStream;
  RTCPeerConnection? _pc;

  WebSocket? _ws;
  late final String _myUid;
  String? _remoteUid;

  bool micMuted = false;
  bool camEnabled = true;

  @override
  void initState() {
    super.initState();
    _myUid = '${widget.currentUserId}-${DateTime.now().microsecondsSinceEpoch}';
    _initAll();
  }

  Future<void> _initAll() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // Luôn bật local trước
    await _startLocalStream();

    // Sau đó connect WS
    await _connectWs();
  }

  // ================== MEDIA ==================

  Future<void> _startLocalStream({bool allowFailure = false}) async {
  if (_localStream != null) return;

  try {
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
        '🎥 getUserMedia ok v=${stream.getVideoTracks().length} a=${stream.getAudioTracks().length}');

    _localStream = stream;
    _localRenderer.srcObject = stream;
    setState(() {});

    // nếu đã có PC thì add track
    if (_pc != null) {
      debugPrint('➕ addTrack local vào PC (sau getUserMedia)');
      for (final track in stream.getTracks()) {
        await _pc!.addTrack(track, stream);
      }
    }
  } catch (e) {
    debugPrint('⚠️ getUserMedia FAILED: $e');

    // Nếu cho phép fail thì không throw, chỉ không có localStream
    if (allowFailure) {
      _localStream = null;
      _localRenderer.srcObject = null;
      setState(() {});
      return;
    }

    rethrow; // chỗ khác nếu cần vẫn có thể bắt lỗi
  }
}

  Future<void> _createPeerConnectionIfNeeded() async {
  if (_pc != null) return;

  final pc = await createPeerConnection({
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    // 🔥 bật Unified Plan để onTrack hoạt động đúng
    'sdpSemantics': 'unified-plan',
  });

  pc.onIceCandidate = (c) {
    if (c.candidate == null || _remoteUid == null) return;
    debugPrint('❄️ local ICE: ${c.candidate}');
    _send({
      't': 'ice',
      'from': _myUid,
      'to': _remoteUid,
      'candidate': c.candidate,
      'sdpMid': c.sdpMid,
      'sdpMLineIndex': c.sdpMLineIndex,
    });
  };

  // Unified Plan: nhận remote track
  pc.onTrack = (RTCTrackEvent e) {
    if (e.streams.isNotEmpty) {
      debugPrint('📺 onTrack stream=${e.streams[0].id} kind=${e.track.kind}');
      setState(() {
        _remoteRenderer.srcObject = e.streams[0];
      });
    } else {
      debugPrint('📺 onTrack nhưng streams rỗng, kind=${e.track.kind}');
    }
  };

  // fallback Plan-B nếu plugin còn bắn onAddStream
  pc.onAddStream = (MediaStream s) {
    debugPrint('📺 onAddStream stream=${s.id}');
    setState(() {
      _remoteRenderer.srcObject = s;
    });
  };

  pc.onConnectionState = (st) {
    debugPrint('🔗 PC state = $st');
  };

  _pc = pc;

  if (_localStream != null) {
    debugPrint('➕ addTrack local vào PC (lúc tạo PC)');
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
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
      final peers = (m['peers'] as List<dynamic>? ?? []);
      if (peers.isNotEmpty) {
        final first = peers.first as Map<String, dynamic>;
        _remoteUid = first['uid'] as String?;
        _remoteName = first['name'] as String?;
        _remoteJoined = true;                // 🔥 đã có người trong phòng
        setState(() {});
        await _startAsCaller();
      }
      break;

    case 'peer.joined':
      // Trường hợp mình vào trước, người khác vào sau
      _remoteUid = m['uid'] as String?;
      _remoteName = m['name'] as String?;
      _remoteJoined = true;
      setState(() {});
      // Thằng join sau sẽ tự nhận 'peers' và gọi offer, mình chỉ cần chờ offer
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
      _remoteJoined = false;
      _remoteRenderer.srcObject = null;
      setState(() {});
      break;
  }
}


  // ================== OFFER / ANSWER ==================

 Future<void> _startAsCaller() async {
  if (_remoteUid == null) return;

  // ⚠️ Cho phép lỗi cam nhưng vẫn tiếp tục call
  await _startLocalStream(allowFailure: true);
  await _createPeerConnectionIfNeeded();

  final pc = _pc!;
  final offer = await pc.createOffer({
    'offerToReceiveAudio': 1,
    'offerToReceiveVideo': 1,
  });
  await pc.setLocalDescription(offer);

  debugPrint('📤 send OFFER to=$_remoteUid');
  _send({
    't': 'offer',
    'from': _myUid,
    'to': _remoteUid,
    'sdp': offer.sdp,
    'type': offer.type,
  });
}



  Future<void> _handleOffer(Map<String, dynamic> m) async {
  _remoteUid = m['from'] as String?;
  if (_remoteUid == null) return;

  // ⚠️ Cho phép lỗi cam nhưng vẫn nhận remote video
  await _startLocalStream(allowFailure: true);
  await _createPeerConnectionIfNeeded();

  final pc = _pc!;
  final remoteDesc = RTCSessionDescription(
    m['sdp'] as String,
    m['type'] as String,
  );
  debugPrint('📥 setRemoteDescription(offer)');
  await pc.setRemoteDescription(remoteDesc);

  final answer = await pc.createAnswer({
    'offerToReceiveAudio': 1,
    'offerToReceiveVideo': 1,
  });
  await pc.setLocalDescription(answer);

  debugPrint('📤 send ANSWER to=$_remoteUid');
  _send({
    't': 'answer',
    'from': _myUid,
    'to': _remoteUid,
    'sdp': answer.sdp,
    'type': answer.type,
  });
}


  Future<void> _handleAnswer(Map<String, dynamic> m) async {
    final pc = _pc;
    if (pc == null) return;

    final remoteDesc = RTCSessionDescription(
      m['sdp'] as String,
      m['type'] as String,
    );
    debugPrint('📥 setRemoteDescription(answer)');
    await pc.setRemoteDescription(remoteDesc);
  }

  Future<void> _handleIce(Map<String, dynamic> m) async {
    final pc = _pc;
    if (pc == null) return;

    final cand = RTCIceCandidate(
      m['candidate'] as String?,
      m['sdpMid'] as String?,
      m['sdpMLineIndex'] as int?,
    );
    debugPrint('❄️ addCandidate');
    await pc.addCandidate(cand);
  }

  // ================== LEAVE / CLEANUP ==================

  Future<void> _leave() async {
    try {
      _send({'t': 'leave', 'uid': _myUid});
    } catch (_) {}

    try {
      await _ws?.close();
    } catch (_) {}

    try {
      await _pc?.close();
    } catch (_) {}

    if (_localStream != null) {
      for (final t in _localStream!.getTracks()) {
        t.stop();
      }
      await _localStream!.dispose();
    }

    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;

    await _localRenderer.dispose();
    await _remoteRenderer.dispose();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _ws?.close();
    _pc?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCEBFF),
      appBar: AppBar(
        title: Text('P2P Call: ${widget.room.name}'),
        backgroundColor: Colors.purple[100],
      ),
      body: Column(
        children: [
          // local
          Expanded(
            child: Container(
              color: Colors.black,
              child: _localStream == null
                  ? const Center(child: Text('Đang bật camera...'))
                  : RTCVideoView(_localRenderer, mirror: true),
            ),
          ),
          // remote
         Expanded(
  child: Container(
    color: Colors.grey[900],
    child: _remoteRenderer.srcObject != null
        ? RTCVideoView(_remoteRenderer)
        : _remoteJoined
            ? _buildRemoteAvatar()
            : const Center(child: Text('Chờ đối phương join...')),
  ),
  
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

 Widget _buildRemoteAvatar() {
  final name = _remoteName ?? 'Đối phương';
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 36,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Đã tham gia (không bật camera)',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

}
