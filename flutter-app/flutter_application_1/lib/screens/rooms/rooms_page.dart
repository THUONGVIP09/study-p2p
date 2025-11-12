import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/room.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});
  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final api = ApiService();
  late Future<List<Room>> futureRooms;
  String q = '';

  @override
  void initState() {
    super.initState();
    futureRooms = api.fetchRooms();
  }

  void _search(String v) {
    setState(() {
      q = v;
      futureRooms = api.fetchRooms(q: v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm room theo code/title...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Room>>(
              future: futureRooms,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Lỗi: ${snap.error}'));
                }
                final data = snap.data ?? [];
                if (data.isEmpty) {
                  return const Center(child: Text('Không có room nào'));
                }
                return ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = data[i];
                    return ListTile(
                      leading: Icon(r.isGroup ? Icons.groups : Icons.person),
                      title: Text(r.title),
                      subtitle: Text('${r.roomCode} • ${r.visibility}'),
                      onTap: () {
                        // TODO: chuyển sang màn hình call/group-call sau
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Chọn room: ${r.roomCode}')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: tạo room mới (sau này)
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
