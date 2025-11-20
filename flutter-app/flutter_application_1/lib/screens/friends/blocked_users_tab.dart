import 'package:flutter/material.dart';

class BlockedUsersTab extends StatelessWidget {
  const BlockedUsersTab({super.key});

  final List<Map<String, dynamic>> dummyBlocked = const [
    {"id": 201, "name": "Toxic Guy"},
    {"id": 202, "name": "Spammer"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: dummyBlocked.length,
      itemBuilder: (context, index) {
        final user = dummyBlocked[index];
        return ListTile(
          leading: CircleAvatar(child: Text(user["name"][0])),
          title: Text(user["name"]),
          trailing: TextButton(
            child: Text("Unblock"),
            onPressed: () {
              // TODO: Unblock
            },
          ),
        );
      },
    );
  }
}
