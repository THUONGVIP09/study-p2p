-- View để đếm số lượng participants đang live trong mỗi call session
-- live_count: số user đang active (left_at IS NULL)

CREATE OR REPLACE VIEW v_call_session_live AS
SELECT 
    cp.call_id AS session_id,
    COUNT(*) AS live_count
FROM call_participants cp
WHERE cp.left_at IS NULL
GROUP BY cp.call_id;
