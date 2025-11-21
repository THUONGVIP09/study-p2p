package com.study.dto;

import java.time.LocalDateTime;

public record StartCallRequest(
        long roomId,
        long userId,
        String topology, // "sfu" hoặc "p2p"
        String sfuRegion, // optional, ví dụ "ap-southeast"
        String sfuRoomId // Agora channel name (roomCode)
) {
}