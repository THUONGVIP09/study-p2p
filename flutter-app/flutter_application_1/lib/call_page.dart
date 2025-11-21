import 'dart:async';

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../models/room.dart';
import '../models/call_session.dart';
import '../services/CallService.dart';

// TODO: thay bằng App ID thật của bro (đang dùng luôn appId cũ)
const String agoraAppId = '2f5b8d4ac95e41168548190bea8a2141';
const String agoraToken = ''; // App ID only -> để rỗng / null

class GroupCallPage extends StatefulWidget {
  final Room room;
  final CallSession callSession;
  final int currentUserId;

  const GroupCallPage({
    super.key,
    required this.room,
    required this.callSession,
    required this.currentUserId,
  });

  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage> {
  RtcEngine? _engine;
  final CallService _callService = const CallService();

  bool _joined = false;
  int? _remoteUid;
  bool micMuted = false;
  bool camEnabled = true;

  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _startHeartbeat();
  }

  Future<void> _initAgora() async {
    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      await engine.enableVideo();
      await engine.startPreview();

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onError: (err, msg) {
            // debug
            // ignore: avoid_print
            print('AGORA ERROR: $err $msg');
          },
          onJoinChannelSuccess: (connection, elapsed) {
            // ignore: avoid_print
            print('JOIN OK: ${connection.channelId}');
            if (mounted) {
              setState(() => _joined = true);
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            // ignore: avoid_print
            print('REMOTE JOIN: $remoteUid');
            if (mounted) {
              setState(() => _remoteUid = remoteUid);
            }
          },
          onUserOffline: (connection, remoteUid, reason) {
            // ignore: avoid_print
            print('REMOTE OFFLINE: $remoteUid');
            if (mounted) {
              setState(() => _remoteUid = null);
            }
          },
        ),
      );

      await engine.joinChannel(
        token: agoraToken.isEmpty ? '' : agoraToken,
        channelId: widget.room.roomCode, // dùng mã phòng làm channel
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('INIT AGORA FAILED: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        await _callService.heartbeat(
          callId: widget.callSession.id,
          userId: widget.currentUserId,
          micMuted: micMuted,
          camEnabled: camEnabled,
        );
      } catch (e) {
        // có thể log nếu cần
        // debugPrint('heartbeat error: $e');
      }
    });
  }

  Future<void> _leaveCall() async {
    try {
      await _callService.leave(
        callId: widget.callSession.id,
        userId: widget.currentUserId,
      );
    } catch (e) {
      // ignore lỗi nhỏ
    }

    final engine = _engine;
    if (engine != null) {
      await engine.leaveChannel();
      await engine.release();
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    final engine = _engine;
    if (engine != null) {
      engine.leaveChannel();
      engine.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCEBFF),
      appBar: AppBar(
        title: Text('Group Call: ${widget.room.name}'),
        backgroundColor: Colors.purple[100],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _joined && _engine != null
                  ? AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    )
                  : const Text('Đang join channel...'),
            ),
          ),
          Expanded(
            child: Center(
              child: _remoteUid != null && _engine != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine!,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: RtcConnection(
                          channelId: widget.room.roomCode,
                        ),
                      ),
                    )
                  : const Text('Chờ người khác join...'),
            ),
          ),
          const SizedBox(height: 12),
          _buildControls(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final engine = _engine;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(micMuted ? Icons.mic_off : Icons.mic),
          onPressed: engine == null
              ? null
              : () {
                  setState(() => micMuted = !micMuted);
                  engine.muteLocalAudioStream(micMuted);
                },
        ),
        IconButton(
          icon: Icon(camEnabled ? Icons.videocam : Icons.videocam_off),
          onPressed: engine == null
              ? null
              : () {
                  setState(() => camEnabled = !camEnabled);
                  engine.muteLocalVideoStream(!camEnabled);
                },
        ),
        IconButton(
          icon: const Icon(Icons.call_end, color: Colors.red),
          onPressed: _leaveCall,
        ),
      ],
    );
  }
}
