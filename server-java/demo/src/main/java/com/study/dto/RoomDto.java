package com.study.dto;

import java.time.LocalDateTime;

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
        LocalDateTime createdAt) {
}
