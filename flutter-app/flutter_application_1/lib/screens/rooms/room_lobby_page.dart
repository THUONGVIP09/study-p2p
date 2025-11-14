import 'dart:math';
import 'package:flutter/material.dart';
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
    myUid = 'u${Random().nextInt(1 << 32)}';
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
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    sig.join(
                      roomCode: widget.roomCode,
                      name: nameCtrl.text.trim(),
                      myUid: myUid,
                    );
                    setState(() {});
                  },
                  child: const Text('Join room'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: sig.leave,
                  child: const Text('Leave'),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Online (${sig.peers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
