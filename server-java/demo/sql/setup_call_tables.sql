-- Script tạo đầy đủ tables cho Call feature
-- Chạy file này nếu chưa có tables call_sessions và call_participants

-- 1. Bảng call_sessions: lưu thông tin session call
CREATE TABLE IF NOT EXISTS call_sessions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    room_id BIGINT NOT NULL,
    sfu_region VARCHAR(50),
    recording_url VARCHAR(500),
    created_by BIGINT NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    topology VARCHAR(20) DEFAULT 'sfu',  -- 'sfu' hoặc 'p2p'
    sfu_room_id VARCHAR(100),  -- Agora channel name (room_code)
    end_reason VARCHAR(100),
    INDEX idx_room_id (room_id),
    INDEX idx_started_at (started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Bảng call_participants: lưu thông tin users tham gia call
CREATE TABLE IF NOT EXISTS call_participants (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    call_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    join_mode VARCHAR(20) DEFAULT 'SFU',  -- 'SFU', 'P2P', etc.
    stats_json TEXT,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP NULL,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    mic_muted BOOLEAN DEFAULT FALSE,
    cam_enabled BOOLEAN DEFAULT TRUE,
    screenshare BOOLEAN DEFAULT FALSE,
    hand_raised BOOLEAN DEFAULT FALSE,
    UNIQUE KEY unique_call_user (call_id, user_id),
    INDEX idx_call_id (call_id),
    INDEX idx_user_id (user_id),
    INDEX idx_left_at (left_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. View để đếm số lượng participants đang live
CREATE OR REPLACE VIEW v_call_session_live AS
SELECT 
    cp.call_id AS session_id,
    COUNT(*) AS live_count
FROM call_participants cp
WHERE cp.left_at IS NULL
GROUP BY cp.call_id;
