# 🔍 Debug Guide - Detailed Logging Version

## Mục Đích
Version này có **LOGS CỰC KỲ CHI TIẾT** để tìm nguyên nhân lỗi mất tin nhắn.

## Các Logs Đã Thêm

### 1. Chat Storage Service (`chat_storage_service.dart`)

#### Load History
```
📁 Storage file path: /path/to/file.json
📂 Storage file does not exist, returning empty
⚠️ Storage file is empty
📖 Loaded history: 2 peers, 1234 bytes
   Peer 1: 5 messages
   Peer 2: 3 messages
```

#### Save History
```
💾 [Write #1] Starting save: 2 peers
💾 [Write #1] Writing 1234 bytes...
✅ [Write #1] Save completed successfully
   Peer 1: 5 messages
   Peer 2: 3 messages
```

#### Add Message (QUAN TRỌNG NHẤT!)
```
🔵 [Op #1] ADD MESSAGE to peer 2
   Sender: me, Content: hello
⏳ [Op #1] Waiting for 1 previous writes...
📖 [Op #1] Loading current history...
   Created new peer entry for 2
💾 [Op #1] Saving: 0 → 1 messages for peer 2
💾 [Write #2] Starting save: 1 peers
✅ [Write #2] Save completed successfully
✅ [Op #1] COMPLETED
```

### 2. Hybrid Chat Service (`hybrid_chat_service.dart`)

#### Receive P2P Message
```
🔵 [HYBRID] Received P2P from friend 2
   Content: hello
   Timestamp: 2025-11-26T...
💾 [HYBRID] Calling ChatStorageService.addMessage for peer message...
✅ [HYBRID] Updated mapping: 127.0.0.1:12345 <-> friend 2
📤 [HYBRID] Emitting to UI stream...
✅ [HYBRID] Storage save completed for peer message
```

#### Send Message
```
📨 [HYBRID] SEND to friend 2: hello
   Attempting P2P to 127.0.0.1:12345...
💾 [HYBRID] Calling ChatStorageService.addMessage for sent P2P...
🔵 [Op #3] ADD MESSAGE to peer 2
   Sender: me, Content: hello
✅ [HYBRID] Sent via P2P to 127.0.0.1:12345
```

### 3. Chat Screen UI (`hybrid_chat_screen.dart`)

#### Bootstrap
```
🚀 [UI] BOOTSTRAP for friend 2 (Bob)
🔌 [UI] Starting hybrid service...
🤝 [UI] Connecting to friend 2...
✅ [UI] Connection mode: P2P Direct
📖 [UI] Loading chat history...
📖 [UI] Loaded 3 messages from storage
✅ [UI] UI updated with 3 messages
🎧 [UI] Setting up stream listener...
```

#### Receive from Stream
```
📥 [UI] Received from stream: peer - hello
   Current messages count: 3
   After add: 4 messages
```

#### Send Message
```
📤 [UI] USER SENDING: hello
   Current messages count: 3
📤 [UI] Calling hybrid.sendToFriend...
✅ [UI] Send completed, updating UI...
   After add: 4 messages
```

---

## Scenario Test với Logs

### Test Case: User 1 gửi "hello" → User 2 reply "hi"

#### Instance 1 (User 1) Console:
```
📤 [UI] USER SENDING: hello
   Current messages count: 0
📤 [UI] Calling hybrid.sendToFriend...

📨 [HYBRID] SEND to friend 2: hello
   Attempting P2P to 127.0.0.1:54321...
💾 [HYBRID] Calling ChatStorageService.addMessage for sent P2P...

🔵 [Op #1] ADD MESSAGE to peer 2
   Sender: me, Content: hello
📖 [Op #1] Loading current history...
   Created new peer entry for 2
💾 [Op #1] Saving: 0 → 1 messages for peer 2
💾 [Write #1] Starting save: 1 peers
💾 [Write #1] Writing 123 bytes...
✅ [Write #1] Save completed successfully
   Peer 2: 1 messages
✅ [Op #1] COMPLETED

✅ [HYBRID] Sent via P2P to 127.0.0.1:54321
✅ [UI] Send completed, updating UI...
   After add: 1 messages

// User 2 gửi reply "hi"

🔵 [HYBRID] Received P2P from friend 2
   Content: hi
   Timestamp: 2025-11-26T...
💾 [HYBRID] Calling ChatStorageService.addMessage for peer message...

🔵 [Op #2] ADD MESSAGE to peer 2
   Sender: peer, Content: hi
⏳ [Op #2] Waiting for 0 previous writes...
📖 [Op #2] Loading current history...
📖 Loaded history: 1 peers, 123 bytes
   Peer 2: 1 messages              ← ✅ Phải thấy message "hello" cũ!
💾 [Op #2] Saving: 1 → 2 messages for peer 2
💾 [Write #2] Starting save: 1 peers
✅ [Write #2] Save completed successfully
   Peer 2: 2 messages              ← ✅ Bây giờ có 2 messages
✅ [Op #2] COMPLETED

📤 [HYBRID] Emitting to UI stream...
✅ [HYBRID] Storage save completed for peer message

📥 [UI] Received from stream: peer - hi
   Current messages count: 1       ← ✅ UI có 1 message (hello)
   After add: 2 messages           ← ✅ Thêm "hi" → 2 messages
```

