package com.study.dto;

public record StartCallRequest(
        long roomId,
        long userId,
        String topology, // "sfu" hoặc "p2p"
        String sfuRegion, // optional, ví dụ "ap-southeast"
        String sfuRoomId // Agora channel name (roomCode)
) {
}