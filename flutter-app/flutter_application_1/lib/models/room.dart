class Room {
  final int id;
  final String roomCode;
  final String title;
  final String description;
  final String visibility;
  final bool isGroup;

  Room({
    required this.id,
    required this.roomCode,
    required this.title,
    required this.description,
    required this.visibility,
    required this.isGroup,
  });

  factory Room.fromJson(Map<String, dynamic> j) {
    // id: số hoặc chuỗi đều ok
    final int id = (j['id'] is String)
        ? int.parse(j['id'])
        : (j['id'] as num).toInt();

    // room_code: ưu tiên room_code/code/roomCode, nếu trống thì sinh từ id
    String code = (j['room_code'] ?? j['code'] ?? j['roomCode'] ?? '').toString();
    if (code.isEmpty) {
      code = 'ROOM-${id.toString().padLeft(4, '0')}';
    }

    // title: ưu tiên title, fallback name
    final String title = (j['title'] ?? j['name'] ?? '').toString();

    // description/visibility: fallback mặc định
    final String description = (j['description'] ?? '').toString();
    final String visibility =
        (j['visibility'] ?? 'public').toString().toLowerCase();

    // is_group: nhận bool | số | string, fallback từ max_participants (>2 coi như group)
    final dynamic ig = j['is_group'] ?? j['isGroup'] ?? j['group'];
    bool isGroup;
    if (ig is bool) {
      isGroup = ig;
    } else if (ig is num) {
      isGroup = ig.toInt() == 1;
    } else if (ig is String) {
      isGroup = ig == '1' || ig.toLowerCase() == 'true';
    } else {
      final mp = j['max_participants'];
      isGroup = (mp is num) ? mp.toInt() > 2 : true;
    }

    return Room(
      id: id,
      roomCode: code,
      title: title,
      description: description,
      visibility: visibility,
      isGroup: isGroup,
    );
  }
}
