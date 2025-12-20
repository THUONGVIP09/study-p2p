package com.study.chat;

// Placeholder cho logic tóm tắt chat đã bị gỡ bỏ.
public class ChatFeatureRemovedService {
    public static boolean isMLServiceHealthy() {
        return false;
    }

    // DTO giữ nguyên tên trường để tránh lỗi nếu còn tham chiếu ở nơi khác.
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
}
