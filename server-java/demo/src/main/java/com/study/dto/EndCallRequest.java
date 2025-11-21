package com.study.dto;

public record EndCallRequest(
        long callId,
        String endReason) {
}