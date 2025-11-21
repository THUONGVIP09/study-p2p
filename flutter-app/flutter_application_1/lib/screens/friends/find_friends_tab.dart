import 'package:flutter/material.dart';
import '../../services/friends_service.dart';

class FindFriendsTab extends StatefulWidget {
  const FindFriendsTab({super.key});

  @override
  State<FindFriendsTab> createState() => _FindFriendsTabState();
}

class _FindFriendsTabState extends State<FindFriendsTab> {
  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        users = [];
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final res = await FriendsService.findFriends(q: q);
      setState(() {
        users = res;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Search error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: "Search users (min 2 chars)...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchCtrl.clear();
                        _search('');
                      },
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => _search(v),
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child:
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        if (isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (users.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                searchCtrl.text.length < 2
                    ? 'Type at least 2 characters'
                    : 'No users found',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final name = user['displayName'] ?? user['name'] ?? 'Unknown';
                return ListTile(
                  leading: CircleAvatar(child: Text(name[0])),
                  title: Text(name),
                  trailing: ElevatedButton(
                    child: const Text('Add'),
                    onPressed: () {
                      // TODO: send friend request
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Send request not implemented')));
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }
}
