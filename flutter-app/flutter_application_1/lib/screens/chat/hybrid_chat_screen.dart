import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/hybrid_chat_service.dart';
import '../../services/p2p_chat_service.dart';
import '../../services/chat_storage_service.dart';
import '../../services/network_helper.dart';
import '../../config/app_config.dart';

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
  late final P2PChatService _p2p;
  late final HybridChatService _hybrid;
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
    _p2p = P2PChatService();
    _hybrid = HybridChatService(currentUserId: widget.currentUserId, p2p: _p2p);
    _bootstrap();
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
      // Auto-detect local IP
      final myIp = await NetworkHelper.getLocalIpAddress();
      print('📶 [UI] Detected local IP: $myIp');

      AppConfig.printConfig();

      print('🔌 [UI] Starting hybrid service...');
      await _hybrid.start(myIp: myIp);

      print('🤝 [UI] Connecting to friend ${widget.friendId}...');
      final direct = await _hybrid.connectToFriend(widget.friendId);
      setState(() {
        _status = direct ? 'P2P Direct' : 'Via Server';
      });
      print('✅ [UI] Connection mode: ${_status}');

      // Load history BEFORE setting up stream listener để tránh duplicate
      print('📖 [UI] Loading chat history...');
      final history = await ChatStorageService.getMessagesWithPeer(
          widget.currentUserId, widget.friendId.toString());
      print('📖 [UI] Loaded ${history.length} messages from storage');

      setState(() {
        _messages.clear(); // Clear để đảm bảo không duplicate
        _messages.addAll(history);
        _isLoading = false;
      });
      print('✅ [UI] UI updated with ${_messages.length} messages');

      // Setup stream listener AFTER loading history
      print('🎧 [UI] Setting up stream listener...');
      _sub = _hybrid.stream.listen((e) {
        // ✅ CHỈ nhận messages của friend hiện tại!
        if (e['friendId'] != widget.friendId) {
          print(
              '⏭️ [UI] Skipping message from friend ${e['friendId']} (current: ${widget.friendId})');
          return;
        }

        print('');
        print('📥 [UI] Received from stream: ${e['sender']} - ${e['content']}');
        print('   Current messages count: ${_messages.length}');

        setState(() {
          _messages.add({
            'sender': e['sender'],
            'content': e['content'],
            'timestamp': e['timestamp'],
          });
        });

        print('   After add: ${_messages.length} messages');
        _scrollToBottom();
      });

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

  @override
  void dispose() {
    print('');
    print('🔴 [UI] WIDGET DISPOSE CALLED for friend ${widget.friendId}');
    print('   📊 Current UI messages count: ${_messages.length}');

    _sub?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();

    // Đợi pending saves trước khi dispose - CRITICAL để không mất tin nhắn!
    print('🔄 [UI] Calling HybridChatService.dispose()...');
    _hybrid.dispose().then((_) {
      print('✅ [UI] HybridChatService disposed after pending saves');
    }).catchError((e) {
      print('❌ [UI] Error disposing HybridChatService: $e');
      print('   Stack trace: $e');
    });

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
      // Service sẽ tự động lưu vào storage
      print('📤 [UI] Calling hybrid.sendToFriend...');
      await _hybrid.sendToFriend(widget.friendId, text);

      // Chỉ update UI
      print('✅ [UI] Send completed, updating UI...');
      setState(() {
        _messages.add({
          'sender': 'me',
          'content': text,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      print('   After add: ${_messages.length} messages');
      _scrollToBottom();
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
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final isMe = m['sender'] == 'me';
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(m['content'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _msgCtrl,
                      enabled: !_isLoading &&
                          !_isSending, // Disable khi loading/sending
                      decoration: InputDecoration(
                        hintText: _isLoading
                            ? 'Loading...'
                            : _isSending
                                ? 'Sending...'
                                : 'Type a message...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isSending) ? null : _send,
                    child: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send'),
                  ),
                )
              ]),
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
