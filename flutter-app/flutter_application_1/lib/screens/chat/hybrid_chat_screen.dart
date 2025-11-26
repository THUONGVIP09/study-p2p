import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/hybrid_chat_service.dart';
import '../../services/p2p_chat_service.dart';
import '../../services/chat_storage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _p2p = P2PChatService();
    _hybrid = HybridChatService(currentUserId: widget.currentUserId, p2p: _p2p);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final myIp = '127.0.0.1'; // TODO: optionally detect via NetworkInfo
    await _hybrid.start(myIp: myIp);
    final direct = await _hybrid.connectToFriend(widget.friendId);
    setState(() {
      _status = direct ? 'P2P Direct' : 'Via Server';
    });
    final history = await ChatStorageService.getMessagesWithPeer(
        widget.friendId.toString());
    setState(() {
      _messages.addAll(history);
    });
    _sub = _hybrid.stream.listen((e) {
      setState(() {
        _messages.add({
          'sender': e['sender'],
          'content': e['content'],
          'timestamp': e['timestamp'],
        });
      });
      _scrollToBottom();
    });
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
    _sub?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    _hybrid.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await _hybrid.sendToFriend(widget.friendId, text);
    await ChatStorageService.addMessage(widget.friendId.toString(), {
      'sender': 'me',
      'content': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
    setState(() {
      _messages.add({
        'sender': 'me',
        'content': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.friendName}'), actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Center(
              child: Text(_status, style: const TextStyle(fontSize: 12))),
        )
      ]),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m = _messages[i];
              final isMe = m['sender'] == 'me';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue.shade100 : Colors.grey.shade300,
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
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child:
                  ElevatedButton(onPressed: _send, child: const Text('Send')),
            )
          ]),
        )
      ]),
    );
  }
}
