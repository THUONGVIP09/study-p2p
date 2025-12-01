package com.study.chat;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Service để gọi Python ML Service và lấy kết quả tóm tắt chat
 */
public class ChatSummaryService {
    
    private static final String ML_SERVICE_URL = "http://localhost:5001";
    private static final HttpClient httpClient = HttpClient.newHttpClient();
    private static final ObjectMapper objectMapper = new ObjectMapper();
    
    /**
     * Gọi Python service để tóm tắt một văn bản đơn
     */
    public static SummaryResult summarizeText(String text, Integer maxLength, Integer minLength) throws IOException, InterruptedException {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("text", text);
        if (maxLength != null) {
            requestBody.put("max_length", maxLength);
        }
        if (minLength != null) {
            requestBody.put("min_length", minLength);
        }
        
        String json = objectMapper.writeValueAsString(requestBody);
        
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(ML_SERVICE_URL + "/summarize"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();
        
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        
        if (response.statusCode() != 200) {
            throw new IOException("ML Service returned status: " + response.statusCode() + ", body: " + response.body());
        }
        
        return objectMapper.readValue(response.body(), SummaryResult.class);
    }
    
    /**
     * Gọi Python service để tóm tắt nhiều messages
     */
    public static SummaryResult summarizeBatch(List<MessageDto> messages, Integer maxLength, Integer minLength) throws IOException, InterruptedException {
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("messages", messages);
        if (maxLength != null) {
            requestBody.put("max_length", maxLength);
        }
        if (minLength != null) {
            requestBody.put("min_length", minLength);
        }
        
        String json = objectMapper.writeValueAsString(requestBody);
        
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(ML_SERVICE_URL + "/summarize/batch"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();
        
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        
        if (response.statusCode() != 200) {
            throw new IOException("ML Service returned status: " + response.statusCode() + ", body: " + response.body());
        }
        
        return objectMapper.readValue(response.body(), SummaryResult.class);
    }
    
    /**
     * Kiểm tra health của ML service
     */
    public static boolean isMLServiceHealthy() {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ML_SERVICE_URL + "/health"))
                    .GET()
                    .build();
            
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            return response.statusCode() == 200;
        } catch (Exception e) {
            return false;
        }
    }
    
    // DTO classes
    public static class MessageDto {
        private String sender;
        private String content;
        
        public MessageDto() {}
        
        public MessageDto(String sender, String content) {
            this.sender = sender;
            this.content = content;
        }
        
        public String getSender() { return sender; }
        public void setSender(String sender) { this.sender = sender; }
        
        public String getContent() { return content; }
        public void setContent(String content) { this.content = content; }
    }
    
    public static class SummaryResult {
        private String summary;
        
        @com.fasterxml.jackson.annotation.JsonProperty("key_points")
        private List<String> keyPoints;
        
        @com.fasterxml.jackson.annotation.JsonProperty("original_length")
        private Integer originalLength;
        
        @com.fasterxml.jackson.annotation.JsonProperty("summary_length")
        private Integer summaryLength;
        
        @com.fasterxml.jackson.annotation.JsonProperty("message_count")
        private Integer messageCount;
        
        public SummaryResult() {}
        
        public String getSummary() { return summary; }
        public void setSummary(String summary) { this.summary = summary; }
        
        public List<String> getKeyPoints() { return keyPoints; }
        public void setKeyPoints(List<String> keyPoints) { this.keyPoints = keyPoints; }
        
        public Integer getOriginalLength() { return originalLength; }
        public void setOriginalLength(Integer originalLength) { this.originalLength = originalLength; }
        
        public Integer getSummaryLength() { return summaryLength; }
        public void setSummaryLength(Integer summaryLength) { this.summaryLength = summaryLength; }
        
        public Integer getMessageCount() { return messageCount; }
        public void setMessageCount(Integer messageCount) { this.messageCount = messageCount; }
    }
}
