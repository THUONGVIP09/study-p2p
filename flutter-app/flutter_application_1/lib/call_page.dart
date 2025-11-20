import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// KHÔNG dùng permission_handler cho web

const String agoraAppId = '2f5b8d4ac95e41168548190bea8a2141';
const String channelName = 'study_room_1';
const String agoraToken = ''; // App ID only thì để rỗng

class GroupCallPage extends StatefulWidget {
  const GroupCallPage({super.key});

  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage> {
  late final RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();

      await _engine.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      await _engine.enableVideo();
      await _engine.startPreview();

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onError: (ErrorCodeType err, String msg) {
            print('AGORA ERROR: $err $msg');
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('JOIN OK: ${connection.channelId}');
            setState(() => _joined = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print('REMOTE JOIN: $remoteUid');
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            print('REMOTE OFFLINE: $remoteUid');
            setState(() => _remoteUid = null);
          },
        ),
      );

      await _engine.joinChannel(
        token: agoraToken.isEmpty ? '' : agoraToken,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      print('INIT AGORA FAILED: $e');
    }
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCEBFF),
      appBar: AppBar(
        title: const Text('Group Call Demo'),
        backgroundColor: Colors.purple[100],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _joined
                  ? AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    )
                  : const Text('Đang join channel...'),
            ),
          ),
          Expanded(
            child: Center(
              child: _remoteUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection:
                            const RtcConnection(channelId: channelName),
                      ),
                    )
                  : const Text('Chờ người khác join...'),
            ),
          ),
        ],
      ),
    );
  }
}
