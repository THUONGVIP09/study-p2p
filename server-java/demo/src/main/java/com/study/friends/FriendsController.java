package com.study.friends;

import com.study.dto.UserDto;
import com.study.dto.ErrorResponse;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

@Path("/api/friends")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class FriendsController {

    /**
     * GET /api/friends?q=search_query&limit=50&offset=0
     * Lấy danh sách bạn bè của user hiện tại (từ context/token)
     * Tạm thời: lấy friends của user_id=1 (hardcode để test)
     */
    @GET
    public Response listFriends(
            @QueryParam("q") @DefaultValue("") String q,
            @QueryParam("limit") @DefaultValue("50") int limit,
            @QueryParam("offset") @DefaultValue("0") int offset,
            @HeaderParam("Authorization") String token) {

        try {
            // TODO: Parse token để lấy userId thật; tạm dùng userId=1
            long userId = 1;

            // Validate input
            limit = Math.min(limit, 100);
            if (offset < 0) offset = 0;

            List<UserDto> friends = new ArrayList<>();

            String sql = "SELECT u.id, u.email, u.display_name " +
                    "FROM friendships f " +
                    "JOIN users u ON (u.id = f.user_id_b AND f.user_id_a = ?) " +
                    "    OR (u.id = f.user_id_a AND f.user_id_b = ?) " +
                    "WHERE f.state = 'ACTIVE' " +
                    (q.isEmpty() ? "" : "AND (u.display_name LIKE ? OR u.email LIKE ?) ") +
                    "LIMIT ? OFFSET ?";

            Connection conn = com.study.Db.get();
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setLong(1, userId);
            ps.setLong(2, userId);

            int paramIdx = 3;
            if (!q.isEmpty()) {
                String qLike = "%" + q + "%";
                ps.setString(paramIdx++, qLike);
                ps.setString(paramIdx++, qLike);
            }
            ps.setInt(paramIdx++, limit);
            ps.setInt(paramIdx, offset);

            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                friends.add(new UserDto(
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
                    "data", friends,
                    "total", friends.size()
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
     * GET /api/friends/{userId}
     * Lấy chi tiết một bạn bè
     */
    @GET
    @Path("/{userId}")
    public Response getFriend(
            @PathParam("userId") long friendId,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            // Kiểm tra xem có phải bạn bè không
            String sql = "SELECT u.id, u.email, u.display_name FROM users u " +
                    "WHERE u.id = ? AND EXISTS (" +
                    "  SELECT 1 FROM friendships f WHERE f.state = 'ACTIVE' " +
                    "  AND ((f.user_id_a = ? AND f.user_id_b = ?) OR (f.user_id_a = ? AND f.user_id_b = ?))" +
                    ")";

            Connection conn = com.study.Db.get();
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setLong(1, friendId);
            ps.setLong(2, userId);
            ps.setLong(3, friendId);
            ps.setLong(4, userId);
            ps.setLong(5, friendId);

            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                UserDto user = new UserDto(
                        rs.getLong("id"),
                        rs.getString("email"),
                        rs.getString("display_name")
                );
                rs.close();
                ps.close();
                conn.close();
                return Response.ok(Map.of("success", true, "data", user)).build();
            }

            rs.close();
            ps.close();
            conn.close();
            return Response.status(404)
                    .entity(new ErrorResponse(false, "Friend not found or not your friend"))
                    .build();

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
     * DELETE /api/friends/{userId}
     * Xóa bạn bè (Remove Friend)
     * Frontend nên hiển thị dialog xác nhận trước khi gọi endpoint này
     */
    @DELETE
    @Path("/{userId}")
    public Response removeFriend(
            @PathParam("userId") long friendId,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            if (userId == friendId) {
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Cannot remove yourself"))
                        .build();
            }

            Connection conn = com.study.Db.get();

            // Kiểm tra xem có phải bạn bè không
            String checkSql = "SELECT id FROM friendships WHERE state = 'ACTIVE' " +
                    "AND ((user_id_a = ? AND user_id_b = ?) OR (user_id_a = ? AND user_id_b = ?))";
            PreparedStatement checkPs = conn.prepareStatement(checkSql);
            checkPs.setLong(1, Math.min(userId, friendId));
            checkPs.setLong(2, Math.max(userId, friendId));
            checkPs.setLong(3, Math.max(userId, friendId));
            checkPs.setLong(4, Math.min(userId, friendId));
            ResultSet rs = checkPs.executeQuery();

            if (!rs.next()) {
                rs.close();
                checkPs.close();
                conn.close();
                return Response.status(404)
                        .entity(new ErrorResponse(false, "Friendship not found"))
                        .build();
            }
            rs.close();
            checkPs.close();

            // Xóa friendship
            String deleteSql = "DELETE FROM friendships WHERE state = 'ACTIVE' " +
                    "AND ((user_id_a = ? AND user_id_b = ?) OR (user_id_a = ? AND user_id_b = ?))";
            PreparedStatement deletePs = conn.prepareStatement(deleteSql);
            deletePs.setLong(1, Math.min(userId, friendId));
            deletePs.setLong(2, Math.max(userId, friendId));
            deletePs.setLong(3, Math.max(userId, friendId));
            deletePs.setLong(4, Math.min(userId, friendId));
            int rowsDeleted = deletePs.executeUpdate();
            deletePs.close();

            conn.close();

            if (rowsDeleted > 0) {
                return Response.ok(Map.of(
                        "success", true,
                        "message", "Friend removed successfully"
                )).build();
            } else {
                return Response.status(500)
                        .entity(new ErrorResponse(false, "Failed to remove friend"))
                        .build();
            }

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
