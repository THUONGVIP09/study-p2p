package com.study.dto;

import java.time.LocalDateTime;

public record CallSessionDto(
                long id,
                long roomId,
                long createdBy,
                String topology,
                String sfuRegion,
                String sfuRoomId,
                String startedAt,
                String endedAt,
                Integer liveCount) {
}
