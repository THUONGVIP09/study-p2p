package com.study.dto;

public record HeartbeatRequest(
        long callId,
        long userId,
        Boolean micMuted,
        Boolean camEnabled,
        Boolean screenshare,
        Boolean handRaised,
        String statsJson // JSON text từ client nếu muốn log QoS
) {
}
