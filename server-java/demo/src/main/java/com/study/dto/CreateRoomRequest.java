package com.study.dto;

public record CreateRoomRequest(
        String name,
        String description,
        String visibility,
        String passcode,
        Integer maxParticipants,
        Long createdBy) {
}
