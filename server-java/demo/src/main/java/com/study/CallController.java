package com.study;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.sql.*;
import java.time.LocalDateTime;
import com.study.dto.ApiResponse;
import com.study.dto.CallSessionDto;
import com.study.dto.EndCallRequest;

import com.study.dto.HeartbeatRequest;
import com.study.dto.JoinCallRequest;
import com.study.dto.StartCallRequest;
import com.study.Db;

@Path("/api/calls")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class CallController {

    // Tìm session "mới nhất" của 1 room (dù đã end hay chưa)
    @GET
    @Path("/latest")
    public Response getLatestCall(@QueryParam("roomId") long roomId) {
        if (roomId <= 0) {
            return bad("roomId không hợp lệ");
        }

        String sql = """
                SELECT cs.id, cs.room_id, cs.created_by, cs.topology, cs.sfu_region,
                       cs.sfu_room_id, cs.started_at, cs.ended_at,
                       v.live_count
                FROM call_sessions cs
                LEFT JOIN v_call_session_live v ON v.session_id = cs.id
                WHERE cs.room_id = ?
                ORDER BY cs.started_at DESC
                LIMIT 1
                """;

        try (Connection con = Db.get();
                PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setLong(1, roomId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Response.ok(new ApiResponse<>(true, "No session", null)).build();
                }

                CallSessionDto dto = mapCallSession(rs);
                return Response.ok(new ApiResponse<>(true, "OK", dto)).build();
            }

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // Start call (nếu cần) – thường gọi khi user bấm "Join call"
    @POST
    @Path("/start")
    public Response startCall(StartCallRequest req) {
        if (req.roomId() <= 0 || req.userId() <= 0) {
            return bad("roomId/userId không hợp lệ");
        }

        String topology = (req.topology() == null || req.topology().isBlank())
                ? "sfu"
                : req.topology().toLowerCase();
        if (!topology.equals("p2p") && !topology.equals("sfu")) {
            topology = "sfu";
        }

        String sfuRegion = req.sfuRegion(); // có thể null
        String sfuRoomId = req.sfuRoomId(); // thường = Agora channelName (roomCode)

        String sqlInsert = """
                INSERT INTO call_sessions
                (room_id, sfu_region, recording_url, created_by,
                 started_at, ended_at, topology, sfu_room_id, end_reason)
                VALUES (?,?,NULL,?,CURRENT_TIMESTAMP,NULL,?,?,NULL)
                """;

        try (Connection con = Db.get();
                PreparedStatement ps = con.prepareStatement(sqlInsert, Statement.RETURN_GENERATED_KEYS)) {

            ps.setLong(1, req.roomId());
            ps.setString(2, sfuRegion);
            ps.setLong(3, req.userId());
            ps.setString(4, topology);
            ps.setString(5, sfuRoomId);

            ps.executeUpdate();
            long callId;
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (!rs.next()) {
                    return server("Không lấy được call_id");
                }
                callId = rs.getLong(1);
            }

            // map lại để trả cho client (live_count mặc định 0)
            CallSessionDto dto = new CallSessionDto(
                    callId,
                    req.roomId(),
                    req.userId(),
                    topology,
                    sfuRegion,
                    sfuRoomId,
                    LocalDateTime.now(),
                    null,
                    0);

            return Response.ok(new ApiResponse<>(true, "Tạo call session thành công", dto)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // User join call (ghi vào call_participants)
    @POST
    @Path("/join")
    public Response joinCall(JoinCallRequest req) {
        if (req.callId() <= 0 || req.userId() <= 0) {
            return bad("callId/userId không hợp lệ");
        }

        String joinMode = req.joinMode();
        if (joinMode == null || joinMode.isBlank()) {
            joinMode = "SFU";
        } else {
            joinMode = joinMode.toUpperCase();
        }

        String sql = """
                INSERT INTO call_participants
                (call_id, user_id, join_mode, stats_json,
                 joined_at, left_at, last_seen_at,
                 mic_muted, cam_enabled, screenshare, hand_raised)
                VALUES (?,?,?,NULL,
                        CURRENT_TIMESTAMP,NULL,CURRENT_TIMESTAMP,
                        ?,?,?,?)
                ON DUPLICATE KEY UPDATE
                    join_mode = VALUES(join_mode),
                    last_seen_at = CURRENT_TIMESTAMP,
                    left_at = NULL,
                    mic_muted = VALUES(mic_muted),
                    cam_enabled = VALUES(cam_enabled),
                    screenshare = VALUES(screenshare),
                    hand_raised = VALUES(hand_raised)
                """;

        try (Connection con = Db.get();
                PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setLong(1, req.callId());
            ps.setLong(2, req.userId());
            ps.setString(3, joinMode);
            ps.setBoolean(4, req.micMuted());
            ps.setBoolean(5, req.camEnabled());
            ps.setBoolean(6, false);
            ps.setBoolean(7, false);

            ps.executeUpdate();
            return Response.ok(new ApiResponse<>(true, "Join call thành công", null)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // Heartbeat: client gửi 5–10s 1 lần
    @POST
    @Path("/heartbeat")
    public Response heartbeat(HeartbeatRequest req) {
        if (req.callId() <= 0 || req.userId() <= 0) {
            return bad("callId/userId không hợp lệ");
        }

        String sql = """
                INSERT INTO call_participants
                (call_id, user_id, join_mode, stats_json,
                 joined_at, left_at, last_seen_at,
                 mic_muted, cam_enabled, screenshare, hand_raised)
                VALUES (?,?, 'SFU', ?, CURRENT_TIMESTAMP, NULL, CURRENT_TIMESTAMP,
                        ?,?,?,?)
                ON DUPLICATE KEY UPDATE
                    last_seen_at = CURRENT_TIMESTAMP,
                    stats_json = VALUES(stats_json),
                    mic_muted = COALESCE(VALUES(mic_muted), mic_muted),
                    cam_enabled = COALESCE(VALUES(cam_enabled), cam_enabled),
                    screenshare = COALESCE(VALUES(screenshare), screenshare),
                    hand_raised = COALESCE(VALUES(hand_raised), hand_raised)
                """;

        try (Connection con = Db.get();
                PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setLong(1, req.callId());
            ps.setLong(2, req.userId());
            ps.setString(3, req.statsJson());
            ps.setBoolean(4, req.micMuted() != null && req.micMuted());
            ps.setBoolean(5, req.camEnabled() != null && req.camEnabled());
            ps.setBoolean(6, req.screenshare() != null && req.screenshare());
            ps.setBoolean(7, req.handRaised() != null && req.handRaised());

            ps.executeUpdate();
            return Response.ok(new ApiResponse<>(true, "OK", null)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // User leave call
    @POST
    @Path("/leave")
    public Response leaveCall(JoinCallRequest req) {
        if (req.callId() <= 0 || req.userId() <= 0) {
            return bad("callId/userId không hợp lệ");
        }

        String sql = """
                UPDATE call_participants
                SET left_at = CURRENT_TIMESTAMP
                WHERE call_id = ? AND user_id = ?
                """;

        try (Connection con = Db.get();
                PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setLong(1, req.callId());
            ps.setLong(2, req.userId());
            ps.executeUpdate();

            return Response.ok(new ApiResponse<>(true, "Leave call thành công", null)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // End call (host bấm kết thúc)
    @POST
    @Path("/end")
    public Response endCall(EndCallRequest req) {
        if (req.callId() <= 0)
            return bad("callId không hợp lệ");

        String sql = """
                UPDATE call_sessions
                SET ended_at = CURRENT_TIMESTAMP,
                    end_reason = ?
                WHERE id = ? AND ended_at IS NULL
                """;

        try (Connection con = Db.get();
                PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, req.endReason());
            ps.setLong(2, req.callId());
            ps.executeUpdate();

            return Response.ok(new ApiResponse<>(true, "End call thành công", null)).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return server("Lỗi DB: " + e.getMessage());
        }
    }

    // ===== Helpers =====

    private CallSessionDto mapCallSession(ResultSet rs) throws SQLException {
        long id = rs.getLong("id");
        long roomId = rs.getLong("room_id");
        long createdBy = rs.getLong("created_by");
        String topology = rs.getString("topology");
        String region = rs.getString("sfu_region");
        String sfuRoomId = rs.getString("sfu_room_id");
        Timestamp started = rs.getTimestamp("started_at");
        Timestamp ended = rs.getTimestamp("ended_at");
        Integer live = (Integer) rs.getObject("live_count");

        return new CallSessionDto(
                id,
                roomId,
                createdBy,
                topology,
                region,
                sfuRoomId,
                started != null ? started.toLocalDateTime() : null,
                ended != null ? ended.toLocalDateTime() : null,
                live);
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
