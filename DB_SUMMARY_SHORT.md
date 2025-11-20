DB: `study_p2p` (charset utf8mb4_unicode_ci)

Mục đích: Ứng dụng học nhóm P2P — quản lý người dùng, phòng học, chat, gọi video (call sessions), lời mời, bạn bè, thông báo và audit.

Core tables (ngắn gọn):
- `users`: email, password_hash, display_name, status, is_admin — (khóa chính `id`), tham chiếu nhiều nơi.
- `rooms`: id, conversation_id, name, visibility (PUBLIC/PRIVATE/PROTECTED), passcode, max_participants, created_by.
- `conversations`: hội thoại chung (ROOM/DIRECT) — liên kết tới `messages` và `rooms`.
- `messages`: conversation_id, sender_id, msg_type (TEXT/IMAGE/FILE/SYSTEM), content, metadata, reply_to_id.
- `room_members`: liên kết user ↔ room (role, mute flags).
- `room_invites`: token-based invites (invite_email, invitee_id, status, expires_at).
- `friend_requests` & `friendships`: kết bạn, trạng thái, ràng buộc unique.
- `call_sessions` & `call_participants`: thông tin session gọi, stats, loại (P2P/SFU/RELAY).
- `notifications`, `tasks`, `device_tokens`, `user_sessions`, `user_settings` — các chức năng phụ trợ.
- `audit_logs`: ghi nhận hành động (actor_id → users.id).

Quan hệ chính / ràng buộc:
- `users.id` là FK phổ biến (messages.sender_id, rooms.created_by, room_members.user_id,...)
- `rooms.conversation_id` → `conversations.id` (một phòng có 1 conversation)
- Cascade delete/updates được sử dụng nhiều nơi để giữ nhất quán.

Enums/fields quan trọng:
- `visibility` của `rooms`: PUBLIC | PRIVATE | PROTECTED
- `msg_type` của `messages`: TEXT | IMAGE | FILE | SYSTEM
- `role`/`status`/`state` nhiều bảng sử dụng enum (HOST/MEMBER, PENDING/ACCEPTED, ACTIVE/BLOCKED,...)

Dữ liệu mẫu (từ dump):
- users: 6 hàng (admin, alice, bob, chloe, david, eva)
- conversations: 3
- rooms: 2
- messages: 5
- call_sessions: 1, call_participants: 3
- room_members & conversation_members: vài bản ghi (ví dụ host + members)

Cách import nhanh:
mysql -u <user> -p < SQL_DACS4.sql
(The dump tạo DB `study_p2p` và thiết lập charset utf8mb4_unicode_ci.)

Ghi chú ngắn cho AI/đồng đội khi đọc:
- Tập trung vào `users`, `rooms` (và `conversations`), `messages`, `room_members` để hiểu luồng chính.
- WebRTC/signaling logic liên quan tới `call_sessions` + `call_participants` và signaling server trong backend code.
- Mọi FK chính đều đặt `users.id` là trung tâm; kiểm tra quyền/khóa khi thao tác dữ liệu.

File: `DB_SUMMARY_SHORT.md` (đã lưu tại thư mục gốc dự án).