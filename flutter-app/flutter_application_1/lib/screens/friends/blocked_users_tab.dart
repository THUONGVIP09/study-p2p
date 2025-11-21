import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/friends_service.dart';

class BlockedUsersTab extends StatefulWidget {
  const BlockedUsersTab({super.key});

  @override
  State<BlockedUsersTab> createState() => _BlockedUsersTabState();
}

class _BlockedUsersTabState extends State<BlockedUsersTab> {
  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> blocked = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked({String query = ''}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final res = await FriendsService.getBlockedUsers(q: query);
      setState(() {
        blocked = res;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading blocked users: $e';
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String q) {
    _loadBlocked(query: q);
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
              hintText: "Search blocked...",
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _onSearchChanged,
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
        else if (blocked.isEmpty)
          const Expanded(
            child: Center(
                child: Text('No blocked users',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: blocked.length,
              itemBuilder: (context, index) {
                final user = blocked[index];
                final name = user['displayName'] ?? user['name'] ?? 'Unknown';
                return ListTile(
                  leading: CircleAvatar(child: Text(name[0])),
                  title: Text(name),
                  trailing: TextButton(
                    child: const Text('Unblock'),
                    onPressed: () {
                      // TODO: Unblock user
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Unblock not implemented')));
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
