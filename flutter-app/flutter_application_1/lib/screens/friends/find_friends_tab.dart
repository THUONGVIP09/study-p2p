import 'package:flutter/material.dart';

class FindFriendsTab extends StatefulWidget {
  const FindFriendsTab({super.key});

  @override
  State<FindFriendsTab> createState() => _FindFriendsTabState();
}

class _FindFriendsTabState extends State<FindFriendsTab> {
  final TextEditingController searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> dummyUsers = [
    {"id": 301, "name": "Linda"},
    {"id": 302, "name": "Mark"},
    {"id": 303, "name": "Oscar"},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: "Search users...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              // TODO: Filter or call API
            },
          ),
        ),

        // List users
        Expanded(
          child: ListView.builder(
            itemCount: dummyUsers.length,
            itemBuilder: (context, index) {
              final user = dummyUsers[index];
              return ListTile(
                leading: CircleAvatar(child: Text(user["name"][0])),
                title: Text(user["name"]),
                trailing: ElevatedButton(
                  child: Text("Add"),
                  onPressed: () {
                    // TODO: send friend request
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
