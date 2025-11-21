import '../models/room.dart';
import 'api_service.dart';

class RoomService {
  const RoomService();

  /// GET /api/rooms?userId=...
  Future<List<Room>> getAllRooms() {
    return ApiService.fetchRooms();
  }

  /// POST /api/rooms
  Future<Room> createRoom({
    required String name,
    String? description,
    String visibility = 'PUBLIC',
    String? passcode,
    int? maxParticipants,
    required int createdBy,
  }) {
    return ApiService.createRoom(
      name: name,
      description: description,
      visibility: visibility,
      passcode: passcode,
      maxParticipants: maxParticipants,
      createdBy: createdBy,
    );
  }

  /// POST /api/rooms/join
  Future<Room> joinRoomByCode({
    required String roomCode,
    required int userId,
    String? passcode,
  }) {
    return ApiService.joinRoomByCode(
      roomCode: roomCode,
      userId: userId,
      passcode: passcode,
    );
  }
}
