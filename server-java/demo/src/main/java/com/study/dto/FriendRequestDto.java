package com.study.dto;

public record FriendRequestDto(long id, long fromUserId, String fromUserName, String status, String createdAt) {}
