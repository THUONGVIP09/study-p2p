-- Bảng lưu tin nhắn trong room
CREATE TABLE IF NOT EXISTS room_messages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    room_code VARCHAR(20) NOT NULL,
    sender_id BIGINT NOT NULL,
    sender_name VARCHAR(255) NOT NULL,
    text TEXT NOT NULL,
    timestamp DATETIME(3) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_room_code (room_code),
    INDEX idx_timestamp (timestamp),
    INDEX idx_sender_id (sender_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
