import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import '../../services/CallService.dart';
import '../../services/api_service.dart';
import '../../services/join_approval_service.dart';
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
  JoinApprovalService? _approvalService;

  List<Room> _rooms = [];
  List<Room> _myRooms = [];
  bool _loading = true;
  int? _userId;

  // Pending join requests for host
  final Map<String, List<Map<String, dynamic>>> _pendingRequests = {};

  @override
  void initState() {
    super.initState();
    _loadUserIdAndRooms();
    _initApprovalService();
  }

  void _initApprovalService() async {
    final userId = await ApiService.getUserId();
    if (userId == null) return;

    _approvalService = JoinApprovalService();

    // Lắng nghe stream trước
    _approvalService!.approvalStream.listen((msg) {
      if (msg['t'] == 'join_request') {
        _handleJoinRequest(msg);
      }
    });

    // Chờ load rooms xong rồi mới connect
    // (sẽ gọi ở _loadRooms sau khi có _myRooms)
  }

  void _handleJoinRequest(Map<String, dynamic> msg) {
    final roomCode = msg['room'] as String;
    final requestId = msg['requestId'] as String;
    final uid = msg['uid'] as String;
    final name = msg['name'] as String;

    setState(() {
      _pendingRequests[roomCode] = _pendingRequests[roomCode] ?? [];
      _pendingRequests[roomCode]!.add({
        'requestId': requestId,
        'uid': uid,
        'name': name,
      });
    });

    // Show notification
    _showJoinRequestDialog(roomCode, requestId, name);
  }

  void _showJoinRequestDialog(
      String roomCode, String requestId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yêu cầu vào phòng'),
        content: Text('$userName muốn vào phòng $roomCode'),
        actions: [
          TextButton(
            onPressed: () {
              _approvalService?.rejectRequest(requestId, roomCode);
              setState(() {
                _pendingRequests[roomCode]
                    ?.removeWhere((r) => r['requestId'] == requestId);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã từ chối $userName')),
              );
            },
            child: const Text('Từ chối'),
          ),
          ElevatedButton(
            onPressed: () {
              _approvalService?.approveRequest(requestId, roomCode);
              setState(() {
                _pendingRequests[roomCode]
                    ?.removeWhere((r) => r['requestId'] == requestId);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã chấp nhận $userName')),
              );
            },
            child: const Text('Chấp nhận'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _approvalService?.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndRooms() async {
    try {
      // Lấy userId từ SharedPreferences
      final userId = await ApiService.getUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Chưa đăng nhập. Vui lòng đăng nhập lại.')),
          );
        }
        return;
      }

      setState(() {
        _userId = userId;
      });

      await _loadRooms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo: $e')),
        );
      }
    }
  }

  Future<void> _loadRooms() async {
    try {
      setState(() => _loading = true);

      // Lấy tất cả phòng từ backend
      final rooms = await _roomService.getAllRooms();
      // Backend chưa có /api/rooms/mine -> lọc client theo createdBy
      final myRooms = _userId == null
          ? <Room>[]
          : rooms.where((r) => r.createdBy == _userId).toList();

      setState(() {
        _rooms = rooms;
        _myRooms = myRooms;
        _loading = false;
      });

      // Host tự động connect WebSocket để nhận join requests cho các phòng của mình
      // Duplicate peer sẽ được filter ở P2PCallPage
      _connectHostToMyRooms();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi load rooms: $e')),
        );
      }
    }
  }

  Future<void> _connectHostToMyRooms() async {
    if (_userId == null || _myRooms.isEmpty || _approvalService == null) {
      return;
    }

    final firstRoom = _myRooms.first;

    try {
      // Connect WebSocket và join vào phòng đầu tiên
      await _approvalService!.connect(
        roomCode: firstRoom.roomCode,
        userId: _userId!,
        uid: 'host_${_userId}_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Host $_userId',
      );

      print(
          'Host connected to WebSocket and joined room ${firstRoom.roomCode}');

      // Join vào các phòng còn lại (nếu có)
      for (int i = 1; i < _myRooms.length; i++) {
        final room = _myRooms[i];
        _approvalService!.joinRoom(
          roomCode: room.roomCode,
          uid:
              'host_${_userId}_${room.id}_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Host $_userId',
          userId: _userId!,
        );
        print('Host joined additional room ${room.roomCode}');
      }
    } catch (e) {
      print('Error connecting host to WebSocket: $e');
    }
  }

  Future<void> _showCreateRoomDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String visibility = 'PUBLIC';
    int? maxParticipants;
    final passcodeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Tạo phòng mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên phòng'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: visibility,
                      items: const [
                        DropdownMenuItem(
                            value: 'PUBLIC', child: Text('Public')),
                        DropdownMenuItem(
                            value: 'PRIVATE', child: Text('Private')),
                        DropdownMenuItem(
                            value: 'PROTECTED', child: Text('Protected')),
                      ],
                      onChanged: (v) {
                        setStateDialog(() {
                          visibility = v ?? 'PUBLIC';
                        });
                      },
                      decoration:
                          const InputDecoration(labelText: 'Visibility'),
                    ),
                    const SizedBox(height: 8),
                    if (visibility == 'PRIVATE')
                      TextField(
                        controller: passcodeController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Passcode (bắt buộc với PRIVATE)',
                        ),
                      ),
                    if (visibility == 'PRIVATE') const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Max participants (tuỳ chọn)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        maxParticipants = int.tryParse(v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Tên phòng không được trống')),
                      );
                      return;
                    }
                    if (visibility == 'PRIVATE' &&
                        passcodeController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Phòng PRIVATE cần passcode')),
                      );
                      return;
                    }
                    try {
                      final room = await ApiService.createRoom(
                        name: nameController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        visibility: visibility,
                        passcode: visibility == 'PRIVATE'
                            ? passcodeController.text.trim()
                            : null,
                        maxParticipants: maxParticipants,
                      );
                      setState(() {
                        _myRooms = [room, ..._myRooms];
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tạo phòng thành công')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tạo phòng thất bại: $e')),
                      );
                    }
                  },
                  child: const Text('Tạo phòng'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRoom(Room room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá phòng'),
        content: Text('Bạn có chắc muốn xoá "${room.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteRoom(roomId: room.id);
      setState(() {
        _myRooms.removeWhere((r) => r.id == room.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá phòng')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xoá phòng thất bại: $e')),
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
      // Kiểm tra visibility và xác thực qua API
      String? passcode;
      if (room.visibility == 'PRIVATE') {
        // Chủ phòng không cần nhập passcode
        if (room.createdBy != _userId) {
          passcode = await _askPasscode();
          if (passcode == null || passcode.isEmpty) {
            return; // Huỷ
          }
          // Xác thực passcode với backend
          try {
            await ApiService.joinRoomByCode(
              roomCode: room.roomCode,
              passcode: passcode,
              userId: _userId,
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Passcode không đúng: $e')),
            );
            return;
          }
        }
        // Chủ phòng tự động được phép vào
      } else if (room.visibility == 'PROTECTED') {
        // Kiểm tra nếu là chủ phòng thì skip approval flow
        if (room.createdBy != _userId) {
          // Gọi API để yêu cầu join
          try {
            await ApiService.joinRoomByCode(
              roomCode: room.roomCode,
              userId: _userId,
            );
            // Backend trả PENDING_APPROVAL, hiển thị UI chờ
            final approved = await _requestJoinApproval(room);
            if (approved != true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chưa được chủ phòng duyệt vào')),
              );
              return;
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi join phòng PROTECTED: $e')),
            );
            return;
          }
        }
      }

      // Pre-join config (mic/cam, preview)
      final prejoin = await _showPrejoinConfig();
      if (prejoin == null) {
        return; // user canceled
      }
      final micMuted = prejoin['micMuted'] as bool;
      final camEnabled = prejoin['camEnabled'] as bool;
      final displayName = prejoin['displayName'] as String?;

      // 1. Lấy session mới nhất cho room
      CallSession? latest = await _callService.getLatestForRoom(room.id);

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
        micMuted: micMuted,
        camEnabled: camEnabled,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => P2PCallPage(
            room: room,
            callSession: session, // session bro đã lấy bằng CallService
            currentUserId: _userId!,
            initialMicMuted: micMuted,
            initialCamEnabled: camEnabled,
            displayName: displayName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không join call được: $e')),
      );
    }
  }

  Future<String?> _askPasscode() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập passcode'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Passcode phòng PRIVATE'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Huỷ')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Xác nhận')),
        ],
      ),
    );
  }

  Future<bool?> _requestJoinApproval(Room room) async {
    // Kết nối WS và gửi join_request
    final service = JoinApprovalService();
    final uid = '${_userId}_${DateTime.now().millisecondsSinceEpoch}';

    await service.connect(
      roomCode: room.roomCode,
      userId: _userId!,
      uid: uid,
      name: 'User $_userId',
    );

    final completer = Completer<bool>();
    bool dialogClosed = false; // Track xem dialog đã bị đóng chưa

    // Lắng nghe phản hồi
    final subscription = service.approvalStream.listen((msg) {
      if (msg['t'] == 'join_approved') {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      } else if (msg['t'] == 'join_rejected') {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
    });

    // Gửi request
    service.requestJoin(room.roomCode);

    // Hiện dialog chờ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Chờ chủ phòng duyệt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Đang chờ chủ phòng "${room.name}" phê duyệt...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!completer.isCompleted) {
                completer.complete(false);
              }
              dialogClosed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Huỷ'),
          ),
        ],
      ),
    );

    final result = await completer.future;
    subscription.cancel();
    service.dispose();

    // Đóng dialog chờ nếu chưa bị đóng (approved/rejected từ host)
    if (mounted && !dialogClosed) {
      Navigator.pop(context);
    }
    return result;
  }

  Future<Map<String, dynamic>?> _showPrejoinConfig() async {
    bool micMuted = false;
    bool camEnabled = true;
    final nameController = TextEditingController();
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Chuẩn bị vào phòng'),
          content: StatefulBuilder(
            builder: (ctx, setStateSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị (tuỳ chọn)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Switch(
                        value: !micMuted,
                        onChanged: (v) {
                          setStateSB(() => micMuted = !v);
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('Mic bật')
                    ],
                  ),
                  Row(
                    children: [
                      Switch(
                        value: camEnabled,
                        onChanged: (v) {
                          setStateSB(() => camEnabled = v);
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('Camera bật')
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'micMuted': micMuted,
                  'camEnabled': camEnabled,
                  'displayName': nameController.text.trim().isEmpty
                      ? null
                      : nameController.text.trim(),
                });
              },
              child: const Text('Vào phòng'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phòng học')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Phòng học'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Tất cả phòng'),
            Tab(text: 'Phòng của tôi'),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRooms,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildRoomsList(_rooms, showManage: false),
            _buildMyRoomsTab(),
          ],
        ),
        // FAB đã bỏ, dùng nút lớn tuỳ chỉnh bên trong tab
      ),
    );
  }

  Widget _buildMyRoomsTab() {
    // Khi chưa có phòng nào -> nút tạo phòng ở giữa, to rõ ràng
    if (_myRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.meeting_room, size: 72, color: Colors.blueGrey),
            const SizedBox(height: 16),
            const Text(
              'Bạn chưa tạo phòng nào',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Tạo phòng mới',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      );
    }

    // Có phòng: danh sách + nút tạo phòng lớn cố định dưới center
    return Stack(
      children: [
        _buildRoomsList(_myRooms, showManage: true),
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Center(
            child: ElevatedButton.icon(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add_circle_outline, size: 30),
              label: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  'Tạo phòng',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomsList(List<Room> rooms, {required bool showManage}) {
    if (rooms.isEmpty) {
      return const Center(child: Text('Chưa có phòng nào'));
    }
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Row(
              children: [
                Expanded(child: Text(room.name)),
                _buildVisibilityBadge(room.visibility),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mã phòng: ${room.roomCode}'),
                const SizedBox(height: 4),
                FutureBuilder<CallSession?>(
                  future: _callService.getLatestForRoom(room.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Đang lấy số người trong phòng...');
                    }
                    if (snapshot.hasError) {
                      return const Text('Không lấy được số người');
                    }
                    final latest = snapshot.data;
                    final count = latest?.liveCount ?? 0;
                    return Text('Đang có: $count người');
                  },
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: () => _joinCall(room),
                  tooltip: 'Vào phòng',
                ),
                if (showManage)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRoom(room),
                    tooltip: 'Xoá phòng',
                  ),
              ],
            ),
            onTap: () => _joinCall(room),
          ),
        );
      },
    );
  }

  Widget _buildVisibilityBadge(String visibility) {
    Color bgColor;
    IconData icon;
    String label;

    switch (visibility) {
      case 'PUBLIC':
        bgColor = Colors.green;
        icon = Icons.public;
        label = 'PUBLIC';
        break;
      case 'PRIVATE':
        bgColor = Colors.orange;
        icon = Icons.lock;
        label = 'PRIVATE';
        break;
      case 'PROTECTED':
        bgColor = Colors.blue;
        icon = Icons.shield;
        label = 'PROTECTED';
        break;
      default:
        bgColor = Colors.grey;
        icon = Icons.help_outline;
        label = visibility;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: bgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: bgColor,
            ),
          ),
        ],
      ),
    );
  }
}
