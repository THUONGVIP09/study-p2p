import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RtcService {
  final localRenderer = RTCVideoRenderer();
  MediaStream? local;

  final pcs = <String, RTCPeerConnection>{};                 // peerUid -> pc
  final remoteRenderers = <String, RTCVideoRenderer>{};       // peerUid -> view

  final Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };
  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  Future<void> init() async { await localRenderer.initialize(); }

  Future<void> openLocal({int w=640, int h=360, int fps=15}) async {
    final c = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        if (kIsWeb) 'width': {'ideal': w},
        if (kIsWeb) 'height': {'ideal': h},
        if (kIsWeb) 'frameRate': {'ideal': fps},
      }
    };
    local = await navigator.mediaDevices.getUserMedia(c);
    localRenderer.srcObject = local;
  }

  Future<RTCPeerConnection> ensurePc(
    String peerUid, {
      required void Function(RTCIceCandidate) onLocalIce,
      required void Function(MediaStream stream) onRemoteStream,
    }
  ) async {
    if (pcs[peerUid] != null) return pcs[peerUid]!;
    final pc = await createPeerConnection(_config, _constraints);

    // add local tracks
    for (var t in local?.getTracks() ?? []) {
      await pc.addTrack(t, local!);
    }

    pc.onIceCandidate = (c) { if (c.candidate != null) onLocalIce(c); };
    pc.onTrack = (ev) { if (ev.streams.isNotEmpty) onRemoteStream(ev.streams[0]); };

    pcs[peerUid] = pc;
    return pc;
  }

  Future<RTCVideoRenderer> remoteRenderer(String peerUid) async {
    if (remoteRenderers[peerUid] != null) return remoteRenderers[peerUid]!;
    final r = RTCVideoRenderer(); await r.initialize();
    remoteRenderers[peerUid] = r;
    return r;
  }

  Future<void> dispose() async {
    for (final pc in pcs.values) { try { await pc.close(); } catch (_) {} }
    pcs.clear();
    for (final r in remoteRenderers.values) { try { await r.dispose(); } catch (_) {} }
    remoteRenderers.clear();
    try { await local?.dispose(); } catch (_) {}
    try { await localRenderer.dispose(); } catch (_) {}
  }
}
