class ChatMessage {
  final String id;
  final int senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isSelf;
  final int? messageId; // server DB id (optional)

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isSelf,
    this.messageId,
  });
}
