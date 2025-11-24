package com.study.friends;

import com.study.dto.FriendRequestDto;
import com.study.dto.ErrorResponse;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

@Path("/api/friend-requests")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class FriendRequestsController {

    /**
     * GET /api/friend-requests?status=PENDING&q=search&limit=50&offset=0
     * Lấy danh sách friend requests (mặc định: pending requests TO current user)
     */
    @GET
    public Response listRequests(
            @QueryParam("status") @DefaultValue("PENDING") String status,
            @QueryParam("q") @DefaultValue("") String q,
            @QueryParam("limit") @DefaultValue("50") int limit,
            @QueryParam("offset") @DefaultValue("0") int offset,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            // Validate input
            limit = Math.min(limit, 100);
            if (offset < 0) offset = 0;

            // Chỉ cho phép các status hợp lệ
            if (!Arrays.asList("PENDING", "ACCEPTED", "REJECTED", "CANCELED").contains(status.toUpperCase())) {
                status = "PENDING";
            }

            List<FriendRequestDto> requests = new ArrayList<>();

            String sql = "SELECT fr.id, fr.from_user_id, u.display_name, fr.status, fr.created_at " +
                    "FROM friend_requests fr " +
                    "JOIN users u ON u.id = fr.from_user_id " +
                    "WHERE fr.to_user_id = ? AND fr.status = ? " +
                    (q.isEmpty() ? "" : "AND (u.display_name LIKE ? OR u.email LIKE ?) ") +
                    "ORDER BY fr.created_at DESC " +
                    "LIMIT ? OFFSET ?";

            Connection conn = com.study.Db.get();
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setLong(1, userId);
            ps.setString(2, status.toUpperCase());

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
                requests.add(new FriendRequestDto(
                        rs.getLong("id"),
                        rs.getLong("from_user_id"),
                        rs.getString("display_name"),
                        rs.getString("status"),
                        rs.getString("created_at")
                ));
            }

            rs.close();
            ps.close();
            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "data", requests,
                    "total", requests.size()
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
     * GET /api/friend-requests/sent?q=search&limit=50&offset=0
     * Lấy danh sách friend requests đã gửi
     */
    @GET
    @Path("/sent")
    public Response listSentRequests(
            @QueryParam("q") @DefaultValue("") String q,
            @QueryParam("limit") @DefaultValue("50") int limit,
            @QueryParam("offset") @DefaultValue("0") int offset,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            limit = Math.min(limit, 100);
            if (offset < 0) offset = 0;

            List<FriendRequestDto> requests = new ArrayList<>();

            String sql = "SELECT fr.id, fr.to_user_id as from_user_id, u.display_name, fr.status, fr.created_at " +
                    "FROM friend_requests fr " +
                    "JOIN users u ON u.id = fr.to_user_id " +
                    "WHERE fr.from_user_id = ? " +
                    (q.isEmpty() ? "" : "AND (u.display_name LIKE ? OR u.email LIKE ?) ") +
                    "ORDER BY fr.created_at DESC " +
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
                requests.add(new FriendRequestDto(
                        rs.getLong("id"),
                        rs.getLong("from_user_id"),
                        rs.getString("display_name"),
                        rs.getString("status"),
                        rs.getString("created_at")
                ));
            }

            rs.close();
            ps.close();
            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "data", requests,
                    "total", requests.size()
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
     * POST /api/friend-requests
     * Gửi lời mời kết bạn (Add Friend)
     * Body: { "toUserId": 2 }
     */
    @POST
    public Response sendFriendRequest(
            Map<String, Object> requestBody,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            if (requestBody == null || !requestBody.containsKey("toUserId")) {
                return Response.status(400)
                        .entity(new ErrorResponse(false, "toUserId is required"))
                        .build();
            }

            long toUserId = ((Number) requestBody.get("toUserId")).longValue();

            if (userId == toUserId) {
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Cannot send friend request to yourself"))
                        .build();
            }

            Connection conn = com.study.Db.get();

            // Kiểm tra xem user tồn tại không
            String checkUserSql = "SELECT id FROM users WHERE id = ? AND status = 'ACTIVE'";
            PreparedStatement checkUserPs = conn.prepareStatement(checkUserSql);
            checkUserPs.setLong(1, toUserId);
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

            // Kiểm tra xem đã là bạn bè chưa
            String checkFriendSql = "SELECT id FROM friendships WHERE state = 'ACTIVE' " +
                    "AND ((user_id_a = ? AND user_id_b = ?) OR (user_id_a = ? AND user_id_b = ?))";
            PreparedStatement checkFriendPs = conn.prepareStatement(checkFriendSql);
            checkFriendPs.setLong(1, userId);
            checkFriendPs.setLong(2, toUserId);
            checkFriendPs.setLong(3, toUserId);
            checkFriendPs.setLong(4, userId);
            ResultSet friendRs = checkFriendPs.executeQuery();
            
            if (friendRs.next()) {
                friendRs.close();
                checkFriendPs.close();
                conn.close();
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Already friends with this user"))
                        .build();
            }
            friendRs.close();
            checkFriendPs.close();

            // Kiểm tra xem đã gửi request chưa
            String checkRequestSql = "SELECT id, status FROM friend_requests " +
                    "WHERE ((from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?))";
            PreparedStatement checkRequestPs = conn.prepareStatement(checkRequestSql);
            checkRequestPs.setLong(1, userId);
            checkRequestPs.setLong(2, toUserId);
            checkRequestPs.setLong(3, toUserId);
            checkRequestPs.setLong(4, userId);
            ResultSet requestRs = checkRequestPs.executeQuery();
            
            if (requestRs.next()) {
                String status = requestRs.getString("status");
                requestRs.close();
                checkRequestPs.close();
                conn.close();
                
                if ("PENDING".equals(status)) {
                    return Response.status(400)
                            .entity(new ErrorResponse(false, "Friend request already exists"))
                            .build();
                } else {
                    return Response.status(400)
                            .entity(new ErrorResponse(false, "A friend request already exists with status: " + status))
                            .build();
                }
            }
            requestRs.close();
            checkRequestPs.close();

            // Kiểm tra xem có bị block không
            String checkBlockSql = "SELECT id FROM user_blocks " +
                    "WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)";
            PreparedStatement checkBlockPs = conn.prepareStatement(checkBlockSql);
            checkBlockPs.setLong(1, userId);
            checkBlockPs.setLong(2, toUserId);
            checkBlockPs.setLong(3, toUserId);
            checkBlockPs.setLong(4, userId);
            ResultSet blockRs = checkBlockPs.executeQuery();
            
            if (blockRs.next()) {
                blockRs.close();
                checkBlockPs.close();
                conn.close();
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Cannot send friend request due to block"))
                        .build();
            }
            blockRs.close();
            checkBlockPs.close();

            // Tạo friend request mới
            String insertSql = "INSERT INTO friend_requests (from_user_id, to_user_id, status, created_at) " +
                    "VALUES (?, ?, 'PENDING', NOW())";
            PreparedStatement insertPs = conn.prepareStatement(insertSql, Statement.RETURN_GENERATED_KEYS);
            insertPs.setLong(1, userId);
            insertPs.setLong(2, toUserId);
            insertPs.executeUpdate();

            ResultSet generatedKeys = insertPs.getGeneratedKeys();
            long requestId = 0;
            if (generatedKeys.next()) {
                requestId = generatedKeys.getLong(1);
            }
            generatedKeys.close();
            insertPs.close();
            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "message", "Friend request sent successfully",
                    "requestId", requestId
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
     * POST /api/friend-requests/{requestId}/accept
     * Chấp nhận lời mời kết bạn
     */
    @POST
    @Path("/{requestId}/accept")
    public Response acceptFriendRequest(
            @PathParam("requestId") long requestId,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            Connection conn = com.study.Db.get();

            // Kiểm tra request tồn tại và là PENDING
            String checkSql = "SELECT from_user_id, to_user_id, status FROM friend_requests WHERE id = ?";
            PreparedStatement checkPs = conn.prepareStatement(checkSql);
            checkPs.setLong(1, requestId);
            ResultSet rs = checkPs.executeQuery();

            if (!rs.next()) {
                rs.close();
                checkPs.close();
                conn.close();
                return Response.status(404)
                        .entity(new ErrorResponse(false, "Friend request not found"))
                        .build();
            }

            long fromUserId = rs.getLong("from_user_id");
            long toUserId = rs.getLong("to_user_id");
            String status = rs.getString("status");
            rs.close();
            checkPs.close();

            // Kiểm tra quyền (chỉ người nhận mới accept được)
            if (toUserId != userId) {
                conn.close();
                return Response.status(403)
                        .entity(new ErrorResponse(false, "You are not authorized to accept this request"))
                        .build();
            }

            if (!"PENDING".equals(status)) {
                conn.close();
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Friend request is not pending (status: " + status + ")"))
                        .build();
            }

            // Update request status
            String updateSql = "UPDATE friend_requests SET status = 'ACCEPTED', updated_at = NOW() WHERE id = ?";
            PreparedStatement updatePs = conn.prepareStatement(updateSql);
            updatePs.setLong(1, requestId);
            updatePs.executeUpdate();
            updatePs.close();

            // Tạo friendship
            String insertSql = "INSERT INTO friendships (user_id_a, user_id_b, state, created_at) " +
                    "VALUES (?, ?, 'ACTIVE', NOW())";
            PreparedStatement insertPs = conn.prepareStatement(insertSql);
            insertPs.setLong(1, Math.min(fromUserId, toUserId));
            insertPs.setLong(2, Math.max(fromUserId, toUserId));
            insertPs.executeUpdate();
            insertPs.close();

            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "message", "Friend request accepted successfully"
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
     * POST /api/friend-requests/{requestId}/reject
     * Từ chối lời mời kết bạn
     */
    @POST
    @Path("/{requestId}/reject")
    public Response rejectFriendRequest(
            @PathParam("requestId") long requestId,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            Connection conn = com.study.Db.get();

            // Kiểm tra request tồn tại và là PENDING
            String checkSql = "SELECT from_user_id, to_user_id, status FROM friend_requests WHERE id = ?";
            PreparedStatement checkPs = conn.prepareStatement(checkSql);
            checkPs.setLong(1, requestId);
            ResultSet rs = checkPs.executeQuery();

            if (!rs.next()) {
                rs.close();
                checkPs.close();
                conn.close();
                return Response.status(404)
                        .entity(new ErrorResponse(false, "Friend request not found"))
                        .build();
            }

            long toUserId = rs.getLong("to_user_id");
            String status = rs.getString("status");
            rs.close();
            checkPs.close();

            // Kiểm tra quyền (chỉ người nhận mới reject được)
            if (toUserId != userId) {
                conn.close();
                return Response.status(403)
                        .entity(new ErrorResponse(false, "You are not authorized to reject this request"))
                        .build();
            }

            if (!"PENDING".equals(status)) {
                conn.close();
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Friend request is not pending (status: " + status + ")"))
                        .build();
            }

            // Update request status
            String updateSql = "UPDATE friend_requests SET status = 'REJECTED', updated_at = NOW() WHERE id = ?";
            PreparedStatement updatePs = conn.prepareStatement(updateSql);
            updatePs.setLong(1, requestId);
            updatePs.executeUpdate();
            updatePs.close();

            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "message", "Friend request rejected successfully"
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
     * DELETE /api/friend-requests/{requestId}
     * Hủy lời mời kết bạn đã gửi (Cancel)
     */
    @DELETE
    @Path("/{requestId}")
    public Response cancelFriendRequest(
            @PathParam("requestId") long requestId,
            @HeaderParam("Authorization") String token) {

        try {
            long userId = 1; // TODO: từ token

            Connection conn = com.study.Db.get();

            // Kiểm tra request tồn tại và là PENDING
            String checkSql = "SELECT from_user_id, status FROM friend_requests WHERE id = ?";
            PreparedStatement checkPs = conn.prepareStatement(checkSql);
            checkPs.setLong(1, requestId);
            ResultSet rs = checkPs.executeQuery();

            if (!rs.next()) {
                rs.close();
                checkPs.close();
                conn.close();
                return Response.status(404)
                        .entity(new ErrorResponse(false, "Friend request not found"))
                        .build();
            }

            long fromUserId = rs.getLong("from_user_id");
            String status = rs.getString("status");
            rs.close();
            checkPs.close();

            // Kiểm tra quyền (chỉ người gửi mới cancel được)
            if (fromUserId != userId) {
                conn.close();
                return Response.status(403)
                        .entity(new ErrorResponse(false, "You are not authorized to cancel this request"))
                        .build();
            }

            if (!"PENDING".equals(status)) {
                conn.close();
                return Response.status(400)
                        .entity(new ErrorResponse(false, "Can only cancel pending requests (current status: " + status + ")"))
                        .build();
            }

            // Update request status to CANCELED
            String updateSql = "UPDATE friend_requests SET status = 'CANCELED', updated_at = NOW() WHERE id = ?";
            PreparedStatement updatePs = conn.prepareStatement(updateSql);
            updatePs.setLong(1, requestId);
            updatePs.executeUpdate();
            updatePs.close();

            conn.close();

            return Response.ok(Map.of(
                    "success", true,
                    "message", "Friend request canceled successfully"
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
