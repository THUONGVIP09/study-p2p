package com.study.dto;

public class SaveMessageRequest {
    public String roomCode;
    public Long senderId;
    public String senderName;
    public String text;
    public String timestamp; // ISO8601 format
}
