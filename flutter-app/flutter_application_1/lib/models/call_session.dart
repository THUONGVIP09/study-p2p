class CallSession {
  final int id;
  final int roomId;
  final int createdBy;
  final String topology;   // "p2p" / "sfu"
  final String? sfuRegion;
  final String? sfuRoomId; // mình sẽ để = roomCode
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? liveCount;

  CallSession({
    required this.id,
    required this.roomId,
    required this.createdBy,
    required this.topology,
    this.sfuRegion,
    this.sfuRoomId,
    this.startedAt,
    this.endedAt,
    this.liveCount,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'] as int,
      roomId: json['roomId'] as int,
      createdBy: json['createdBy'] as int,
      topology: json['topology'] as String,
      sfuRegion: json['sfuRegion'],
      sfuRoomId: json['sfuRoomId'],
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      liveCount: json['liveCount'],
    );
  }

  bool get isLive => endedAt == null;
}