#### Instance 2 (User 2) Console:
```
// User 1 gửi "hello"

🔵 [HYBRID] Received P2P from friend 1
   Content: hello
   Timestamp: 2025-11-26T...
💾 [HYBRID] Calling ChatStorageService.addMessage for peer message...

🔵 [Op #1] ADD MESSAGE to peer 1
   Sender: peer, Content: hello
📖 [Op #1] Loading current history...
   Created new peer entry for 1
💾 [Op #1] Saving: 0 → 1 messages for peer 1
✅ [Op #1] COMPLETED

📤 [HYBRID] Emitting to UI stream...

📥 [UI] Received from stream: peer - hello
   Current messages count: 0
   After add: 1 messages

// User 2 reply "hi"

📤 [UI] USER SENDING: hi
   Current messages count: 1
📤 [UI] Calling hybrid.sendToFriend...

📨 [HYBRID] SEND to friend 1: hi
💾 [HYBRID] Calling ChatStorageService.addMessage for sent P2P...

🔵 [Op #2] ADD MESSAGE to peer 1
   Sender: me, Content: hi
⏳ [Op #2] Waiting for 0 previous writes...
📖 [Op #2] Loading current history...
📖 Loaded history: 1 peers, 123 bytes
   Peer 1: 1 messages              ← ✅ Phải thấy "hello" từ User 1!
💾 [Op #2] Saving: 1 → 2 messages for peer 1
✅ [Op #2] COMPLETED

✅ [UI] Send completed, updating UI...
   After add: 2 messages
```

---

## Cách Sử Dụng Logs để Debug

### 1. Xác Định Bước Bị Lỗi

Theo dõi sequence:
1. `📤 [UI] USER SENDING` → User click send
2. `📨 [HYBRID] SEND` → Service gọi
3. `🔵 [Op #X] ADD MESSAGE` → Storage operation start
4. `📖 [Op #X] Loading current history` → **QUAN TRỌNG: Kiểm tra count!**
5. `💾 [Op #X] Saving: X → Y messages` → **QUAN TRỌNG: Count phải tăng!**
6. `✅ [Op #X] COMPLETED` → Operation done

### 2. Phát Hiện Race Condition

**Dấu hiệu:**
```
🔵 [Op #5] ADD MESSAGE to peer 2
📖 [Op #5] Loading current history...
   Peer 2: 3 messages              ← Giả sử có 3
💾 [Op #5] Saving: 3 → 4 messages

🔵 [Op #6] ADD MESSAGE to peer 2
📖 [Op #6] Loading current history...
   Peer 2: 3 messages              ← ❌ VẪN LÀ 3! (không phải 4)
💾 [Op #6] Saving: 3 → 4 messages  ← ❌ Ghi đè message #5!
```

**Nguyên nhân:** Op #6 load TRƯỚC KHI Op #5 save xong

**Fix:** Logs sẽ hiện:
```
🔵 [Op #6] ADD MESSAGE to peer 2
⏳ [Op #6] Waiting for 1 previous writes...  ← ✅ Đợi Op #5
📖 [Op #6] Loading current history...
   Peer 2: 4 messages              ← ✅ Đúng rồi!
💾 [Op #6] Saving: 4 → 5 messages
```

### 3. Kiểm Tra File Corruption

**Dấu hiệu:**
```
💾 [Write #X] Writing 1234 bytes...
❌ [Write #X] Error saving: FormatException...
```

**Hoặc:**
```
📖 Loading current history...
❌ Error loading chat history: FormatException...
```

### 4. Kiểm Tra UI Update

**Dấu hiệu mất tin nhắn:**
```
📥 [UI] Received from stream: peer - hi
   Current messages count: 3       ← Có 3 messages
   After add: 4 messages           ← Thêm thành 4

// Reload UI

📖 [UI] Loaded 2 messages from storage  ← ❌ CHỈ CÒN 2!
```

**Nguyên nhân:** Storage không save đúng → check logs của `[Op #X]`

