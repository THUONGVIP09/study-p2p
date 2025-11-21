import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import '../../services/CallService.dart';
import '../../services/api_service.dart';
import '../../models/room.dart';
import '../../models/call_session.dart';
import '../../call_page.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final RoomService _roomService = const RoomService();
  final CallService _callService = const CallService();

  List<Room> _rooms = [];
  bool _loading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final uid = await ApiService.getUserId();
      if (uid == null) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa đăng nhập')),
        );
        return;
      }
      final rooms = await _roomService.getRoomsForUser(uid);
      setState(() {
        _userId = uid;
        _rooms = rooms;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi load rooms: $e')),
      );
    }
  }

  Future<void> _joinCall(Room room) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có userId')),
      );
      return;
    }

    try {
      // 1. Lấy session mới nhất cho room
      CallSession? latest =
          await _callService.getLatestForRoom(room.id);

      late CallSession session;

      // 2. Nếu chưa có call hoặc call cũ đã end → start call mới
      if (latest == null || !latest.isLive) {
        session = await _callService.startCall(
          roomId: room.id,
          userId: _userId!,
          roomCode: room.roomCode, // rất quan trọng
        );
      } else {
        session = latest;
      }

      // 3. Join vào call session (ghi vào call_participants)
      await _callService.joinCall(
        callId: session.id,
        userId: _userId!,
        micMuted: false,
        camEnabled: true,
      );

      if (!mounted) return;

      // 4. Mở màn call Agora
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupCallPage(
            room: room,
            callSession: session,
            currentUserId: _userId!,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không join call được: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phòng học')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng học'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
        ],
      ),
      body: _rooms.isEmpty
          ? const Center(child: Text('Chưa có phòng nào'))
          : ListView.builder(
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(room.name),
                    subtitle: Text(
                        'Mã phòng: ${room.roomCode}  ·  Visibility: ${room.visibility}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.video_call),
                      onPressed: () => _joinCall(room),
                    ),
                    onTap: () => _joinCall(room),
                  ),
                );
              },
            ),
    );
  }
}
