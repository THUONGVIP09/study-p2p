package com.study.dto;

// KHÔNG dùng LocalDateTime nữa

public record RoomDto(
                long id,
                long conversationId,
                String name,
                String roomCode,
                String description,
                String visibility,
                Integer maxParticipants,
                long createdBy,
                boolean isActive,
                String createdAt // <-- đổi sang String
) {
}
