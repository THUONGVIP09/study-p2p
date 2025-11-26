import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/chat_storage_service.dart';
import '../../services/friends_service.dart';
import 'chat_connection_setup_screen.dart';

/// Màn hình chính của Chat - hiển thị tất cả conversations
/// Giống Messenger, WhatsApp - danh sách các cuộc hội thoại
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  int? _currentUserId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null) {
        setState(() {
          _errorMessage = 'Please login first';
          _isLoading = false;
        });
        return;
      }

      setState(() => _currentUserId = userId);

      // Load all chat history to get list of conversations
      final chatHistoryMap = await ChatStorageService.loadHistory(userId);

      // Get unique friend IDs from chat history
      final friendIds = chatHistoryMap.keys.toList();

      // Load friends list from API to get names
      List<Map<String, dynamic>> friendsList = [];
      try {
        friendsList = await FriendsService.getFriends();
        print('📋 Loaded ${friendsList.length} friends for name lookup');
      } catch (e) {
        print('⚠️ Could not load friends list: $e');
      }

      // Get friend details and last messages
      final conversations = <Map<String, dynamic>>[];

      for (var friendId in friendIds) {
        String friendName = 'User $friendId';
        String friendEmail = '';

        // Find friend info from friends list
        try {
          final friend = friendsList.firstWhere(
            (f) => f['id'].toString() == friendId,
            orElse: () => <String, dynamic>{},
          );

          if (friend.isNotEmpty) {
            friendName = friend['name'] ??
                friend['displayName'] ??
                friend['email']?.toString().split('@').first ??
                'User $friendId';
            friendEmail = friend['email'] ?? '';
            print('✅ Found friend $friendId: $friendName');
          } else {
            print('⚠️ Friend $friendId not in friends list');
          }
        } catch (e) {
          print('⚠️ Error looking up friend $friendId: $e');
        }

        // Get messages with this friend
        final friendMessages = chatHistoryMap[friendId] ?? [];

        if (friendMessages.isNotEmpty) {
          final lastMsg = friendMessages.last;

          conversations.add({
            'friendId': int.parse(friendId),
            'friendName': friendName,
            'friendEmail': friendEmail,
            'lastMessage': lastMsg['content'] ?? '',
            'lastMessageTime': lastMsg['timestamp'] ?? '',
            'sender': lastMsg['sender'] ?? 'me',
            'unreadCount': 0, // TODO: implement unread count
          });
        }
      }

      // Sort by last message time (newest first)
      conversations.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['lastMessageTime'] ?? '') ?? DateTime(2000);
        final bTime =
            DateTime.tryParse(b['lastMessageTime'] ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading conversations: $e';
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${time.day}/${time.month}/${time.year}';
    } catch (e) {
      return '';
    }
  }

  void _openChat(Map<String, dynamic> conversation) {
    if (_currentUserId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConnectionSetupScreen(
          friendId: conversation['friendId'],
          friendName: conversation['friendName'],
          currentUserId: _currentUserId!,
        ),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      _loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadConversations,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No conversations yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start chatting with your friends!',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConversations,
                      child: ListView.separated(
                        itemCount: _conversations.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 72,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, index) {
                          final conv = _conversations[index];
                          final isMe = conv['sender'] == 'me';

                          return ListTile(
                            onTap: () => _openChat(conv),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                conv['friendName'].toString()[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            title: Text(
                              conv['friendName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${isMe ? "You: " : ""}${conv['lastMessage']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTime(conv['lastMessageTime']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                if (conv['unreadCount'] > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${conv['unreadCount']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
