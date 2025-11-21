package com.study.friends;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

record FriendRequestDto(long id, long fromUserId, String fromUserName, String status, String createdAt) {}

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
}
