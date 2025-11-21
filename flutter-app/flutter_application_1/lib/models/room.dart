class Room {
  final int id;
  final int conversationId;
  final String name;
  final String roomCode;
  final String? description;
  final String visibility; // PUBLIC/PRIVATE/PROTECTED
  final int? maxParticipants;
  final int createdBy;
  final bool isActive;
  final DateTime? createdAt;

  Room({
    required this.id,
    required this.conversationId,
    required this.name,
    required this.roomCode,
    this.description,
    required this.visibility,
    this.maxParticipants,
    required this.createdBy,
    required this.isActive,
    this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      conversationId: json['conversationId'] as int,
      name: json['name'] as String,
      roomCode: json['roomCode'] as String,
      description: json['description'],
      visibility: json['visibility'] as String,
      maxParticipants: json['maxParticipants'],
      createdBy: json['createdBy'] as int,
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}