---

## Test Steps với Log Monitoring

### Bước 1: Chạy App và Quan Sát Startup
```
🚀 [UI] BOOTSTRAP for friend X
📖 [UI] Loading chat history...
📖 [UI] Loaded 0 messages from storage   ← ✅ Fresh start
```

### Bước 2: User 1 Gửi "hello"
**Xem logs Instance 1:**
- `📤 [UI] USER SENDING: hello`
- `🔵 [Op #1] ADD MESSAGE` → `Saving: 0 → 1`
- `✅ [Op #1] COMPLETED`

### Bước 3: User 2 Nhận và Reply "hi"
**Xem logs Instance 2:**
- `🔵 [HYBRID] Received P2P` → Content: hello
- `🔵 [Op #1] ADD MESSAGE` → `Saving: 0 → 1` ← Lưu "hello"
- User click Send
- `📤 [UI] USER SENDING: hi`
- `🔵 [Op #2] ADD MESSAGE` → `Loading... Peer 1: 1 messages` ← ✅ Phải thấy!
- `💾 [Op #2] Saving: 1 → 2 messages` ← ✅ Đúng!

### Bước 4: User 1 Reply "how are you"
**Xem logs Instance 1:**
- `🔵 [HYBRID] Received P2P` → Content: hi
- `🔵 [Op #2] ADD MESSAGE` → **KIỂM TRA COUNT TẠI ĐÂY!**
  - Nếu `Loading... Peer 2: 1 messages` → ✅ OK (có "hello" cũ)
  - Nếu `Loading... Peer 2: 0 messages` → ❌ MẤT DATA!
- `📤 [UI] USER SENDING: how are you`
- `🔵 [Op #3] ADD MESSAGE` → **KIỂM TRA COUNT!**
  - Phải `Loading... Peer 2: 2 messages` (hello + hi)
  - `Saving: 2 → 3 messages`

### Bước 5: Reload UI (Close và Reopen Chat)
**Xem logs cả 2 instances:**
```
🚀 [UI] BOOTSTRAP for friend X
📖 [UI] Loading chat history...
📖 Loaded history: 1 peers, XXX bytes
   Peer X: Y messages              ← ✅ KIỂM TRA Y!
📖 [UI] Loaded Y messages from storage
✅ [UI] UI updated with Y messages
```

**Expected counts:**
- Instance 1: Phải load 3 messages (1 gửi, 2 nhận)
- Instance 2: Phải load 3 messages (2 gửi, 1 nhận)

---

## Red Flags - Dấu Hiệu Lỗi

### ❌ Message Count Không Tăng
```
🔵 [Op #5] Saving: 3 → 4 messages
🔵 [Op #6] Loading... Peer X: 3 messages  ← ❌ Phải là 4!
```

### ❌ Operation Fail
```
🔵 [Op #X] ADD MESSAGE
❌ [Op #X] ERROR: ...
```

### ❌ UI Count Không Khớp Storage
```
💾 [Write #X] Save completed
   Peer 2: 5 messages              ← Storage có 5

📖 [UI] Loaded 3 messages          ← ❌ UI chỉ load 3!
```

### ❌ Load Empty When Should Have Data
```
📖 Loading current history...
📖 Loaded history: 0 peers         ← ❌ File empty hoặc corrupt!
```

---

## Copy Logs và Gửi

Khi test, copy **TOÀN BỘ CONSOLE OUTPUT** của cả 2 instances, bao gồm:

1. **Startup logs** (Bootstrap)
2. **Mỗi lần send message** (từ `📤 [UI] USER SENDING` đến `✅ COMPLETED`)
3. **Mỗi lần receive message** (từ `🔵 [HYBRID] Received` đến `✅ COMPLETED`)
4. **Reload logs** (Bootstrap lần 2)

Format:
```
=== INSTANCE 1 (User 1) ===
[paste logs here]

=== INSTANCE 2 (User 2) ===
[paste logs here]

=== REPRO STEPS ===
1. User 1: hello
2. User 2: hi
3. User 1: how are you  ← Lỗi xảy ra ở đây
4. Reload UI cả 2 bên
```

---

## Tóm Tắt

Với logs này, chúng ta có thể xác định CHÍNH XÁC:
- ✅ Message nào được save
- ✅ Message nào được load
- ✅ File có bị corrupt không
- ✅ Race condition xảy ra ở đâu
- ✅ UI update đúng không
- ✅ Count mismatch ở bước nào

**QUAN TRỌNG:** Chú ý logs có `Saving: X → Y` - nếu Y không tăng đúng → đó là nơi bị lỗi!
