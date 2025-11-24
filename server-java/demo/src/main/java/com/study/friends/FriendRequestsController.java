package com.study.friends;

import com.study.AuthUtil;
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
            // Parse token to get actual userId
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

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

            try (Connection conn = com.study.Db.get();
                 PreparedStatement ps = conn.prepareStatement(sql)) {
                
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

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        requests.add(new FriendRequestDto(
                                rs.getLong("id"),
                                rs.getLong("from_user_id"),
                                rs.getString("display_name"),
                                rs.getString("status"),
                                rs.getString("created_at")
                        ));
                    }
                }
            }

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
            // Parse token to get actual userId
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

            limit = Math.min(limit, 100);
            if (offset < 0) offset = 0;

            List<FriendRequestDto> requests = new ArrayList<>();

            // For sent requests: retrieve recipient (to_user) information
            // Note: FriendRequestDto fields are named "fromUser" but for sent requests,
            // we populate them with recipient data (the user TO whom request was sent)
            String sql = "SELECT fr.id, fr.to_user_id, u.display_name, fr.status, fr.created_at " +
                    "FROM friend_requests fr " +
                    "JOIN users u ON u.id = fr.to_user_id " +
                    "WHERE fr.from_user_id = ? " +
                    (q.isEmpty() ? "" : "AND (u.display_name LIKE ? OR u.email LIKE ?) ") +
                    "ORDER BY fr.created_at DESC " +
                    "LIMIT ? OFFSET ?";

            try (Connection conn = com.study.Db.get();
                 PreparedStatement ps = conn.prepareStatement(sql)) {
                
                ps.setLong(1, userId);

                int paramIdx = 2;
                if (!q.isEmpty()) {
                    String qLike = "%" + q + "%";
                    ps.setString(paramIdx++, qLike);
                    ps.setString(paramIdx++, qLike);
                }
                ps.setInt(paramIdx++, limit);
                ps.setInt(paramIdx, offset);

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        requests.add(new FriendRequestDto(
                                rs.getLong("id"),
                                rs.getLong("to_user_id"),
                                rs.getString("display_name"),
                                rs.getString("status"),
                                rs.getString("created_at")
                        ));
                    }
                }
            }

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
            // Parse token to get actual userId
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

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

            try (Connection conn = com.study.Db.get()) {
                conn.setAutoCommit(false);
                
                try {
                    // Kiểm tra xem user tồn tại không
                    String checkUserSql = "SELECT id FROM users WHERE id = ? AND status = 'ACTIVE'";
                    try (PreparedStatement checkUserPs = conn.prepareStatement(checkUserSql)) {
                        checkUserPs.setLong(1, toUserId);
                        try (ResultSet userRs = checkUserPs.executeQuery()) {
                            if (!userRs.next()) {
                                return Response.status(404)
                                        .entity(new ErrorResponse(false, "User not found"))
                                        .build();
                            }
                        }
                    }

                    // Kiểm tra xem đã là bạn bè chưa
                        String checkFriendSql = "SELECT 1 FROM friendships WHERE state = 'ACTIVE' " +
                            "AND ((user_id_a = ? AND user_id_b = ?) OR (user_id_a = ? AND user_id_b = ?))";
                    try (PreparedStatement checkFriendPs = conn.prepareStatement(checkFriendSql)) {
                        checkFriendPs.setLong(1, userId);
                        checkFriendPs.setLong(2, toUserId);
                        checkFriendPs.setLong(3, toUserId);
                        checkFriendPs.setLong(4, userId);
                        try (ResultSet friendRs = checkFriendPs.executeQuery()) {
                            if (friendRs.next()) {
                                return Response.status(400)
                                        .entity(new ErrorResponse(false, "Already friends with this user"))
                                        .build();
                            }
                        }
                    }

                    // Kiểm tra xem có bị block không
                        String checkBlockSql = "SELECT 1 FROM user_blocks " +
                            "WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)";
                    try (PreparedStatement checkBlockPs = conn.prepareStatement(checkBlockSql)) {
                        checkBlockPs.setLong(1, userId);
                        checkBlockPs.setLong(2, toUserId);
                        checkBlockPs.setLong(3, toUserId);
                        checkBlockPs.setLong(4, userId);
                        try (ResultSet blockRs = checkBlockPs.executeQuery()) {
                            if (blockRs.next()) {
                                return Response.status(400)
                                        .entity(new ErrorResponse(false, "Cannot send friend request due to block"))
                                        .build();
                            }
                        }
                    }

                    // Kiểm tra xem đã gửi request chưa
                    String checkRequestSql = "SELECT id, status, from_user_id, to_user_id FROM friend_requests " +
                            "WHERE ((from_user_id = ? AND to_user_id = ?) OR (from_user_id = ? AND to_user_id = ?))";
                    try (PreparedStatement checkRequestPs = conn.prepareStatement(checkRequestSql)) {
                        checkRequestPs.setLong(1, userId);
                        checkRequestPs.setLong(2, toUserId);
                        checkRequestPs.setLong(3, toUserId);
                        checkRequestPs.setLong(4, userId);
                        try (ResultSet requestRs = checkRequestPs.executeQuery()) {
                            if (requestRs.next()) {
                                String status = requestRs.getString("status");
                                
                                if ("PENDING".equals(status)) {
                                    return Response.status(400)
                                            .entity(new ErrorResponse(false, "Friend request already exists"))
                                            .build();
                                } else if ("REJECTED".equals(status) || "CANCELED".equals(status)) {
                                    // Allow re-sending after REJECTED/CANCELED by updating existing request to PENDING
                                    // Only update status and timestamps, keep original from_user_id and to_user_id
                                    long requestId = requestRs.getLong("id");
                                    long existingFromUserId = requestRs.getLong("from_user_id");
                                    long existingToUserId = requestRs.getLong("to_user_id");
                                    
                                    // Check if current user was involved in the original request
                                    if (existingFromUserId != userId && existingToUserId != userId) {
                                        return Response.status(400)
                                                .entity(new ErrorResponse(false, "Cannot re-send someone else's friend request"))
                                                .build();
                                    }
                                    
                                    // Update to PENDING, keeping original created_at
                                    String updateSql = "UPDATE friend_requests SET status = 'PENDING' WHERE id = ?";
                                    try (PreparedStatement updatePs = conn.prepareStatement(updateSql)) {
                                        updatePs.setLong(1, requestId);
                                        updatePs.executeUpdate();
                                    }
                                    
                                    conn.commit();
                                    return Response.ok(Map.of(
                                            "success", true,
                                            "message", "Friend request re-sent successfully",
                                            "requestId", requestId
                                    )).build();
                                } else {
                                    // ACCEPTED status
                                    return Response.status(400)
                                            .entity(new ErrorResponse(false, "A friend request already exists with status: " + status))
                                            .build();
                                }
                            }
                        }
                    }

                    // Tạo friend request mới
                    String insertSql = "INSERT INTO friend_requests (from_user_id, to_user_id, status, created_at) " +
                            "VALUES (?, ?, 'PENDING', NOW())";
                    long requestId;
                    try (PreparedStatement insertPs = conn.prepareStatement(insertSql, Statement.RETURN_GENERATED_KEYS)) {
                        insertPs.setLong(1, userId);
                        insertPs.setLong(2, toUserId);
                        insertPs.executeUpdate();

                        try (ResultSet generatedKeys = insertPs.getGeneratedKeys()) {
                            if (generatedKeys.next()) {
                                requestId = generatedKeys.getLong(1);
                            } else {
                                throw new SQLException("Failed to get generated key for friend request");
                            }
                        }
                    }

                    conn.commit();
                    return Response.ok(Map.of(
                            "success", true,
                            "message", "Friend request sent successfully",
                            "requestId", requestId
                    )).build();
                    
                } catch (SQLException e) {
                    conn.rollback();
                    throw e;
                }
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
            // Parse token to get actual userId
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

            try (Connection conn = com.study.Db.get()) {
                conn.setAutoCommit(false);
                
                try {
                    // Kiểm tra request tồn tại và là PENDING
                    String checkSql = "SELECT from_user_id, to_user_id, status FROM friend_requests WHERE id = ?";
                    long fromUserId;
                    long toUserId;
                    String status;
                    
                    try (PreparedStatement checkPs = conn.prepareStatement(checkSql)) {
                        checkPs.setLong(1, requestId);
                        try (ResultSet rs = checkPs.executeQuery()) {
                            if (!rs.next()) {
                                return Response.status(404)
                                        .entity(new ErrorResponse(false, "Friend request not found"))
                                        .build();
                            }
                            fromUserId = rs.getLong("from_user_id");
                            toUserId = rs.getLong("to_user_id");
                            status = rs.getString("status");
                        }
                    }

                    // Kiểm tra quyền (chỉ người nhận mới accept được)
                    if (toUserId != userId) {
                        return Response.status(403)
                                .entity(new ErrorResponse(false, "You are not authorized to accept this request"))
                                .build();
                    }

                    if (!"PENDING".equals(status)) {
                        return Response.status(400)
                                .entity(new ErrorResponse(false, "Friend request is not pending (status: " + status + ")"))
                                .build();
                    }

                    // Kiểm tra xem có bị block không
                        String checkBlockSql = "SELECT 1 FROM user_blocks " +
                            "WHERE (blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)";
                    try (PreparedStatement checkBlockPs = conn.prepareStatement(checkBlockSql)) {
                        checkBlockPs.setLong(1, fromUserId);
                        checkBlockPs.setLong(2, toUserId);
                        checkBlockPs.setLong(3, toUserId);
                        checkBlockPs.setLong(4, fromUserId);
                        try (ResultSet blockRs = checkBlockPs.executeQuery()) {
                            if (blockRs.next()) {
                                return Response.status(400)
                                        .entity(new ErrorResponse(false, "Cannot accept request due to block"))
                                        .build();
                            }
                        }
                    }

                    // Kiểm tra xem đã là bạn bè chưa (tránh duplicate)
                        String checkFriendshipSql = "SELECT 1 FROM friendships WHERE state = 'ACTIVE' " +
                            "AND ((user_id_a = ? AND user_id_b = ?) OR (user_id_a = ? AND user_id_b = ?))";
                    try (PreparedStatement checkFriendshipPs = conn.prepareStatement(checkFriendshipSql)) {
                        checkFriendshipPs.setLong(1, Math.min(fromUserId, toUserId));
                        checkFriendshipPs.setLong(2, Math.max(fromUserId, toUserId));
                        checkFriendshipPs.setLong(3, Math.max(fromUserId, toUserId));
                        checkFriendshipPs.setLong(4, Math.min(fromUserId, toUserId));
                        try (ResultSet friendshipRs = checkFriendshipPs.executeQuery()) {
                            if (friendshipRs.next()) {
                                // Already friends, just update request status
                                String updateSql = "UPDATE friend_requests SET status = 'ACCEPTED' WHERE id = ?";
                                try (PreparedStatement updatePs = conn.prepareStatement(updateSql)) {
                                    updatePs.setLong(1, requestId);
                                    updatePs.executeUpdate();
                                }
                                
                                conn.commit();
                                return Response.ok(Map.of(
                                        "success", true,
                                        "message", "Friend request accepted successfully (already friends)"
                                )).build();
                            }
                        }
                    }

                    // Update request status
                    String updateSql = "UPDATE friend_requests SET status = 'ACCEPTED' WHERE id = ?";
                    try (PreparedStatement updatePs = conn.prepareStatement(updateSql)) {
                        updatePs.setLong(1, requestId);
                        updatePs.executeUpdate();
                    }

                    // Tạo friendship
                        String insertSql = "INSERT INTO friendships (user_id_a, user_id_b, state, since) " +
                            "VALUES (?, ?, 'ACTIVE', NOW())";
                    try (PreparedStatement insertPs = conn.prepareStatement(insertSql)) {
                        insertPs.setLong(1, Math.min(fromUserId, toUserId));
                        insertPs.setLong(2, Math.max(fromUserId, toUserId));
                        insertPs.executeUpdate();
                    }

                    conn.commit();
                    return Response.ok(Map.of(
                            "success", true,
                            "message", "Friend request accepted successfully"
                    )).build();
                    
                } catch (SQLException e) {
                    conn.rollback();
                    throw e;
                }
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
            // Parse token to get actual userId
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

            try (Connection conn = com.study.Db.get()) {
                // Kiểm tra request tồn tại và là PENDING
                String checkSql = "SELECT from_user_id, to_user_id, status FROM friend_requests WHERE id = ?";
                long toUserId;
                String status;
                
                try (PreparedStatement checkPs = conn.prepareStatement(checkSql)) {
                    checkPs.setLong(1, requestId);
                    try (ResultSet rs = checkPs.executeQuery()) {
                        if (!rs.next()) {
                            return Response.status(404)
                                    .entity(new ErrorResponse(false, "Friend request not found"))
                                    .build();
                        }
                        toUserId = rs.getLong("to_user_id");
                        status = rs.getString("status");
                    }
                }

                // Kiểm tra quyền (chỉ người nhận mới reject được)
                if (toUserId != userId) {
                    return Response.status(403)
                            .entity(new ErrorResponse(false, "You are not authorized to reject this request"))
                            .build();
                }

                if (!"PENDING".equals(status)) {
                    return Response.status(400)
                            .entity(new ErrorResponse(false, "Friend request is not pending (status: " + status + ")"))
                            .build();
                }

                // Update request status
                String updateSql = "UPDATE friend_requests SET status = 'REJECTED' WHERE id = ?";
                try (PreparedStatement updatePs = conn.prepareStatement(updateSql)) {
                    updatePs.setLong(1, requestId);
                    updatePs.executeUpdate();
                }

                return Response.ok(Map.of(
                        "success", true,
                        "message", "Friend request rejected successfully"
                )).build();
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
            // Parse token to get actual userId
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

            try (Connection conn = com.study.Db.get()) {
                // Kiểm tra request tồn tại và là PENDING
                String checkSql = "SELECT from_user_id, status FROM friend_requests WHERE id = ?";
                long fromUserId;
                String status;
                
                try (PreparedStatement checkPs = conn.prepareStatement(checkSql)) {
                    checkPs.setLong(1, requestId);
                    try (ResultSet rs = checkPs.executeQuery()) {
                        if (!rs.next()) {
                            return Response.status(404)
                                    .entity(new ErrorResponse(false, "Friend request not found"))
                                    .build();
                        }
                        fromUserId = rs.getLong("from_user_id");
                        status = rs.getString("status");
                    }
                }

                // Kiểm tra quyền (chỉ người gửi mới cancel được)
                if (fromUserId != userId) {
                    return Response.status(403)
                            .entity(new ErrorResponse(false, "You are not authorized to cancel this request"))
                            .build();
                }

                if (!"PENDING".equals(status)) {
                    return Response.status(400)
                            .entity(new ErrorResponse(false, "Can only cancel pending requests (current status: " + status + ")"))
                            .build();
                }

                // Update request status to CANCELED
                String updateSql = "UPDATE friend_requests SET status = 'CANCELED' WHERE id = ?";
                try (PreparedStatement updatePs = conn.prepareStatement(updateSql)) {
                    updatePs.setLong(1, requestId);
                    updatePs.executeUpdate();
                }

                return Response.ok(Map.of(
                        "success", true,
                        "message", "Friend request canceled successfully"
                )).build();
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
