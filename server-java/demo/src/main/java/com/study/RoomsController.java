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
                if (maxP == null) {
                    ps.setNull(6, Types.INTEGER);
                } else {
                    ps.setInt(6, maxP);
                }
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
                    LocalDateTime.now());

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
                        createdAt != null ? createdAt.toLocalDateTime() : null));
            }

            return Response.ok(new ApiResponse<>(true, "OK", list)).build();

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
