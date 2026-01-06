import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/friends_service.dart';
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
  
  // Chat relay connection to register self as online
  WebSocketChannel? _chatRelayChannel;
  int? _currentUserId;
  Timer? _heartbeatTimer;
  Timer? _refreshOnlineListTimer;
  @override
  void initState() {
    super.initState();
    _loadFriends();
    _initializeOnlineStatus();
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

      // Connect to chat-relay to register as online
      final relayUrl = AppConfig.chatRelayUrl(_currentUserId!);
      debugPrint('🔌 Connecting to chat-relay to register as online: $relayUrl');
      
      _chatRelayChannel = WebSocketChannel.connect(Uri.parse(relayUrl));
      
      // Listen for any incoming messages (in case someone sends a message)
      _chatRelayChannel!.stream.listen(
        (data) {
          debugPrint('📨 [FriendsTab] Received relay message: $data');
        },
        onError: (error) {
          debugPrint('❌ Chat relay error: $error');
        },
        onDone: () {
          debugPrint('🔌 Chat relay disconnected');
        },
      );

      // Start heartbeat to stay online
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_chatRelayChannel != null) {
          try {
            _chatRelayChannel!.sink.add(jsonEncode({
              'type': 'heartbeat',
              'from': _currentUserId,
            }));
          } catch (e) {
            debugPrint('❌ Heartbeat failed: $e');
          }
        }
      });

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

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Avatar with online indicator
                        Stack(
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
    _heartbeatTimer?.cancel();
    _refreshOnlineListTimer?.cancel();
    _onlineListSub?.cancel();
    _chatRelayChannel?.sink.close();
    _onlineListChannel?.sink.close();
    searchCtrl.dispose();
    super.dispose();
  }
}
