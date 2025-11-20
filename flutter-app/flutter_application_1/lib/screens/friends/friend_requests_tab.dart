import 'package:flutter/material.dart';

class FriendRequestsTab extends StatelessWidget {
  const FriendRequestsTab({super.key});

  final List<Map<String, dynamic>> dummyRequests = const [
    {"id": 101, "name": "David"},
    {"id": 102, "name": "Eva"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: dummyRequests.length,
      itemBuilder: (context, index) {
        final req = dummyRequests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(req["name"][0])),
            title: Text(req["name"]),
            subtitle: Text("Sent you a friend request"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    // TODO: Accept
                  },
                ),
                IconButton(
                  icon: Icon(Icons.cancel, color: Colors.red),
                  onPressed: () {
                    // TODO: Reject
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
