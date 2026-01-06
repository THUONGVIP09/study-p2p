import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/friends_service.dart';
import '../../services/unread_messages_service.dart';
import '../../services/friend_chat_storage_service.dart';
import '../../services/global_chat_service.dart';
import '../chat/hybrid_chat_screen.dart';
import '../../config/app_config.dart';

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

  // Online status tracking
  final Map<int, bool> _onlineStatus = {};
  WebSocketChannel? _onlineListChannel;
  StreamSubscription? _onlineListSub;
  
  // Use global chat service for relay connection
  StreamSubscription? _chatMessageSub;
  int? _currentUserId;
  Timer? _refreshOnlineListTimer;
  
  // Unread message counts per friend
  Map<int, int> _unreadCounts = {};
  @override
  void initState() {
    super.initState();
    _loadFriends();
    _initializeOnlineStatus();
    _loadUnreadCounts();
    
    // Listen to unread count changes
    UnreadMessagesService.addListener(_onUnreadCountsChanged);
  }

  /// Initialize online status: first register self, then subscribe to updates
  Future<void> _initializeOnlineStatus() async {
    // First, register ourselves as online
    await _registerAsOnline();
    
    // Small delay to ensure server has processed our registration
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Then subscribe to online list updates
    _subscribeToOnlineList();
    
    // Set up periodic refresh to handle any missed updates
    // This reconnects every 30 seconds to ensure fresh data
    _refreshOnlineListTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _reconnectOnlineList();
      }
    });
  }

  /// Register current user as online by connecting to chat-relay
  Future<void> _registerAsOnline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('userId');
      
      if (_currentUserId == null) {
        debugPrint('⚠️ No userId found, cannot register as online');
        return;
      }
      
      // Initialize UnreadMessagesService với userId để tránh xung đột file
      await UnreadMessagesService.initialize(_currentUserId!);

      // Connect to global chat service (singleton - shared across app)
      await GlobalChatService.instance.connect(_currentUserId!);
      debugPrint('🔌 Connected to GlobalChatService for user $_currentUserId');
      
      // Listen for incoming messages from global chat service
      _chatMessageSub?.cancel();
      _chatMessageSub = GlobalChatService.instance.stream.listen(
        (msg) {
          debugPrint('📨 [FriendsTab] Received from GlobalChat: $msg');
          _handleIncomingChatMessage(msg);
        },
        onError: (error) {
          debugPrint('❌ GlobalChat stream error: $error');
        },
      );

      debugPrint('✅ Registered as online (userId: $_currentUserId)');
    } catch (e) {
      debugPrint('❌ Failed to register as online: $e');
    }
  }

  void _subscribeToOnlineList() {
    try {
      // Connect to online list broadcast WebSocket using AppConfig
      // Use WebSocketChannel.connect for cross-platform support (web + native)
      _onlineListChannel = WebSocketChannel.connect(
        Uri.parse(AppConfig.onlineListUrl),
      );

      // Listen for online peer updates
      _onlineListSub = _onlineListChannel!.stream.listen((data) {
        try {
          final msg = jsonDecode(data);
          if (msg['type'] == 'ONLINE_LIST') {
            final peers = msg['peers'] as List;
            if (mounted) {
              setState(() {
                // Reset all to offline first
                _onlineStatus.clear();

                // Mark online peers
                for (var peer in peers) {
                  final userId = peer['userId'];
                  if (userId != null) {
                    _onlineStatus[userId] = true;
                  }
                }
              });
              debugPrint('📡 Online status updated: ${_onlineStatus.keys.length} users online');
            }
          }
        } catch (e) {
          debugPrint('Error parsing online list: $e');
        }
      }, onError: (error) {
        debugPrint('Online list WebSocket error: $error');
        // Try to reconnect after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _subscribeToOnlineList();
          }
        });
      }, onDone: () {
        debugPrint('Online list WebSocket closed');
        // Try to reconnect after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _subscribeToOnlineList();
          }
        });
      });
    } catch (e) {
      debugPrint('Failed to subscribe to online list: $e');
    }
  }

  /// Reconnect to online list WebSocket to get fresh data
  void _reconnectOnlineList() {
    debugPrint('🔄 Reconnecting to online list for fresh data...');
    _onlineListSub?.cancel();
    _onlineListChannel?.sink.close();
    _subscribeToOnlineList();
  }

  /// Load số tin nhắn chưa đọc
  Future<void> _loadUnreadCounts() async {
    final counts = await UnreadMessagesService.getUnreadCounts();
    if (mounted) {
      setState(() {
        _unreadCounts = counts;
      });
    }
  }
  
  /// Callback khi số tin nhắn chưa đọc thay đổi
  void _onUnreadCountsChanged(Map<int, int> counts) {
    if (mounted) {
      setState(() {
        _unreadCounts = counts;
      });
    }
  }
  
  /// Xử lý tin nhắn đến từ GlobalChatService
  /// Format: {friendId: int, sender: 'peer', content: String, timestamp: String}
  void _handleIncomingChatMessage(Map<String, dynamic> msg) async {
    try {
      debugPrint('🔍 [FriendsTab] Processing chat message: $msg');
      
      final fromUserId = msg['friendId'] as int?;
      final content = msg['content'] as String?;
      final timestamp = msg['timestamp'] as String? ?? DateTime.now().toIso8601String();
      
      // Skip if not a valid chat message
      if (fromUserId == null || content == null) {
        debugPrint('⚠️ [FriendsTab] Skipping - invalid message format');
        return;
      }
      
      debugPrint('📩 [FriendsTab] New message from user $fromUserId: $content');
      
      // Lưu vào unread messages
      await UnreadMessagesService.addUnreadMessage(
        friendId: fromUserId,
        senderName: 'Friend $fromUserId',
        content: content,
        timestamp: timestamp,
      );
      
      // Lưu vào lịch sử chat
      if (_currentUserId != null) {
        await FriendChatStorageService.addMessage(
          _currentUserId!,
          fromUserId,
          {
            'sender': 'peer',
            'content': content,
            'timestamp': timestamp,
          },
        );
        debugPrint('✅ [FriendsTab] Saved message to storage');
      }
    } catch (e) {
      debugPrint('❌ Error handling incoming message: $e');
    }
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
                final userId = user['id'] as int;
                final isOnline = _onlineStatus[userId] ?? false;
                final unreadCount = _unreadCounts[userId] ?? 0;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Avatar with online indicator and unread badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              child: Text(
                                (user['displayName'] ?? 'U')[0].toUpperCase(),
                              ),
                            ),
                            // Online status indicator (chấm xanh/xám)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            // Unread message badge (chấm đỏ với số)
                            if (unreadCount > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Name & Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user['displayName'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Online status text
                                  Text(
                                    isOnline ? 'online' : 'offline',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          isOnline ? Colors.green : Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
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

                        // Action button
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            final userId = user['id'] as int;
                            if (value == 'remove') {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove Friend'),
                                  content: const Text(
                                      'Are you sure you want to remove this friend?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  await FriendsService.removeFriend(userId);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Friend removed successfully')),
                                    );
                                    _loadFriends();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              }
                            } else if (value == 'block') {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Block User'),
                                  content: const Text(
                                      'Are you sure you want to block this user? This will remove them from your friends list and delete any pending friend requests.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Block'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  await FriendsService.blockUser(userId);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'User blocked successfully')),
                                    );
                                    _loadFriends();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              }
                            } else if (value == 'message') {
                              // Get current user ID from SharedPreferences
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final currentUserId = prefs.getInt('userId') ?? 1;
                              
                              // Clear unread messages for this friend
                              await UnreadMessagesService.markAsRead(userId);

                              // Navigate directly to chat (uses AppConfig server IP)
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HybridChatScreen(
                                    friendId: userId,
                                    friendName:
                                        (user['displayName'] ?? 'Friend'),
                                    currentUserId: currentUserId,
                                  ),
                                ),
                              );
                            }
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
    _refreshOnlineListTimer?.cancel();
    _onlineListSub?.cancel();
    _chatMessageSub?.cancel();
    _onlineListChannel?.sink.close();
    searchCtrl.dispose();
    UnreadMessagesService.removeListener(_onUnreadCountsChanged);
    // Don't disconnect GlobalChatService here - it's a singleton
    super.dispose();
  }
}
