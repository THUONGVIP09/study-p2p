import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/signaling_service.dart';
import '../../services/rtc_service.dart';

class RoomLobbyPage extends StatefulWidget {
  final String roomCode;
  const RoomLobbyPage({super.key, required this.roomCode});

  @override
  State<RoomLobbyPage> createState() => _RoomLobbyPageState();
}

class _RoomLobbyPageState extends State<RoomLobbyPage> {
  final sig = SignalingService();
  final rtc = RtcService();

  late final String myUid;
  final nameCtrl = TextEditingController(text: 'Guest');

  bool mediaReady = false;

  @override
  void initState() {
    super.initState();

    myUid = 'u${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    sig.onChanged = () => setState(() {});

    // init renderer (không await trong initState)
    Future.microtask(() async {
      await rtc.init();
    });

    // gắn callback signaling cho WebRTC
    sig.onOffer  = _onOffer;
    sig.onAnswer = _onAnswer;
    sig.onIce    = _onIce;
  }

  @override
  void dispose() {
    sig.leave();
    rtc.dispose(); // không await trong dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Room ${widget.roomCode}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Join / Leave
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    sig.join(
                      roomCode: widget.roomCode,
                      name: nameCtrl.text.trim(),
                      myUid: myUid,
                    );
                  },
                  child: const Text('Join'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: sig.leave,
                  child: const Text('Leave'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ---- Trạng thái
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Status: ${sig.status}  •  Me: $myUid',
                  style: const TextStyle(fontSize: 12)),
            ),

            const SizedBox(height: 12),

            // ---- Media controls
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await rtc.openLocal();
                    setState(() => mediaReady = true);
                  },
                  child: const Text('Enable Camera/Mic'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (!mediaReady || sig.peers.isEmpty) ? null : _callAll,
                  child: const Text('Start Call'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ---- Preview local + 1 remote (demo)
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                      ),
                      child: RTCVideoView(rtc.localRenderer, mirror: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(builder: (_) {
                      if (sig.peers.isEmpty) {
                        return const Center(child: Text('Remote sẽ hiện ở đây'));
                      }
                      final firstUid = sig.peers.keys.first;
                      return FutureBuilder<RTCVideoRenderer>(
                        future: rtc.remoteRenderer(firstUid),
                        builder: (_, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                            ),
                            child: RTCVideoView(snap.data!),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // ---- Peers list
            Text('Peers online (${sig.peers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (sig.peers.isEmpty)
              const Text('Chưa có ai khác trong phòng. Bạn đã join rồi nha.'),
            Expanded(
              child: ListView(
                children: sig.peers.entries.map((e) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(e.value),
                  subtitle: Text(e.key),
                  trailing: ElevatedButton(
                    onPressed: !mediaReady ? null : () => _callPeer(e.key),
                    child: const Text('Call'),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== WebRTC logic ==================

  Future<void> _callAll() async {
    for (final uid in sig.peers.keys) {
      await _callPeer(uid);
    }
  }

  Future<void> _callPeer(String peerUid) async {
    final pc = await rtc.ensurePc(
      peerUid,
      onLocalIce: (c) => sig.sendIce(peerUid, c.toMap(), myUid),
      onRemoteStream: (stream) async {
        final r = await rtc.remoteRenderer(peerUid);
        r.srcObject = stream;
        setState(() {});
      },
    );

    final offer = await pc.createOffer({'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1});
    await pc.setLocalDescription(offer);
    sig.sendOffer(peerUid, offer.toMap(), myUid);
  }

  Future<void> _onOffer(String fromUid, Map<String, dynamic> sdp) async {
    final pc = await rtc.ensurePc(
      fromUid,
      onLocalIce: (c) => sig.sendIce(fromUid, c.toMap(), myUid),
      onRemoteStream: (stream) async {
        final r = await rtc.remoteRenderer(fromUid);
        r.srcObject = stream;
        setState(() {});
      },
    );

    await pc.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
    final answer = await pc.createAnswer({'offerToReceiveVideo': 1, 'offerToReceiveAudio': 1});
    await pc.setLocalDescription(answer);
    sig.sendAnswer(fromUid, answer.toMap(), myUid);
  }

  Future<void> _onAnswer(String fromUid, Map<String, dynamic> sdp) async {
    final pc = await rtc.ensurePc(
      fromUid,
      onLocalIce: (c) => sig.sendIce(fromUid, c.toMap(), myUid),
      onRemoteStream: (_) {},
    );
    await pc.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
  }

  Future<void> _onIce(String fromUid, Map<String, dynamic> cand) async {
    final pc = await rtc.ensurePc(
      fromUid,
      onLocalIce: (_) {},
      onRemoteStream: (_) {},
    );
    await pc.addCandidate(RTCIceCandidate(
      cand['candidate'],
      cand['sdpMid'],
      cand['sdpMLineIndex'],
    ));
  }
}
