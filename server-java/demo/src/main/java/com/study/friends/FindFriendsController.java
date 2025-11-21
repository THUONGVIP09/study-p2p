package com.study.friends;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

record DiscoverUserDto(long id, String email, String displayName, String relationshipStatus) {}

@Path("/api/find-friends")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class FindFriendsController {

    /**
     * GET /api/find-friends?q=search&limit=50&offset=0
     * Tìm kiếm những user khác (không phải bạn bè, không bị block)
     * Trả về: id, email, display_name, relationshipStatus (NONE, PENDING, BLOCKED)
     */
    @GET
    public Response searchUsers(
            @QueryParam("q") @DefaultValue("") String q,
            @QueryParam("limit") @DefaultValue("50") int limit,
            @QueryParam("offset") @DefaultValue("0") int offset,
            @HeaderParam("Authorization") String token) {

        try {
            // TODO: từ token
            long userId = 1;

            if (q.isEmpty() || q.length() < 2) {
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Search query must be at least 2 characters"))
                        .build();
            }

            limit = Math.min(limit, 100);
            if (offset < 0) offset = 0;

            List<DiscoverUserDto> users = new ArrayList<>();

            // SQL: Tìm users không phải current user, không phải bạn bè, không bị block
            String sql = "SELECT u.id, u.email, u.display_name, " +
                    "CASE " +
                    "  WHEN EXISTS (SELECT 1 FROM user_blocks WHERE (blocker_id = ? AND blocked_id = u.id) OR (blocker_id = u.id AND blocked_id = ?)) " +
                    "    THEN 'BLOCKED' " +
                    "  WHEN EXISTS (SELECT 1 FROM friend_requests WHERE (from_user_id = ? AND to_user_id = u.id) OR (from_user_id = u.id AND to_user_id = ?)) " +
                    "    THEN 'PENDING' " +
                    "  ELSE 'NONE' " +
                    "END as relationship_status " +
                    "FROM users u " +
                    "WHERE u.id != ? " +
                    "  AND u.status = 'ACTIVE' " +
                    "  AND NOT EXISTS (SELECT 1 FROM friendships WHERE state = 'ACTIVE' AND ((user_id_a = ? AND user_id_b = u.id) OR (user_id_a = u.id AND user_id_b = ?))) " +
                    "  AND (u.display_name LIKE ? OR u.email LIKE ?) " +
                    "ORDER BY u.display_name ASC " +
                    "LIMIT ? OFFSET ?";

            Connection conn = com.study.Db.get();
            PreparedStatement ps = conn.prepareStatement(sql);

            String qLike = "%" + q + "%";
            int paramIdx = 1;
            ps.setLong(paramIdx++, userId);
            ps.setLong(paramIdx++, userId);
            ps.setLong(paramIdx++, userId);
            ps.setLong(paramIdx++, userId);
            ps.setLong(paramIdx++, userId);
            ps.setLong(paramIdx++, userId);
            ps.setLong(paramIdx++, userId);
            ps.setString(paramIdx++, qLike);
            ps.setString(paramIdx++, qLike);
            ps.setInt(paramIdx++, limit);
            ps.setInt(paramIdx, offset);

            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                users.add(new DiscoverUserDto(
                        rs.getLong("id"),
                        rs.getString("email"),
                        rs.getString("display_name"),
                        rs.getString("relationship_status")
                ));
            }

            rs.close();
            ps.close();
            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "data", users,
                    "total", users.size()
            )).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(500)
                    .entity(new ErrorResponse(false, "Database error: " + e.getMessage()))
                    .build();
        } catch (Exception e) {
            e.printStackTrace();
            return Response.status(500)
                    .entity(new ErrorResponse(false, "Unexpected error: " + e.getMessage()))
                    .build();
        }
    }

    /**
     * GET /api/find-friends/online
     * Lấy danh sách user online/active gần đây (optional)
     */
    @GET
    @Path("/online")
    public Response getOnlineUsers(
            @QueryParam("limit") @DefaultValue("20") int limit,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            limit = Math.min(limit, 100);

            List<UserDto> onlineUsers = new ArrayList<>();

            // Ví dụ: lấy users có session gần đây
            String sql = "SELECT DISTINCT u.id, u.email, u.display_name " +
                    "FROM user_sessions us " +
                    "JOIN users u ON u.id = us.user_id " +
                    "WHERE u.id != ? AND u.status = 'ACTIVE' " +
                    "  AND us.revoked_at IS NULL " +
                    "  AND us.created_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE) " +
                    "  AND NOT EXISTS (SELECT 1 FROM friendships WHERE state = 'ACTIVE' AND ((user_id_a = ? AND user_id_b = u.id) OR (user_id_a = u.id AND user_id_b = ?))) " +
                    "  AND NOT EXISTS (SELECT 1 FROM user_blocks WHERE (blocker_id = ? AND blocked_id = u.id) OR (blocker_id = u.id AND blocked_id = ?)) " +
                    "ORDER BY us.created_at DESC " +
                    "LIMIT ?";

            Connection conn = com.study.Db.get();
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setLong(1, userId);
            ps.setLong(2, userId);
            ps.setLong(3, userId);
            ps.setLong(4, userId);
            ps.setLong(5, userId);
            ps.setInt(6, limit);

            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                onlineUsers.add(new UserDto(
                        rs.getLong("id"),
                        rs.getString("email"),
                        rs.getString("display_name")
                ));
            }

            rs.close();
            ps.close();
            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "data", onlineUsers,
                    "total", onlineUsers.size()
            )).build();

        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(500)
                    .entity(new ErrorResponse(false, "Database error: " + e.getMessage()))
                    .build();
        } catch (Exception e) {
            e.printStackTrace();
            return Response.status(500)
                    .entity(new ErrorResponse(false, "Unexpected error: " + e.getMessage()))
                    .build();
        }
    }
}
