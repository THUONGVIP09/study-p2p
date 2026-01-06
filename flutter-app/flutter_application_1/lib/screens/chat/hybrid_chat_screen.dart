import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../../services/hybrid_chat_service.dart';
import '../../services/p2p_chat_service.dart';
import '../../services/global_chat_service.dart';
import '../../services/friend_chat_storage_service.dart';
import '../../services/unread_messages_service.dart';
import '../../services/network_helper.dart';
import '../../config/app_config.dart';
import '../../widgets/emoji_picker_button.dart';

class HybridChatScreen extends StatefulWidget {
  final int friendId;
  final String friendName;
  final int currentUserId;

  const HybridChatScreen({
    Key? key,
    required this.friendId,
    required this.friendName,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<HybridChatScreen> createState() => _HybridChatScreenState();
}

class _HybridChatScreenState extends State<HybridChatScreen> {
  // For non-web platforms
  P2PChatService? _p2p;
  HybridChatService? _hybrid;
  
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _sub;
  String _status = 'Connecting...';
  bool _isLoading = true; // Loading state
  bool _isSending = false; // Sending state

  @override
  void initState() {
    super.initState();
    _markAsRead();
    _bootstrap();
  }
  
  /// Đánh dấu tin nhắn từ friend này là đã đọc
  Future<void> _markAsRead() async {
    // Đảm bảo UnreadMessagesService đã được khởi tạo với đúng userId
    await UnreadMessagesService.initialize(widget.currentUserId);
    await UnreadMessagesService.markAsRead(widget.friendId);
  }

  Future<void> _bootstrap() async {
    print('');
    print(
        '🚀 [UI] BOOTSTRAP for friend ${widget.friendId} (${widget.friendName})');

    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
    });

    try {
      AppConfig.printConfig();

      if (kIsWeb) {
        // WEB PLATFORM: Use GlobalChatService (singleton - no new connection)
        print('🌐 [UI] Web platform detected - using GlobalChatService');
        
        // Ensure GlobalChatService is connected
        await GlobalChatService.instance.connect(widget.currentUserId);
        
        setState(() {
          _status = 'Via Server (Web)';
        });
        print('✅ [UI] Using GlobalChatService for web');

        // Setup stream listener for web - listen to global chat service
        _sub = GlobalChatService.instance.stream.listen((e) {
          if (e['friendId'] != widget.friendId) {
            return;
          }
          final msg = {
            'sender': e['sender'],
            'content': e['content'],
            'timestamp': e['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          // Check for duplicate before adding
          final isDuplicate = _messages.any((m) => 
            m['content'] == msg['content'] && 
            m['timestamp'] == msg['timestamp']
          );
          if (!isDuplicate) {
            setState(() {
              _messages.add(msg);
            });
            // Save received message to storage
            FriendChatStorageService.addMessage(
              widget.currentUserId,
              widget.friendId,
              msg,
            );
            _scrollToBottom();
          }
        });
      } else {
        // NON-WEB PLATFORM: Use P2P + Hybrid service
        print('📱 [UI] Non-web platform - using P2P + Hybrid');
        
        // Auto-detect local IP
        final myIp = await NetworkHelper.getLocalIpAddress();
        print('📶 [UI] Detected local IP: $myIp');

        _p2p = P2PChatService();
        _hybrid = HybridChatService(currentUserId: widget.currentUserId, p2p: _p2p!);

        print('🔌 [UI] Starting hybrid service...');
        await _hybrid!.start(myIp: myIp);

        print('🤝 [UI] Connecting to friend ${widget.friendId}...');
        final direct = await _hybrid!.connectToFriend(widget.friendId);
        setState(() {
          _status = direct ? 'P2P Direct' : 'Via Server';
        });
        print('✅ [UI] Connection mode: ${_status}');

        // Setup stream listener for non-web
        _sub = _hybrid!.stream.listen((e) {
          if (e['friendId'] != widget.friendId) {
            return;
          }
          final msg = {
            'sender': e['sender'],
            'content': e['content'],
            'timestamp': e['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          setState(() {
            _messages.add(msg);
          });
          // Save received message to storage
          FriendChatStorageService.addMessage(
            widget.currentUserId,
            widget.friendId,
            msg,
          );
          _scrollToBottom();
        });
      }

      // Load history BEFORE setting up stream listener để tránh duplicate
      print('📖 [UI] Loading chat history...');
      final history = await FriendChatStorageService.loadMessages(
          widget.currentUserId, widget.friendId);
      print('📖 [UI] Loaded ${history.length} messages from storage');

      setState(() {
        _messages.clear(); // Clear để đảm bảo không duplicate
        _messages.addAll(history);
        _isLoading = false;
      });
      print('✅ [UI] UI updated with ${_messages.length} messages');

      _scrollToBottom();
    } catch (e) {
      print('❌ Bootstrap error: $e');
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(String? isoTimestamp) {
    if (isoTimestamp == null || isoTimestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inDays == 0) {
        // Today - show time only
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        // Yesterday
        return 'Hôm qua ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays < 7) {
        // This week
        final weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        return '${weekdays[dt.weekday - 1]} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        // Older
        return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    print('');
    print('🔴 [UI] WIDGET DISPOSE CALLED for friend ${widget.friendId}');
    print('   📊 Current UI messages count: ${_messages.length}');

    _sub?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();

    // Only dispose HybridChatService for non-web platforms
    // GlobalChatService is a singleton and should not be disposed here
    if (!kIsWeb) {
      _hybrid?.dispose().then((_) {
        print('✅ [UI] HybridChatService disposed after pending saves');
      }).catchError((e) {
        print('❌ [UI] Error disposing HybridChatService: $e');
      });
    }

    super.dispose();
    print('✅ [UI] Widget dispose completed');
  }

  Future<void> _send() async {
    if (_isSending || _isLoading) return; // Block nếu đang gửi hoặc loading

    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    print('');
    print('📤 [UI] USER SENDING: $text');
    print('   Current messages count: ${_messages.length}');

    setState(() {
      _isSending = true;
    });

    _msgCtrl.clear();

    try {
      // Send via appropriate service based on platform
      bool success = false;
      if (kIsWeb) {
        // Use GlobalChatService for web
        success = await GlobalChatService.instance.sendToFriend(widget.friendId, text);
      } else {
        await _hybrid?.sendToFriend(widget.friendId, text);
        success = true;
      }

      if (success) {
        // Create message object
        final msg = {
          'sender': 'me',
          'content': text,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        // Update UI
        print('✅ [UI] Send completed, updating UI...');
        setState(() {
          _messages.add(msg);
        });
        print('   After add: ${_messages.length} messages');
        
        // Save to storage
        await FriendChatStorageService.addMessage(
          widget.currentUserId,
          widget.friendId,
          msg,
        );
        
        _scrollToBottom();
      } else {
        throw Exception('Send failed');
      }
    } catch (e) {
      print('❌ [UI] Send error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.friendName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
                child: Text(_status, style: const TextStyle(fontSize: 12))),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, 
                                size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có tin nhắn nào',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bắt đầu cuộc trò chuyện!',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final m = _messages[i];
                            final isMe = m['sender'] == 'me';
                            final timestamp = _formatTimestamp(m['timestamp']);
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe 
                                      ? CrossAxisAlignment.end 
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['content'] ?? '',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timestamp,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(children: [
                  // Emoji picker button
                  EmojiPickerButton(
                    onEmojiSelected: (emoji) {
                      // Insert emoji at cursor position
                      final text = _msgCtrl.text;
                      final selection = _msgCtrl.selection;
                      final newText = text.replaceRange(
                        selection.start,
                        selection.end,
                        emoji,
                      );
                      _msgCtrl.text = newText;
                      _msgCtrl.selection = TextSelection.collapsed(
                        offset: selection.start + emoji.length,
                      );
                    },
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      enabled: !_isLoading && !_isSending,
                      decoration: InputDecoration(
                        hintText: _isLoading
                            ? 'Loading...'
                            : _isSending
                                ? 'Sending...'
                                : 'Type a message...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: (_isLoading || _isSending) 
                          ? Colors.grey 
                          : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: (_isLoading || _isSending) ? null : _send,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            )
          ]),
          // Overlay khi đang loading để block toàn bộ UI
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading chat history...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
