package com.study.chat;

import com.study.AuthUtil;
import com.study.Db;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Controller xử lý chat summary
 * Endpoint: /api/chat/summary
 */
@Path("/api/chat/summary")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ChatSummaryController {
    
    /**
     * POST /api/chat/summary/room
     * Tóm tắt chat của một room (conversation)
     * 
     * Request body: {
     *   "roomId": 123,
     *   "limit": 100,  // số lượng messages lấy (default 100)
     *   "maxLength": 150,  // độ dài tối đa summary (optional)
     *   "minLength": 40    // độ dài tối thiểu summary (optional)
     * }
     */
    @POST
    @Path("/room")
    public Response summarizeRoomChat(
            Map<String, Object> requestBody,
            @HeaderParam("Authorization") String token) {
        
        try {
            // Validate user
            Long userId = AuthUtil.getUserIdFromToken(token);
            if (userId == null) {
                return unauthorized("Token không hợp lệ");
            }
            
            // Parse request
            if (!requestBody.containsKey("roomId")) {
                return badRequest("Missing roomId");
            }
            
            long roomId = ((Number) requestBody.get("roomId")).longValue();
            int limit = requestBody.containsKey("limit") 
                ? ((Number) requestBody.get("limit")).intValue() 
                : 100;
            
            Integer maxLength = requestBody.containsKey("maxLength")
                ? ((Number) requestBody.get("maxLength")).intValue()
                : null;
            
            Integer minLength = requestBody.containsKey("minLength")
                ? ((Number) requestBody.get("minLength")).intValue()
                : null;
            
            // Kiểm tra ML service
            if (!ChatSummaryService.isMLServiceHealthy()) {
                return serverError("ML Service không khả dụng. Vui lòng khởi động ml-service trước.");
            }
            
            // Lấy messages từ DB
            List<ChatSummaryService.MessageDto> messages = getMessagesFromRoom(roomId, limit);
            
            if (messages.isEmpty()) {
                return ok(Map.of(
                    "success", true,
                    "message", "Không có tin nhắn để tóm tắt",
                    "summary", "",
                    "keyPoints", List.of()
                ));
            }
            
            // Gọi ML service
            ChatSummaryService.SummaryResult result = 
                ChatSummaryService.summarizeBatch(messages, maxLength, minLength);
            
            // Trả về kết quả
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("summary", result.getSummary());
            response.put("keyPoints", result.getKeyPoints());
            response.put("messageCount", result.getMessageCount());
            response.put("originalLength", result.getOriginalLength());
            response.put("summaryLength", result.getSummaryLength());
            
            return Response.ok(response).build();
            
        } catch (Exception e) {
            e.printStackTrace();
            return serverError("Lỗi khi tóm tắt: " + e.getMessage());
        }
    }
    
    /**
     * POST /api/chat/summary/conversation
     * Tóm tắt chat 1-1 giữa 2 users
     * 
     * Request body: {
     *   "friendId": 456,
     *   "limit": 100,
     *   "maxLength": 150,
     *   "minLength": 40
     * }
     */
    @POST
    @Path("/conversation")
    public Response summarizeConversation(
            Map<String, Object> requestBody,
            @HeaderParam("Authorization") String token) {
        
        try {
            // Validate user
            Long userId = AuthUtil.getUserIdFromToken(token);
            if (userId == null) {
                return unauthorized("Token không hợp lệ");
            }
            
            // Parse request
            if (!requestBody.containsKey("friendId")) {
                return badRequest("Missing friendId");
            }
            
            long friendId = ((Number) requestBody.get("friendId")).longValue();
            int limit = requestBody.containsKey("limit") 
                ? ((Number) requestBody.get("limit")).intValue() 
                : 100;
            
            Integer maxLength = requestBody.containsKey("maxLength")
                ? ((Number) requestBody.get("maxLength")).intValue()
                : null;
            
            Integer minLength = requestBody.containsKey("minLength")
                ? ((Number) requestBody.get("minLength")).intValue()
                : null;
            
            // Kiểm tra ML service
            if (!ChatSummaryService.isMLServiceHealthy()) {
                return serverError("ML Service không khả dụng. Vui lòng khởi động ml-service trước.");
            }
            
            // Lấy messages từ conversation
            List<ChatSummaryService.MessageDto> messages = 
                getMessagesFromConversation(userId, friendId, limit);
            
            if (messages.isEmpty()) {
                return ok(Map.of(
                    "success", true,
                    "message", "Không có tin nhắn để tóm tắt",
                    "summary", "",
                    "keyPoints", List.of()
                ));
            }
            
            // Gọi ML service
            ChatSummaryService.SummaryResult result = 
                ChatSummaryService.summarizeBatch(messages, maxLength, minLength);
            
            // Trả về kết quả
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("summary", result.getSummary());
            response.put("keyPoints", result.getKeyPoints());
            response.put("messageCount", result.getMessageCount());
            response.put("originalLength", result.getOriginalLength());
            response.put("summaryLength", result.getSummaryLength());
            
            return Response.ok(response).build();
            
        } catch (Exception e) {
            e.printStackTrace();
            return serverError("Lỗi khi tóm tắt: " + e.getMessage());
        }
    }
    
    /**
     * GET /api/chat/summary/health
     * Kiểm tra trạng thái ML service
     */
    @GET
    @Path("/health")
    public Response checkMLServiceHealth() {
        boolean healthy = ChatSummaryService.isMLServiceHealthy();
        return Response.ok(Map.of(
            "mlServiceHealthy", healthy,
            "message", healthy ? "ML Service đang hoạt động" : "ML Service không khả dụng"
        )).build();
    }
    
    // Helper methods
    
    private List<ChatSummaryService.MessageDto> getMessagesFromRoom(long roomId, int limit) throws SQLException {
        List<ChatSummaryService.MessageDto> messages = new ArrayList<>();
        
        String sql = """
            SELECT m.content, u.display_name
            FROM messages m
            JOIN users u ON m.sender_id = u.id
            JOIN conversations c ON m.conversation_id = c.id
            JOIN rooms r ON r.conversation_id = c.id
            WHERE r.id = ?
            ORDER BY m.created_at DESC
            LIMIT ?
        """;
        
        try (Connection conn = Db.get();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            
            ps.setLong(1, roomId);
            ps.setInt(2, limit);
            
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String content = rs.getString("content");
                    String sender = rs.getString("display_name");
                    messages.add(new ChatSummaryService.MessageDto(sender, content));
                }
            }
        }
        
        // Reverse để đúng thứ tự thời gian (cũ -> mới)
        java.util.Collections.reverse(messages);
        return messages;
    }
    
    private List<ChatSummaryService.MessageDto> getMessagesFromConversation(
            long userId, long friendId, int limit) throws SQLException {
        
        List<ChatSummaryService.MessageDto> messages = new ArrayList<>();
        
        // Tìm conversation_id giữa 2 users
        String findConvSql = """
            SELECT c.id
            FROM conversations c
            JOIN conversation_participants cp1 ON c.id = cp1.conversation_id
            JOIN conversation_participants cp2 ON c.id = cp2.conversation_id
            WHERE cp1.user_id = ? AND cp2.user_id = ?
            AND c.is_group = FALSE
            LIMIT 1
        """;
        
        String msgSql = """
            SELECT m.content, u.display_name
            FROM messages m
            JOIN users u ON m.sender_id = u.id
            WHERE m.conversation_id = ?
            ORDER BY m.created_at DESC
            LIMIT ?
        """;
        
        try (Connection conn = Db.get()) {
            long conversationId = -1;
            
            // Tìm conversation
            try (PreparedStatement ps = conn.prepareStatement(findConvSql)) {
                ps.setLong(1, userId);
                ps.setLong(2, friendId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        conversationId = rs.getLong("id");
                    }
                }
            }
            
            if (conversationId <= 0) {
                return messages; // Không tìm thấy conversation
            }
            
            // Lấy messages
            try (PreparedStatement ps = conn.prepareStatement(msgSql)) {
                ps.setLong(1, conversationId);
                ps.setInt(2, limit);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        String content = rs.getString("content");
                        String sender = rs.getString("display_name");
                        messages.add(new ChatSummaryService.MessageDto(sender, content));
                    }
                }
            }
        }
        
        // Reverse để đúng thứ tự thời gian
        java.util.Collections.reverse(messages);
        return messages;
    }
    
    private Response ok(Map<String, Object> data) {
        return Response.ok(data).build();
    }
    
    private Response badRequest(String message) {
        return Response.status(Response.Status.BAD_REQUEST)
                .entity(Map.of("success", false, "error", message))
                .build();
    }
    
    private Response unauthorized(String message) {
        return Response.status(Response.Status.UNAUTHORIZED)
                .entity(Map.of("success", false, "error", message))
                .build();
    }
    
    private Response serverError(String message) {
        return Response.serverError()
                .entity(Map.of("success", false, "error", message))
                .build();
    }
}
