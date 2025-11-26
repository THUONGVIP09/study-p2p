package com.study.tasks;

import com.study.AuthUtil;
import com.study.Db;
import com.study.dto.ErrorResponse;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Path("/api/tasks")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TasksController {

    @GET
    public Response listTasks(@HeaderParam("Authorization") String token) {
        try {
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

            List<TaskDto> out = new ArrayList<>();
            String sql = "SELECT id, user_id, title, description, due_date, repeat_rule, status, priority, created_at, completed_at " +
                    "FROM tasks WHERE user_id = ? ORDER BY created_at DESC";

            try (Connection conn = Db.get(); PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setLong(1, userId);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        out.add(new TaskDto(
                                rs.getLong("id"),
                                rs.getLong("user_id"),
                                rs.getString("title"),
                                rs.getString("description"),
                                rs.getDate("due_date"),
                                rs.getString("repeat_rule"),
                                rs.getString("status"),
                                rs.getObject("priority") == null ? null : rs.getInt("priority"),
                                rs.getTimestamp("created_at"),
                                rs.getTimestamp("completed_at")
                        ));
                    }
                }
            }

            return Response.ok(Map.of("success", true, "data", out)).build();
        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(500).entity(new ErrorResponse(false, "Database error: " + e.getMessage())).build();
        }
    }

    @POST
    public Response createTask(Map<String, Object> body, @HeaderParam("Authorization") String token) {
        try {
            long userId;
            try {
                userId = AuthUtil.getUserIdFromToken(token);
            } catch (IllegalArgumentException e) {
                return AuthUtil.createUnauthorizedResponse(e.getMessage());
            }

            if (body == null || body.get("title") == null || ((String) body.get("title")).trim().isEmpty()) {
                return Response.status(400).entity(new ErrorResponse(false, "title is required")).build();
            }

            String title = ((String) body.get("title")).trim();
            String description = (String) body.getOrDefault("description", null);
            java.sql.Date dueDate = null;
            if (body.get("due_date") != null) {
                try {
                    dueDate = java.sql.Date.valueOf((String) body.get("due_date"));
                } catch (Exception ignored) {}
            }
            String repeatRule = (String) body.getOrDefault("repeat_rule", "NONE");
            String status = (String) body.getOrDefault("status", "TODO");
            Integer priority = body.get("priority") == null ? null : ((Number) body.get("priority")).intValue();
            Timestamp completedAt = null;
            if (body.get("completed_at") != null) {
                try { completedAt = Timestamp.valueOf((String) body.get("completed_at")); } catch (Exception ignored) {}
            }

            String insertSql = "INSERT INTO tasks (user_id, title, description, due_date, repeat_rule, status, priority, created_at, completed_at) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), ?)";
            long id;
            try (Connection conn = Db.get(); PreparedStatement ps = conn.prepareStatement(insertSql, Statement.RETURN_GENERATED_KEYS)) {
                ps.setLong(1, userId);
                ps.setString(2, title);
                if (description == null) ps.setNull(3, Types.VARCHAR); else ps.setString(3, description);
                if (dueDate == null) ps.setNull(4, Types.DATE); else ps.setDate(4, dueDate);
                ps.setString(5, repeatRule);
                ps.setString(6, status);
                if (priority == null) ps.setNull(7, Types.INTEGER); else ps.setInt(7, priority);
                if (completedAt == null) ps.setNull(8, Types.TIMESTAMP); else ps.setTimestamp(8, completedAt);

                ps.executeUpdate();
                try (ResultSet g = ps.getGeneratedKeys()) {
                    if (g.next()) id = g.getLong(1); else throw new SQLException("Failed to get id");
                }
            }

            return Response.status(201).entity(Map.of("success", true, "data", Map.of("id", id))).build();
        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(500).entity(new ErrorResponse(false, "Database error: " + e.getMessage())).build();
        }
    }

    @GET
    @Path("/{id}")
    public Response getTask(@PathParam("id") long id, @HeaderParam("Authorization") String token) {
        try {
            long userId;
            try { userId = AuthUtil.getUserIdFromToken(token); } catch (IllegalArgumentException e) { return AuthUtil.createUnauthorizedResponse(e.getMessage()); }

            String sql = "SELECT id, user_id, title, description, due_date, repeat_rule, status, priority, created_at, completed_at FROM tasks WHERE id = ? AND user_id = ?";
            try (Connection conn = Db.get(); PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setLong(1, id);
                ps.setLong(2, userId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        TaskDto t = new TaskDto(
                                rs.getLong("id"), rs.getLong("user_id"), rs.getString("title"), rs.getString("description"),
                                rs.getDate("due_date"), rs.getString("repeat_rule"), rs.getString("status"),
                                rs.getObject("priority") == null ? null : rs.getInt("priority"), rs.getTimestamp("created_at"), rs.getTimestamp("completed_at")
                        );
                        return Response.ok(Map.of("success", true, "data", t)).build();
                    }
                }
            }
            return Response.status(404).entity(new ErrorResponse(false, "Task not found")).build();
        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(500).entity(new ErrorResponse(false, "Database error: " + e.getMessage())).build();
        }
    }

    @PUT
    @Path("/{id}")
    public Response updateTask(@PathParam("id") long id, Map<String, Object> body, @HeaderParam("Authorization") String token) {
        try {
            long userId;
            try { userId = AuthUtil.getUserIdFromToken(token); } catch (IllegalArgumentException e) { return AuthUtil.createUnauthorizedResponse(e.getMessage()); }

            // Verify ownership
            String checkSql = "SELECT user_id FROM tasks WHERE id = ?";
            try (Connection conn = Db.get(); PreparedStatement checkPs = conn.prepareStatement(checkSql)) {
                checkPs.setLong(1, id);
                try (ResultSet rs = checkPs.executeQuery()) {
                    if (!rs.next()) return Response.status(404).entity(new ErrorResponse(false, "Task not found")).build();
                    if (rs.getLong("user_id") != userId) return Response.status(403).entity(new ErrorResponse(false, "Forbidden")).build();
                }
            }

            // Read existing to allow partial updates
            String readSql = "SELECT title, description, due_date, repeat_rule, status, priority, completed_at FROM tasks WHERE id = ?";
            String title; String description; java.sql.Date dueDate; String repeatRule; String status; Integer priority; Timestamp completedAt;
            try (Connection conn = Db.get(); PreparedStatement rps = conn.prepareStatement(readSql)) {
                rps.setLong(1, id);
                try (ResultSet rs = rps.executeQuery()) {
                    rs.next();
                    title = rs.getString("title");
                    description = rs.getString("description");
                    dueDate = rs.getDate("due_date");
                    repeatRule = rs.getString("repeat_rule");
                    status = rs.getString("status");
                    priority = rs.getObject("priority") == null ? null : rs.getInt("priority");
                    completedAt = rs.getTimestamp("completed_at");
                }
            }

            if (body.containsKey("title") && body.get("title") != null) title = ((String) body.get("title")).trim();
            if (body.containsKey("description")) description = (String) body.get("description");
            if (body.containsKey("due_date")) {
                Object v = body.get("due_date");
                if (v == null) dueDate = null; else try { dueDate = Date.valueOf((String) v); } catch (Exception ignored) {}
            }
            if (body.containsKey("repeat_rule")) repeatRule = (String) body.getOrDefault("repeat_rule", "NONE");
            if (body.containsKey("status")) status = (String) body.getOrDefault("status", "TODO");
            if (body.containsKey("priority")) priority = body.get("priority") == null ? null : ((Number) body.get("priority")).intValue();
            if (body.containsKey("completed_at")) {
                Object v = body.get("completed_at");
                if (v == null) completedAt = null; else try { completedAt = Timestamp.valueOf((String) v); } catch (Exception ignored) {}
            }

            // If status is DONE and completedAt not set, set to NOW()
            boolean setCompletedNow = false;
            if ("DONE".equals(status) && completedAt == null) setCompletedNow = true;

            String updateSql = "UPDATE tasks SET title = ?, description = ?, due_date = ?, repeat_rule = ?, status = ?, priority = ?, completed_at = ? WHERE id = ?";
            try (Connection conn = Db.get(); PreparedStatement ups = conn.prepareStatement(updateSql)) {
                ups.setString(1, title);
                if (description == null) ups.setNull(2, Types.VARCHAR); else ups.setString(2, description);
                if (dueDate == null) ups.setNull(3, Types.DATE); else ups.setDate(3, dueDate);
                ups.setString(4, repeatRule);
                ups.setString(5, status);
                if (priority == null) ups.setNull(6, Types.INTEGER); else ups.setInt(6, priority);
                if (setCompletedNow) ups.setTimestamp(7, new Timestamp(System.currentTimeMillis())); else if (completedAt == null) ups.setNull(7, Types.TIMESTAMP); else ups.setTimestamp(7, completedAt);
                ups.setLong(8, id);
                int rows = ups.executeUpdate();
                if (rows > 0) return Response.ok(Map.of("success", true)).build(); else return Response.status(500).entity(new ErrorResponse(false, "Failed to update")).build();
            }

        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(500).entity(new ErrorResponse(false, "Database error: " + e.getMessage())).build();
        }
    }

    @DELETE
    @Path("/{id}")
    public Response deleteTask(@PathParam("id") long id, @HeaderParam("Authorization") String token) {
        try {
            long userId;
            try { userId = AuthUtil.getUserIdFromToken(token); } catch (IllegalArgumentException e) { return AuthUtil.createUnauthorizedResponse(e.getMessage()); }

            String delSql = "DELETE FROM tasks WHERE id = ? AND user_id = ?";
            try (Connection conn = Db.get(); PreparedStatement ps = conn.prepareStatement(delSql)) {
                ps.setLong(1, id);
                ps.setLong(2, userId);
                int rows = ps.executeUpdate();
                if (rows > 0) return Response.ok(Map.of("success", true)).build(); else return Response.status(404).entity(new ErrorResponse(false, "Task not found or forbidden")).build();
            }
        } catch (SQLException e) {
            e.printStackTrace();
            return Response.status(500).entity(new ErrorResponse(false, "Database error: " + e.getMessage())).build();
        }
    }

}
