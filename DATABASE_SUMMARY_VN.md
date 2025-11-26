**Tóm Tắt Cơ Sở Dữ Liệu (study_p2p)**

- **File SQL nguồn**: `SQL_DACS4.sql` (root của repo).
- **Database**: `study_p2p`.
- **Mục tiêu hệ thống**: Ứng dụng chat/room/calls với quản lý người dùng, bạn bè, thông báo, cuộc gọi, hội thoại và quyền truy cập phòng.

**Bảng Chính & Mục Đích**
- **`users`**: Thông tin người dùng.
  - PK: `id`; Unique: `email`.
  - Các cột quan trọng: `password_hash`, `display_name`, `status` (ENUM: `ACTIVE`,`SUSPENDED`,`DELETED`), `is_admin`.

- **`user_settings`**: Cấu hình cá nhân (ngôn ngữ, cho phép DM/invite).
  - FK: `user_id` -> `users.id` (unique).

- **`user_sessions`**: Phiên đăng nhập, token, IP, user agent.
  - FK: `user_id` -> `users.id`.

- **`device_tokens`**: Push tokens (FCM/APNs/WebPush).
  - FK: `user_id` -> `users.id`; unique `push_token`.

- **`friend_requests`**: Yêu cầu kết bạn.
  - Cặp: `from_user_id`, `to_user_id`; unique trên cặp.
  - `status`: ENUM(`PENDING`,`ACCEPTED`,`REJECTED`,`CANCELED`).

- **`friendships`**: Quan hệ bạn bè.
  - PK: (`user_id_a`,`user_id_b`) — lưu theo 1 hướng nhất định.
  - `state`: ENUM(`ACTIVE`,`BLOCKED`,`REMOVED`).

- **`user_blocks`**: Ghi lại cặp blocker/blocked (unique pair).

- **`user_bans`**: Ban do admin.
  - FK: `user_id`, `by_admin_id` -> `users.id`.

- **`conversations`**: Hội thoại (ROOM hoặc DIRECT).
  - `type`: ENUM(`ROOM`,`DIRECT`).

- **`conversation_members`**: Thành viên hội thoại.
  - FK: `conversation_id` -> `conversations.id`, `user_id` -> `users.id`.

- **`rooms`**: Phòng gắn với 1 conversation.
  - `conversation_id` (unique) -> `conversations.id`.
  - `visibility`: ENUM(`PUBLIC`,`PRIVATE`,`PROTECTED`), `passcode`, `max_participants`, `created_by` -> `users.id`.

- **`room_members`**: Thành viên phòng (role, mute flags).
  - FK: `room_id` -> `rooms.id`, `user_id` -> `users.id`.

- **`room_invites`**: Lời mời phòng token-based.
  - FK: `room_id` -> `rooms.id`, `inviter_id`/`invitee_id` -> `users.id`.
  - `status`: ENUM(`PENDING`,`ACCEPTED`,`EXPIRED`,`REVOKED`).

- **`messages`**: Tin nhắn trong `conversations`.
  - FK: `conversation_id` -> `conversations.id`, `sender_id` -> `users.id`, `reply_to_id` -> `messages.id` (ON DELETE SET NULL).
  - `msg_type`: ENUM(`TEXT`,`IMAGE`,`FILE`,`SYSTEM`); `content`; `metadata` JSON.

- **`message_attachments`**: File đính kèm cho `messages`.
  - FK: `message_id` -> `messages.id`.

- **`notifications`**: Thông báo cho user.
  - FK: `user_id` -> `users.id`.
  - `type`: ENUM(`FRIEND_REQUEST`,`ROOM_INVITE`,`MESSAGE`,`TASK_REMINDER`,`SYSTEM`).

- **`tasks`**: Todo/reminder cho user.
  - FK: `user_id` -> `users.id`.
  - `repeat_rule`: ENUM(`NONE`,`DAILY`,`WEEKLY`); `status`: ENUM(`TODO`,`DOING`,`DONE`).

- **`call_sessions`**: Phiên gọi gắn với room.
  - FK: `room_id` -> `rooms.id`, `created_by` -> `users.id`.

- **`call_participants`**: Người tham gia cuộc gọi.
  - FK: `call_id` -> `call_sessions.id`, `user_id` -> `users.id`.
  - `join_mode`: ENUM(`P2P`,`SFU`,`RELAY`); `stats_json` (JSON).

