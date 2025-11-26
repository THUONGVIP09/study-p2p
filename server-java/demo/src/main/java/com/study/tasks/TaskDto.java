package com.study.tasks;

import java.sql.Date;
import java.sql.Timestamp;

public record TaskDto(
        Long id,
        long userId,
        String title,
        String description,
        Date dueDate,
        String repeatRule,
        String status,
        Integer priority,
        Timestamp createdAt,
        Timestamp completedAt
) {}
