# HƯỚNG DẪN SỬ DỤNG TÍNH NĂNG ĐỒNG BỘ TIN NHẮN

## Tổng quan
Tính năng này cho phép tin nhắn trong room được lưu trữ an toàn:
- **Lưu local trước** (SharedPreferences) - đảm bảo không mất tin nhắn
- **Đồng bộ lên server** - lưu vào database MySQL
- **Tự động retry** - nếu server offline, sẽ tự động sync khi server online trở lại

---

## 1. CÀI ĐẶT DATABASE

### Chạy migration SQL:
```bash
cd server-java/demo
mysql -u root -p study_p2p < sql/setup_room_messages.sql
```

Hoặc chạy trực tiếp SQL:
```sql
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
```

---

## 2. KHỞI ĐỘNG SERVER JAVA

```bash
cd server-java/demo
mvn clean package
java -jar target/demo-1.0-SNAPSHOT-jar-with-dependencies.jar
```

Server sẽ chạy trên:
- REST API: `http://localhost:8080`
- WebSocket Signaling: `ws://localhost:8081/ws`

---

## 3. KIỂM TRA API

### Test save message:
```bash
curl -X POST http://localhost:8080/api/room-messages \
  -H "Content-Type: application/json" \
  -d '{
    "roomCode": "R000001",
    "senderId": 1,
    "senderName": "Test User",
    "text": "Hello World",
    "timestamp": "2024-12-22T10:30:00.000Z"
  }'
```

### Test get messages:
```bash
curl http://localhost:8080/api/room-messages?roomCode=R000001
```

---

## 4. LUỒNG HOẠT ĐỘNG

### A. Khi gửi tin nhắn (Server ONLINE):
```
User gửi tin → _onSendChat()
    ↓
1. Lưu vào LocalStorage (synced: false)
    ↓
2. Hiển thị UI ngay lập tức (optimistic update)
    ↓
3. Gửi P2P broadcast đến các peer
    ↓
4. Gọi API saveRoomMessage()
    ↓
5. Server lưu vào MySQL
    ↓
6. Mark message as synced trong local
```

### B. Khi gửi tin nhắn (Server OFFLINE):
```
User gửi tin → _onSendChat()
    ↓
1. Lưu vào LocalStorage (synced: false)
    ↓
2. Hiển thị UI ngay lập tức
    ↓
3. Gửi P2P broadcast đến các peer
    ↓
4. API call FAILS (server offline)
    ↓
5. Message vẫn ở local (chưa sync)
    ↓
[30 giây sau - background sync check]
    ↓
6. MessageSyncService tự động retry
    ↓
7. Server online → batch sync thành công
    ↓
8. Mark messages as synced
```

---

## 5. CÁC FILE ĐÃ TẠO/SỬA

### Backend (Java):
✅ **sql/setup_room_messages.sql** - Migration tạo bảng
✅ **dto/SaveMessageRequest.java** - DTO cho request
✅ **dto/RoomMessageDto.java** - DTO cho response
✅ **RoomMessagesController.java** - REST endpoints
✅ **Main.java** - Đăng ký controller

### Frontend (Flutter):
✅ **services/api_service.dart** - Thêm 3 methods:
   - `saveRoomMessage()` - Lưu 1 tin
   - `getRoomMessages()` - Lấy lịch sử
   - `syncRoomMessagesBatch()` - Batch sync

✅ **services/message_sync_service.dart** - Background sync service
✅ **call_page.dart** - Tích hợp sync:
   - Import MessageSyncService
   - Start sync trong initState()
   - Force sync trong dispose()
   - _saveMessageToServer() method

---

## 6. TESTING

### Test Scenario 1: Server Online
1. Start server Java
2. Run Flutter app
3. Vào room và gửi tin nhắn
4. Check console: "✅ Message synced to server: {id}"
5. Verify trong MySQL:
```sql
SELECT * FROM room_messages WHERE room_code = 'R000001';
```

### Test Scenario 2: Server Offline → Online
1. KHÔNG start server Java
2. Run Flutter app
3. Vào room và gửi tin nhắn
4. Check console: "⚠️ Server offline or error - message remains local"
5. Start server Java
6. Đợi 30 giây (hoặc gửi tin mới để trigger sync)
7. Check console: "✅ Synced X messages to server"
8. Verify trong MySQL

### Test Scenario 3: Background Sync
1. Server offline, gửi 5 tin nhắn
2. Start server
3. Background sync tự động chạy mỗi 30s
4. Check console để thấy "📤 Syncing 5 messages..."

---

## 7. LOGS QUAN TRỌNG

### Flutter (Client):
```
💾 Saved message: {messageId}           → Lưu local
✅ Message synced to server: {id}       → Sync thành công
⚠️ Server offline or error              → Server down
🔄 MessageSyncService started           → Service khởi động
📤 Syncing X messages for {roomCode}    → Đang sync
```

### Java (Server):
```
Lưu tin nhắn thành công                 → API save OK
Lấy tin nhắn thành công                 → API get OK
Đã lưu X tin nhắn                       → Batch sync OK
```

---

## 8. TÙY CHỈNH

### Thay đổi tần suất sync:
Trong `message_sync_service.dart`:
```dart
// Hiện tại: mỗi 30 giây
_syncTimer = Timer.periodic(const Duration(seconds: 30), ...);

// Thay đổi thành 1 phút:
_syncTimer = Timer.periodic(const Duration(minutes: 1), ...);
```

### Disable background sync:
```dart
// Trong call_page.dart initState(), comment dòng:
// MessageSyncService.startBackgroundSync();
```

---

## 9. TROUBLESHOOTING

### Problem: Messages không sync
- **Check:** Server có chạy không? `curl http://localhost:8080/api/room-messages?roomCode=TEST`
- **Check:** Database có bảng `room_messages`?
- **Check:** Flutter console có log error không?

### Problem: Duplicate messages
- **Giải pháp:** LocalMessageStorage đã track `synced` flag, chỉ sync messages chưa đồng bộ

### Problem: Server restart → mất messages?
- **Không mất:** Messages đã lưu trong MySQL, dùng `getRoomMessages()` để load lại

---

## 10. NEXT STEPS (TÙY CHỌN)

- [ ] Load chat history từ server khi vào room
- [ ] UI indicator hiển thị message đang pending sync
- [ ] Retry với exponential backoff
- [ ] Pagination cho chat history
- [ ] Delete old messages sau X ngày

---

**Tài liệu này đầy đủ để trình bày với thầy về tính năng đồng bộ tin nhắn! 🎉**
