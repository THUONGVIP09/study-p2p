package com.study.friends;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.sql.*;
import java.util.*;

record BlockedUserDto(long id, String email, String displayName, String blockedAt) {}

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
}
