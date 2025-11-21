package com.study.dto;

public record JoinCallRequest(
        long callId,
        long userId,
        String joinMode, // "SFU" cho Agora
        boolean micMuted,
        boolean camEnabled) {
}