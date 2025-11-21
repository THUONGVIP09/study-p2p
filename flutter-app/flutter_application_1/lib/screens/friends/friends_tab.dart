import 'package:flutter/material.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final TextEditingController searchCtrl = TextEditingController();

  // Dummy data
  List<Map<String, dynamic>> dummyFriends = [
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"},
    {"id": 3, "name": "Chloe"},
    {"id": 4, "name": "David"},
    {"id": 5, "name": "Eva"},
  ];

  List<Map<String, dynamic>> filteredFriends = [];

  @override
  void initState() {
    super.initState();
    filteredFriends = dummyFriends;
  }

  void filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredFriends = dummyFriends;
      } else {
        filteredFriends = dummyFriends
            .where((f) => f["name"].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

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
              hintText: "Search friends...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: filterFriends,
          ),
        ),

        // List friends
        Expanded(
          child: ListView.builder(
            itemCount: filteredFriends.length,
            itemBuilder: (context, index) {
              final user = filteredFriends[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(child: Text(user["name"][0])),
                      const SizedBox(width: 12),

                      // Name
                      Expanded(
                        child: Text(
                          user["name"],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),

                      // Buttons
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // TODO: Chat
                            },
                            child: const Text("Chat"),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: () {
                              // TODO: Unfriend
                            },
                            child: const Text("Unfriend"),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: () {
                              // TODO: Block User
                            },
                            child: const Text("Block User"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
