import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/signaling_service.dart';

class RoomLobbyPage extends StatefulWidget {
  final String roomCode;
  const RoomLobbyPage({super.key, required this.roomCode});

  @override
  State<RoomLobbyPage> createState() => _RoomLobbyPageState();
}

class _RoomLobbyPageState extends State<RoomLobbyPage> {
  final sig = SignalingService();
  late final String myUid;
  final nameCtrl = TextEditingController(text: 'Guest');

  @override
  void initState() {
    super.initState();
    // UID ổn định, không dùng nextInt(0)
    myUid = 'u${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    sig.onChanged = () => setState(() {});
  }

  @override
  void dispose() {
    sig.leave();
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
            // Trạng thái
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Status: ${sig.status}  •  Me: $myUid',
                  style: const TextStyle(fontSize: 12)),
            ),
            const Divider(height: 24),
            Text('Peers online (${sig.peers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (sig.peers.isEmpty)
              const Text('Chưa có ai khác trong phòng. Bạn đã join rồi nha.'),
            Expanded(
              child: ListView(
                children: sig.peers.entries
                    .map((e) => ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(e.value),
                          subtitle: Text(e.key),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
