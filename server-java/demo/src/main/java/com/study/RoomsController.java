package com.study;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.sql.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import com.study.dto.RoomDto;
import com.study.dto.CreateRoomRequest;
import com.study.dto.ApiResponse;
import com.study.dto.JoinRoomRequest;

@Path("/api/rooms")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class RoomsController {

    // ========= TẠO PHÒNG =========
    @POST
    public Response createRoom(CreateRoomRequest req) {
        if (req == null || req.name() == null || req.name().isBlank()) {
            return bad("Tên phòng không được rỗng");
        }
        long createdBy = req.createdBy() == null ? 0L : req.createdBy();
        if (createdBy <= 0) {
            return bad("createdBy không hợp lệ");
        }

        String visibility = normalizeVisibility(req.visibility());

        Integer maxP = (req.maxParticipants() == null || req.maxParticipants() <= 0)
                ? 12
                : req.maxParticipants();

        try (Connection con = Db.get()) { // Db.get() phải trả về Connection
            con.setAutoCommit(false);

            // 1) tạo conversation
            long conversationId;
            try (PreparedStatement ps = con.prepareStatement(
                    "INSERT INTO conversations (type) VALUES ('ROOM')",
                    Statement.RETURN_GENERATED_KEYS)) {
                ps.executeUpdate();
                try (ResultSet rs = ps.getGeneratedKeys()) {
                    if (!rs.next()) {
                        con.rollback();
                        return server("Không lấy được conversation_id");
                    }
                    conversationId = rs.getLong(1);
                }
            }

            // 2) tạo room
            long roomId;
            String sqlRoom = """
                    INSERT INTO rooms
                    (conversation_id, name, description, visibility, passcode,
                     max_participants, created_by, is_active)
                    VALUES (?,?,?,?,?,?,?,1)
                    """;
            try (PreparedStatement ps = con.prepareStatement(sqlRoom, Statement.RETURN_GENERATED_KEYS)) {
                ps.setLong(1, conversationId);
                ps.setString(2, req.name());
                ps.setString(3, req.description());
                ps.setString(4, visibility);
                ps.setString(5, req.passcode());
                // Set max participants
                ps.setInt(6, maxP);
                ps.setLong(7, createdBy);

                ps.executeUpdate();
                try (ResultSet rs = ps.getGeneratedKeys()) {
                    if (!rs.next()) {
                        con.rollback();
                        return server("Không lấy được room_id");
                    }
                    roomId = rs.getLong(1);
                }
            }

            // 3) thêm owner vào room_members
            String sqlMember = """
                    INSERT INTO room_members (room_id, user_id, role)
                    VALUES (?,?, 'HOST')
                    """;
            try (PreparedStatement ps = con.prepareStatement(sqlMember)) {
                ps.setLong(1, roomId);
                ps.setLong(2, createdBy);
                ps.executeUpdate();
            }

            con.commit();

            String roomCode = encodeRoomCode(roomId);
            String createdAtStr = LocalDateTime.now().toString();

            RoomDto dto = new RoomDto(
                    roomId,
                    conversationId,
                    req.name(),
                    roomCode,
                    req.description(),
                    visibility,
                    maxP,
                    createdBy,
                    true,
                    createdAtStr);

            return Response.ok(new ApiResponse<>(true, "Tạo phòng thành công", dto)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // ========= LẤY TẤT CẢ PHÒNG =========
    @GET
    public Response listRooms(@QueryParam("userId") Long userId) {
        // userId bây giờ không dùng, chỉ để tương thích với client
        String sql = """
                SELECT r.id, r.conversation_id, r.name, r.description,
                       r.visibility, r.passcode, r.max_participants,
                       r.created_by, r.is_active, r.created_at
                FROM rooms r
                ORDER BY r.created_at DESC
                """;

        List<RoomDto> list = new ArrayList<>();

        try (Connection con = Db.get();
                PreparedStatement ps = con.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                long id = rs.getLong("id");
                long convId = rs.getLong("conversation_id");
                String name = rs.getString("name");
                String desc = rs.getString("description");
                String vis = rs.getString("visibility");
                Integer maxP = (Integer) rs.getObject("max_participants");
                long createdBy = rs.getLong("created_by");
                boolean isActive = rs.getBoolean("is_active");
                Timestamp createdAt = rs.getTimestamp("created_at");
                String createdAtStr = createdAt != null
                        ? createdAt.toLocalDateTime().toString()
                        : null;

                String roomCode = encodeRoomCode(id);

                list.add(new RoomDto(
                        id,
                        convId,
                        name,
                        roomCode,
                        desc,
                        vis,
                        maxP,
                        createdBy,
                        isActive,
                        createdAtStr));
            }
            return Response.ok(new ApiResponse<>(true, "OK", list)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // ========= JOIN ROOM (PRIVATE/PUBLIC/PROTECTED) =========
    @POST
    @Path("/join")
    public Response joinRoom(JoinRoomRequest req) {
        if ((req.roomCode() == null || req.roomCode().isBlank())) {
            return bad("roomCode không hợp lệ");
        }
        // Giải mã roomCode -> roomId
        long roomId = decodeRoomCode(req.roomCode());
        if (roomId <= 0)
            return bad("roomCode không hợp lệ");

        String sql = "SELECT visibility, passcode, created_by FROM rooms WHERE id = ?";
        try (Connection con = Db.get(); PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setLong(1, roomId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next())
                    return bad("Room không tồn tại");
                String vis = rs.getString("visibility");
                String storedPass = rs.getString("passcode");

                vis = normalizeVisibility(vis);
                switch (vis) {
                    case "PUBLIC" -> {
                        return Response.ok(new ApiResponse<>(true, "OK", null)).build();
                    }
                    case "PRIVATE" -> {
                        String provided = req.passcode();
                        if (storedPass == null || storedPass.isBlank()) {
                            return bad("Phòng PRIVATE chưa thiết lập passcode");
                        }
                        if (provided == null || !storedPass.equals(provided)) {
                            return bad("Passcode không đúng");
                        }
                        return Response.ok(new ApiResponse<>(true, "OK", null)).build();
                    }
                    case "PROTECTED" -> {
                        // Chưa có cơ chế approve thực, trả về trạng thái pending để client hiển thị chờ
                        return Response.ok(new ApiResponse<>(true, "PENDING_APPROVAL", null)).build();
                    }
                    default -> {
                        return Response.ok(new ApiResponse<>(true, "OK", null)).build();
                    }
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // ========= XÓA PHÒNG =========
    @DELETE
    @Path("/{roomId}")
    public Response deleteRoom(@PathParam("roomId") long roomId, @HeaderParam("X-User-Id") Long userId) {
        if (roomId <= 0) {
            return bad("roomId không hợp lệ");
        }

        try (Connection con = Db.get()) {
            // Kiểm tra quyền xóa (chỉ chủ phòng mới được xóa)
            String checkSql = "SELECT created_by, conversation_id FROM rooms WHERE id = ?";
            long createdBy = 0;
            long conversationId = 0;
            try (PreparedStatement ps = con.prepareStatement(checkSql)) {
                ps.setLong(1, roomId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) {
                        return bad("Room không tồn tại");
                    }
                    createdBy = rs.getLong("created_by");
                    conversationId = rs.getLong("conversation_id");
                }
            }

            // Optional: check userId header for authorization
            // if (userId != null && userId != createdBy) {
            // return bad("Bạn không có quyền xóa phòng này");
            // }

            con.setAutoCommit(false);

            // 1) Xóa room_members
            try (PreparedStatement ps = con.prepareStatement("DELETE FROM room_members WHERE room_id = ?")) {
                ps.setLong(1, roomId);
                ps.executeUpdate();
            }

            // 2) Xóa call_participants (nếu có)
            try (PreparedStatement ps = con.prepareStatement(
                    "DELETE FROM call_participants WHERE call_id IN (SELECT id FROM call_sessions WHERE room_id = ?)")) {
                ps.setLong(1, roomId);
                ps.executeUpdate();
            }

            // 3) Xóa call_sessions (nếu có)
            try (PreparedStatement ps = con.prepareStatement("DELETE FROM call_sessions WHERE room_id = ?")) {
                ps.setLong(1, roomId);
                ps.executeUpdate();
            }

            // 4) Xóa messages liên quan đến conversation (nếu có)
            if (conversationId > 0) {
                try (PreparedStatement ps = con.prepareStatement("DELETE FROM messages WHERE conversation_id = ?")) {
                    ps.setLong(1, conversationId);
                    ps.executeUpdate();
                }
            }

            // 5) Xóa room
            try (PreparedStatement ps = con.prepareStatement("DELETE FROM rooms WHERE id = ?")) {
                ps.setLong(1, roomId);
                ps.executeUpdate();
            }

            // 6) Xóa conversation (nếu có)
            if (conversationId > 0) {
                try (PreparedStatement ps = con.prepareStatement("DELETE FROM conversations WHERE id = ?")) {
                    ps.setLong(1, conversationId);
                    ps.executeUpdate();
                }
            }

            con.commit();
            return Response.ok(new ApiResponse<>(true, "Xóa phòng thành công", null)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // ========= Helpers =========

    private String normalizeVisibility(String vis) {
        if (vis == null || vis.isBlank())
            return "PUBLIC";
        vis = vis.toUpperCase();
        return switch (vis) {
            case "PUBLIC", "PRIVATE", "PROTECTED" -> vis;
            default -> "PUBLIC";
        };
    }

    // id -> "R000123"
    private String encodeRoomCode(long roomId) {
        return "R" + String.format("%06d", roomId);
    }

    private long decodeRoomCode(String roomCode) {
        try {
            if (roomCode == null || roomCode.length() < 2)
                return -1;
            if (!roomCode.startsWith("R"))
                return -1;
            return Long.parseLong(roomCode.substring(1));
        } catch (Exception e) {
            return -1;
        }
    }

    private Response bad(String msg) {
        return Response.status(Response.Status.BAD_REQUEST)
                .entity(new ApiResponse<>(false, msg, null))
                .build();
    }

    private Response server(String msg) {
        return Response.serverError()
                .entity(new ApiResponse<>(false, msg, null))
                .build();
    }
}