- **`audit_logs`**: Log hành động hệ thống.
  - FK: `actor_id` -> `users.id`.
  - `meta` JSON để lưu thêm dữ kiện.

**Quan hệ & Hành vi FK Quan Trọng**
- Phần lớn FK dùng `ON DELETE CASCADE` để dọn sạch dữ liệu con khi xóa record cha (ví dụ: `room_members`, `messages`, `conversation_members`).
- Một vài FK dùng `ON DELETE RESTRICT` (ví dụ `rooms.created_by`) — cần xử lý trước khi xóa user.
- `messages.reply_to_id` dùng `ON DELETE SET NULL` — khi message đích bị xóa, reply vẫn tồn nhưng chỉ mất liên kết.

**Index & Unique Constraints**
- `users.email` là unique — dùng cho login.
- `device_tokens.push_token`, `room_invites.token` là unique.
- Unique pair cho `friend_requests(from_user_id,to_user_id)` và `user_blocks(blocker_id,blocked_id)`.
- Index phổ biến: các cột `*_id` (FK) và `created_at` để tối ưu truy vấn theo user/room/time.

**Kiểu dữ liệu đặc biệt**
- JSON fields: `messages.metadata`, `call_participants.stats_json`, `audit_logs.meta`, `notifications.data` — lưu cấu trúc linh hoạt.
- ENUMs: được sử dụng rộng rãi để giới hạn trạng thái/loại (tham khảo file SQL để biết tất cả giá trị enum).

**Dữ liệu mẫu trong file SQL**
- File chứa seed demo: 6 users (gồm admin), 2 rooms, messages, friend_requests, invites, calls, v.v.
- Có user `status='SUSPENDED'` (ví dụ `eva@study.vn`) — cần xử lý logic loại trừ trong authentication/authorization.

**Truy vấn mẫu hữu ích**
- Lấy tin nhắn theo conversation:
```
SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC;
```
- Lấy thành viên active của room:
```
SELECT u.*
FROM room_members rm
JOIN users u ON rm.user_id = u.id
WHERE rm.room_id = ? AND rm.left_at IS NULL;
```
- Lấy danh sách bạn bè (cần xét cả hai chiều lưu trong `friendships`):
```
SELECT CASE WHEN user_id_a = ? THEN user_id_b ELSE user_id_a END AS friend_id
FROM friendships
WHERE user_id_a = ? OR user_id_b = ?;
```

**Gợi ý cho developer / AI code**
- Luôn kiểm tra `users.status` trước khi cho phép hành động (nhắn, join room, tạo session).
- Khi xóa user: xem kỹ FK `ON DELETE` — nếu cần giữ dữ liệu, cân nhắc soft-delete (`status='DELETED'`) thay vì xóa cứng.
- Khi xử lý friend request: cập nhật `friendships` khi `friend_requests.status` chuyển thành `ACCEPTED` để đảm bảo nhất quán.
- Chuẩn hóa cách lưu cặp trong `friendships` (ví dụ luôn lưu `user_id_a < user_id_b`) để truy vấn thuận tiện.
- Sử dụng index trên `conversation_id`, `room_id`, `created_at` cho các API danh sách/stream message.

**Tài liệu & Onboarding đề xuất**
- Sinh sơ đồ ER từ `SQL_DACS4.sql` (tool: dbdiagram.io, draw.io) để dev mới dễ nắm.
- Thêm file này `DATABASE_SUMMARY_VN.md` vào repo root (đã tạo) và cập nhật `README.md` để tham chiếu.
- Ghi chú migration/seed: `SQL_DACS4.sql` chứa cả cấu trúc và dữ liệu demo.

**Nơi tìm file**
- SQL seed/structure: `SQL_DACS4.sql` (root).
- Nếu cần diagram: xuất SQL sang dbdiagram hoặc công cụ ER để tạo hình ảnh.

**Các hành động tiếp theo (tuỳ chọn)**
- Tạo `DATABASE_SUMMARY_EN.md` (tiếng Anh).
- Sinh file import cho `dbdiagram.io` hoặc PlantUML.
- Tạo truy vấn API mẫu mapping tới bảng (friend-management, messages, rooms).

---

Source: `SQL_DACS4.sql` — Generated by repository assistant on user request.
