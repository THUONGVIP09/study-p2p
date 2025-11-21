import 'package:flutter/material.dart';
import '../../services/friends_service.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> filteredFriends = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends({String query = ''}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final friends = await FriendsService.getFriends(q: query);
      setState(() {
        filteredFriends = friends;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading friends: $e';
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _loadFriends(query: query);
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
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // Error message
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),

        // Loading indicator
        if (isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (filteredFriends.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                searchCtrl.text.isEmpty ? "No friends yet" : "No friends found",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          )
        else
          // List friends
          Expanded(
            child: ListView.builder(
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                final user = filteredFriends[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          child: Text(
                            (user['displayName'] ?? 'U')[0].toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name & Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['displayName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                user['email'] ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action button (placeholder)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            // TODO: Implement actions (message, remove friend, block, etc.)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Action: $value')),
                            );
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'message',
                              child: Text('Message'),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove Friend'),
                            ),
                            const PopupMenuItem(
                              value: 'block',
                              child: Text('Block'),
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

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }
}
