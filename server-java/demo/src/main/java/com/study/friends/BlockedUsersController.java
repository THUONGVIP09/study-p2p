package com.study.friends;

import com.study.dto.BlockedUserDto;
import com.study.dto.ErrorResponse;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

@Path("/api/blocked-users")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class BlockedUsersController {

    /**
     * GET /api/blocked-users?q=search&limit=50&offset=0
     * Lấy danh sách những user mà current user đã block
     */
    @GET
    public Response listBlockedUsers(
            @QueryParam("q") @DefaultValue("") String q,
            @QueryParam("limit") @DefaultValue("50") int limit,
            @QueryParam("offset") @DefaultValue("0") int offset,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            limit = Math.min(limit, 100);
            if (offset < 0) offset = 0;

            List<BlockedUserDto> blockedUsers = new ArrayList<>();

            String sql = "SELECT u.id, u.email, u.display_name, ub.created_at " +
                    "FROM user_blocks ub " +
                    "JOIN users u ON u.id = ub.blocked_id " +
                    "WHERE ub.blocker_id = ? " +
                    (q.isEmpty() ? "" : "AND (u.display_name LIKE ? OR u.email LIKE ?) ") +
                    "ORDER BY ub.created_at DESC " +
                    "LIMIT ? OFFSET ?";

            Connection conn = com.study.Db.get();
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setLong(1, userId);

            int paramIdx = 2;
            if (!q.isEmpty()) {
                String qLike = "%" + q + "%";
                ps.setString(paramIdx++, qLike);
                ps.setString(paramIdx++, qLike);
            }
            ps.setInt(paramIdx++, limit);
            ps.setInt(paramIdx, offset);

            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                blockedUsers.add(new BlockedUserDto(
                        rs.getLong("id"),
                        rs.getString("email"),
                        rs.getString("display_name"),
                        rs.getString("created_at")
                ));
            }

            rs.close();
            ps.close();
            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "data", blockedUsers,
                    "total", blockedUsers.size()
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
     * GET /api/blocked-users/blocking-me
     * Lấy danh sách những user đã block current user
     */
    @GET
    @Path("/blocking-me")
    public Response listUsersBlockingMe(
            @QueryParam("q") @DefaultValue("") String q,
            @QueryParam("limit") @DefaultValue("50") int limit,
            @QueryParam("offset") @DefaultValue("0") int offset,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            limit = Math.min(limit, 100);
            if (offset < 0) offset = 0;

            List<BlockedUserDto> blockedBy = new ArrayList<>();

            String sql = "SELECT u.id, u.email, u.display_name, ub.created_at " +
                    "FROM user_blocks ub " +
                    "JOIN users u ON u.id = ub.blocker_id " +
                    "WHERE ub.blocked_id = ? " +
                    (q.isEmpty() ? "" : "AND (u.display_name LIKE ? OR u.email LIKE ?) ") +
                    "ORDER BY ub.created_at DESC " +
                    "LIMIT ? OFFSET ?";

            Connection conn = com.study.Db.get();
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setLong(1, userId);

            int paramIdx = 2;
            if (!q.isEmpty()) {
                String qLike = "%" + q + "%";
                ps.setString(paramIdx++, qLike);
                ps.setString(paramIdx++, qLike);
            }
            ps.setInt(paramIdx++, limit);
            ps.setInt(paramIdx, offset);

            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                blockedBy.add(new BlockedUserDto(
                        rs.getLong("id"),
                        rs.getString("email"),
                        rs.getString("display_name"),
                        rs.getString("created_at")
                ));
            }

            rs.close();
            ps.close();
            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "data", blockedBy,
                    "total", blockedBy.size()
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
     * POST /api/blocked-users
     * Block một user
     * Body: { "blockedUserId": 2 }
     * Frontend nên hiển thị dialog xác nhận trước khi gọi endpoint này
     */
    @POST
    public Response blockUser(
            Map<String, Object> requestBody,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            if (requestBody == null || !requestBody.containsKey("blockedUserId")) {
                return Response.status(400)
                        .entity(new ErrorResponse(false, "blockedUserId is required"))
                        .build();
            }

            long blockedUserId = ((Number) requestBody.get("blockedUserId")).longValue();

            if (userId == blockedUserId) {
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Cannot block yourself"))
                        .build();
            }

            Connection conn = com.study.Db.get();

            // Kiểm tra xem user tồn tại không
            String checkUserSql = "SELECT id FROM users WHERE id = ? AND status = 'ACTIVE'";
            PreparedStatement checkUserPs = conn.prepareStatement(checkUserSql);
            checkUserPs.setLong(1, blockedUserId);
            ResultSet userRs = checkUserPs.executeQuery();
            
            if (!userRs.next()) {
                userRs.close();
                checkUserPs.close();
                conn.close();
                return Response.status(404)
                        .entity(new ErrorResponse(false, "User not found"))
                        .build();
            }
            userRs.close();
            checkUserPs.close();

            // Kiểm tra xem đã block chưa
            String checkBlockSql = "SELECT id FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?";
            PreparedStatement checkBlockPs = conn.prepareStatement(checkBlockSql);
            checkBlockPs.setLong(1, userId);
            checkBlockPs.setLong(2, blockedUserId);
            ResultSet blockRs = checkBlockPs.executeQuery();
            
            if (blockRs.next()) {
                blockRs.close();
                checkBlockPs.close();
                conn.close();
                return Response.status(400)
                        .entity(new ErrorResponse(false, "User is already blocked"))
                        .build();
            }
            blockRs.close();
            checkBlockPs.close();

            // Xóa friendship nếu tồn tại
            String deleteFriendshipSql = "DELETE FROM friendships " +
                    "WHERE ((user_id_a = ? AND user_id_b = ?) OR (user_id_a = ? AND user_id_b = ?))";
            PreparedStatement deleteFriendshipPs = conn.prepareStatement(deleteFriendshipSql);
            deleteFriendshipPs.setLong(1, Math.min(userId, blockedUserId));
            deleteFriendshipPs.setLong(2, Math.max(userId, blockedUserId));
            deleteFriendshipPs.setLong(3, Math.max(userId, blockedUserId));
            deleteFriendshipPs.setLong(4, Math.min(userId, blockedUserId));
            deleteFriendshipPs.executeUpdate();
            deleteFriendshipPs.close();

            // Xóa friend requests liên quan
            String deleteRequestsSql = "DELETE FROM friend_requests " +
                    "WHERE (from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?)";
            PreparedStatement deleteRequestsPs = conn.prepareStatement(deleteRequestsSql);
            deleteRequestsPs.setLong(1, userId);
            deleteRequestsPs.setLong(2, blockedUserId);
            deleteRequestsPs.setLong(3, blockedUserId);
            deleteRequestsPs.setLong(4, userId);
            deleteRequestsPs.executeUpdate();
            deleteRequestsPs.close();

            // Tạo user_block
            String insertSql = "INSERT INTO user_blocks (blocker_id, blocked_id, created_at) VALUES (?, ?, NOW())";
            PreparedStatement insertPs = conn.prepareStatement(insertSql);
            insertPs.setLong(1, userId);
            insertPs.setLong(2, blockedUserId);
            insertPs.executeUpdate();
            insertPs.close();

            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "message", "User blocked successfully"
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
     * DELETE /api/blocked-users/{userId}
     * Unblock một user (gỡ block)
     */
    @DELETE
    @Path("/{userId}")
    public Response unblockUser(
            @PathParam("userId") long blockedUserId,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            if (userId == blockedUserId) {
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Invalid operation"))
                        .build();
            }

            Connection conn = com.study.Db.get();

            // Kiểm tra xem đã block chưa
            String checkSql = "SELECT id FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?";
            PreparedStatement checkPs = conn.prepareStatement(checkSql);
            checkPs.setLong(1, userId);
            checkPs.setLong(2, blockedUserId);
            ResultSet rs = checkPs.executeQuery();

            if (!rs.next()) {
                rs.close();
                checkPs.close();
                conn.close();
                return Response.status(404)
                        .entity(new ErrorResponse(false, "Block not found"))
                        .build();
            }
            rs.close();
            checkPs.close();

            // Xóa block
            String deleteSql = "DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?";
            PreparedStatement deletePs = conn.prepareStatement(deleteSql);
            deletePs.setLong(1, userId);
            deletePs.setLong(2, blockedUserId);
            int rowsDeleted = deletePs.executeUpdate();
            deletePs.close();

            conn.close();

            if (rowsDeleted > 0) {
                return Response.ok(Map.of(
                        "success", true,
                        "message", "User unblocked successfully"
                )).build();
            } else {
                return Response.status(500)
                        .entity(new ErrorResponse(false, "Failed to unblock user"))
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
