import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/friends_service.dart';

class FriendRequestsTab extends StatefulWidget {
  const FriendRequestsTab({super.key});

  @override
  State<FriendRequestsTab> createState() => _FriendRequestsTabState();
}

class _FriendRequestsTabState extends State<FriendRequestsTab> {
  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> requests = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests({String query = ''}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final res = await FriendsService.getFriendRequests(q: query);
      setState(() {
        requests = res;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading requests: $e';
        isLoading = false;
      });
    }
  }

  void _onSearchChanged(String q) {
    _loadRequests(query: q);
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
              hintText: "Search requests...",
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
        else if (requests.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                searchCtrl.text.isEmpty
                    ? "No friend requests"
                    : "No requests found",
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                final name = req['displayName'] ?? req['name'] ?? 'Unknown';
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(name[0])),
                    title: Text(name),
                    subtitle:
                        Text(req['message'] ?? 'Sent you a friend request'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          onPressed: () {
                            // TODO: Accept request
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Accept not implemented')));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () {
                            // TODO: Reject request
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Reject not implemented')));
                          },
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
