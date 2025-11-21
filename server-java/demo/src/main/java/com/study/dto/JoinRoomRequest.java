package com.study.dto;

public record JoinRoomRequest(
        String roomCode,
        Long userId,
        String passcode) {
}
