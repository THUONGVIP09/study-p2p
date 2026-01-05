import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC P2P Chat - Direct peer-to-peer messaging cho web
/// Server CHỈ dùng để signaling (offer/answer/ice), KHÔNG relay chat
class WebRTCP2PChat {
  final String myUid;
  final Function(Map<String, dynamic>)
      sendSignal; // Callback để gửi signaling qua WebSocket
  final Function(String peerId, Map<String, dynamic> message)?
      onMessageReceived;

  // Map peer connections
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};

  WebRTCP2PChat({
    required this.myUid,
    required this.sendSignal,
    this.onMessageReceived,
  });

  /// Create a peer connection and set basic handlers (no offer/datachannel).
  Future<RTCPeerConnection> _createPeerConnectionForPeer(String peerId) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    });

    // Handle ICE candidates
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        debugPrint('🧊 Sending ICE candidate to $peerId');
        sendSignal({
          't': 'webrtc.ice',
          'targetUid': peerId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    // Handle incoming data channel (when remote creates channel)
    pc.onDataChannel = (channel) {
      debugPrint('📨 Received data channel from $peerId');
      _setupDataChannel(peerId, channel);
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  /// Init peer connection cho 1 peer cụ thể
  Future<void> initPeerConnection(String peerId) async {
    if (!kIsWeb) {
      debugPrint('⚠️ WebRTC P2P chat only for web');
      return;
    }

    if (_peerConnections.containsKey(peerId)) {
      debugPrint('⚠️ Peer connection already exists: $peerId');
      return;
    }

    try {
      debugPrint('🔗 Creating WebRTC connection to $peerId');
      final pc = await _createPeerConnectionForPeer(peerId);
      // As the initiator, create data channel and send offer
      await _createAndSendOffer(peerId, pc);
    } catch (e) {
      debugPrint('❌ Failed to init peer connection: $e');
    }
  }

  /// Tạo và gửi offer cho peer
  Future<void> _createAndSendOffer(String peerId, RTCPeerConnection pc) async {
    try {
      // Create data channel trước khi tạo offer
      final dataChannel = await pc.createDataChannel(
        'chat',
        RTCDataChannelInit()..id = 0,
      );
      _setupDataChannel(peerId, dataChannel);

      // Create offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      debugPrint('📤 Sending offer to $peerId');
      sendSignal({
        't': 'webrtc.offer',
        'targetUid': peerId,
        'sdp': offer.sdp,
      });
    } catch (e) {
      debugPrint('❌ Failed to create offer: $e');
    }
  }

  /// Setup data channel listeners
  void _setupDataChannel(String peerId, RTCDataChannel channel) {
    _dataChannels[peerId] = channel;

    channel.onMessage = (message) {
      try {
        final data = jsonDecode(message.text) as Map<String, dynamic>;
        debugPrint('📨 Received P2P message from $peerId: ${data['text']}');
        onMessageReceived?.call(peerId, data);
      } catch (e) {
        debugPrint('❌ Failed to parse message: $e');
      }
    };

    channel.onDataChannelState = (RTCDataChannelState state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        debugPrint('✅ Data channel opened with $peerId');
        debugPrint('🟢 Ready to send P2P messages to $peerId');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        debugPrint('🔌 Data channel closed with $peerId');
      } else {
        debugPrint('🔄 Data channel state for $peerId: $state');
      }
    };
  }

  /// Handle incoming offer từ peer
  Future<void> handleOffer(String fromUid, String sdp) async {
    try {
      debugPrint('📥 Received offer from $fromUid');

      var pc = _peerConnections[fromUid];
      if (pc == null) {
        debugPrint('⚠️ No peer connection for $fromUid, creating...');
        pc = await _createPeerConnectionForPeer(fromUid);
      }

      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

      // Create answer
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      debugPrint('📤 Sending answer to $fromUid');
      sendSignal({
        't': 'webrtc.answer',
        'targetUid': fromUid,
        'sdp': answer.sdp,
      });

      // Add pending ICE candidates
      final pending = _pendingCandidates[fromUid];
      if (pending != null) {
        for (final candidate in pending) {
          await pc.addCandidate(candidate);
        }
        _pendingCandidates.remove(fromUid);
      }
    } catch (e) {
      debugPrint('❌ Failed to handle offer: $e');
    }
  }

  /// Handle incoming answer từ peer
  Future<void> handleAnswer(String fromUid, String sdp) async {
    try {
      debugPrint('📥 Received answer from $fromUid');

      final pc = _peerConnections[fromUid];
      if (pc == null) {
        debugPrint('⚠️ No peer connection for $fromUid');
        return;
      }

      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));

      // Add pending ICE candidates
      final pending = _pendingCandidates[fromUid];
      if (pending != null) {
        for (final candidate in pending) {
          await pc.addCandidate(candidate);
        }
        _pendingCandidates.remove(fromUid);
      }
    } catch (e) {
      debugPrint('❌ Failed to handle answer: $e');
    }
  }

  /// Handle incoming ICE candidate từ peer
  Future<void> handleIceCandidate(
    String fromUid,
    String candidate,
    String? sdpMid,
    int sdpMLineIndex,
  ) async {
    try {
      debugPrint('🧊 Received ICE candidate from $fromUid');

      final pc = _peerConnections[fromUid];
      if (pc == null) {
        debugPrint('⚠️ No peer connection, queueing candidate');
        _pendingCandidates.putIfAbsent(fromUid, () => []).add(
              RTCIceCandidate(candidate, sdpMid ?? '', sdpMLineIndex),
            );
        return;
      }

      final iceCandidate = RTCIceCandidate(
        candidate,
        sdpMid ?? '',
        sdpMLineIndex,
      );

      // Try to add candidate; if it fails (remote desc not ready), queue it.
      try {
        await pc.addCandidate(iceCandidate);
      } catch (e) {
        _pendingCandidates.putIfAbsent(fromUid, () => []).add(iceCandidate);
      }
    } catch (e) {
      debugPrint('❌ Failed to add ICE candidate: $e');
    }
  }

  /// Gửi tin nhắn P2P đến 1 peer cụ thể
  Future<bool> sendToPeer(String peerId, Map<String, dynamic> message) async {
    try {
      final channel = _dataChannels[peerId];
      if (channel == null ||
          channel.state != RTCDataChannelState.RTCDataChannelOpen) {
        debugPrint('⚠️ Data channel not ready for $peerId');
        return false;
      }

      final json = jsonEncode(message);
      channel.send(RTCDataChannelMessage(json));
      debugPrint('✅ Sent P2P message to $peerId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send to $peerId: $e');
      return false;
    }
  }

  /// Broadcast tin nhắn đến tất cả peers
  Future<void> broadcast(Map<String, dynamic> message) async {
    for (final peerId in _dataChannels.keys) {
      await sendToPeer(peerId, message);
    }
  }

  /// Cleanup connection với 1 peer
  Future<void> closePeer(String peerId) async {
    try {
      await _dataChannels[peerId]?.close();
      await _peerConnections[peerId]?.close();
      _dataChannels.remove(peerId);
      _peerConnections.remove(peerId);
      _pendingCandidates.remove(peerId);
      debugPrint('🔌 Closed connection to $peerId');
    } catch (e) {
      debugPrint('❌ Error closing peer: $e');
    }
  }

  /// Cleanup all connections
  Future<void> dispose() async {
    for (final peerId in _peerConnections.keys.toList()) {
      await closePeer(peerId);
    }
    debugPrint('🛑 WebRTC P2P Chat disposed');
  }
}
