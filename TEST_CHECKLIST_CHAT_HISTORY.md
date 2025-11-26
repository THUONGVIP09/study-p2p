# ✅ Test Checklist - Chat History Fixes

## Chuẩn Bị
- [ ] Database có ít nhất 2 users là bạn bè
- [ ] Server Java đang chạy (port 8080, 8082)
- [ ] 2 Flutter instances sẵn sàng

---

## Test 1: Basic Flow ⭐ (QUAN TRỌNG NHẤT)

**Mục tiêu:** Verify messages persist after reload

### Bước 1: Gửi tin nhắn
- [ ] Instance 1: Login User A → mở chat với User B
- [ ] Instance 2: Login User B → mở chat với User A
- [ ] User A gửi: "hello"
- [ ] User B reply: "hi there"
- [ ] User A reply: "how are you?"
- [ ] ✅ Cả 2 bên thấy đủ 3 tin nhắn

### Bước 2: Test persistence
- [ ] Close chat screen ở Instance 1 (back về friends list)
- [ ] Close chat screen ở Instance 2 (back về friends list)
- [ ] Mở lại chat (User A với User B) ở Instance 1
- [ ] Mở lại chat (User B với User A) ở Instance 2
- [ ] ✅ **Instance 1 thấy đủ 3 tin nhắn** (2 tin của A, 1 tin của B)
- [ ] ✅ **Instance 2 thấy đủ 3 tin nhắn** (1 tin của A, 2 tin của B)

### Nếu fail:
1. Check console logs:
   - `🔵 Received P2P from friend X: ...` (nhận được)
   - `💾 Saving sent P2P message to friend X` (lưu được)
2. Run debug script: `flutter run lib/debug_storage.dart`
3. Check file path và content

---

## Test 2: Loading State

**Mục tiêu:** Verify UI không cho spam khi đang load

- [ ] Mở chat screen
- [ ] ✅ Thấy loading overlay: "Loading chat history..."
- [ ] ✅ Không thể type vào text field
- [ ] ✅ Send button bị disabled
- [ ] Đợi load xong
- [ ] ✅ Overlay biến mất
- [ ] ✅ Text field enabled
- [ ] ✅ Send button enabled

---

## Test 3: Sending State

**Mục tiêu:** Verify không spam send được

- [ ] Gửi 1 message
- [ ] ✅ Send button hiện spinner (loading icon)
- [ ] ✅ Không thể gửi message khác khi đang gửi
- [ ] ✅ Text field disable
- [ ] Message gửi xong
- [ ] ✅ UI quay lại bình thường

---

## Test 4: No Duplicate Messages

**Mục tiêu:** Verify không bị duplicate khi reload

- [ ] User A gửi: "test 1"
- [ ] User B gửi: "test 2"
- [ ] Cả 2 đều thấy 2 messages
- [ ] Close chat → Reopen chat (cả 2 instances)
- [ ] ✅ Vẫn chỉ thấy 2 messages (không duplicate thành 4)

---

## Test 5: Filter by Friend

**Mục tiêu:** Verify không nhận nhầm tin của friend khác

### Cần 3 users: A, B, C (A-B friends, A-C friends)

- [ ] Instance 1: User A mở chat với User B
- [ ] Instance 2: User B gửi message cho User A
- [ ] Instance 3: User C gửi message cho User A
- [ ] ✅ Instance 1 (chat A-B) CHỈ thấy message từ B, KHÔNG thấy message từ C
- [ ] Close chat A-B, mở chat A-C
- [ ] ✅ Thấy message từ C

---

## Test 6: Fresh Start

**Mục tiêu:** Verify file cũ bị xóa

- [ ] Chat 1-2 messages
- [ ] Close app hoàn toàn
- [ ] Mở lại app
- [ ] Login → mở chat
- [ ] ✅ Không có lịch sử cũ (đã bị xóa)
- [ ] Không có lỗi parse JSON

**Lưu ý:** Nếu muốn GIỮ lịch sử, comment dòng này trong `main.dart`:
```dart
// await ChatStorageService.deleteStorageFile();
```

---

## Test 7: Race Condition Save

**Mục tiêu:** Verify multiple saves không gây lỗi

- [ ] User A và User B chat liên tục (spam messages)
- [ ] User A: "1", "2", "3", "4", "5"
- [ ] User B: "a", "b", "c", "d", "e"
- [ ] Total: 10 messages trong vòng vài giây
- [ ] ✅ Không có crash
- [ ] ✅ Không có error logs
- [ ] Close → Reopen
- [ ] ✅ Thấy đủ 10 messages (không mất)

---

## Debug Tools

### Xem console logs
```
🔵 Received P2P from friend X: content   → Nhận được message
💾 Saving sent P2P message to friend X   → Lưu message gửi đi
💾 Saving relay message from friend X    → Lưu relay message
❌ Error ...                             → Có lỗi
```

### Run debug script
```bash
cd flutter-app/flutter_application_1
flutter run lib/debug_storage.dart
```

Output sẽ show:
- File path
- File size
- JSON content
- List messages per peer

---

## Expected Results Summary

| Test | Expected | ✅/❌ |
|------|----------|------|
| Messages persist after reload | Cả 2 bên thấy đủ | |
| No duplicates | Mỗi message 1 lần | |
| Loading overlay blocks UI | Không spam được | |
| Sending state shows spinner | Visual feedback | |
| Filter by friendId | Không nhận nhầm | |
| Fresh start clears old data | Không lỗi parse | |
| Multiple saves no crash | Lock works | |

---

## Nếu Gặp Lỗi

### Lỗi: Messages mất sau reload
1. Check logs: `💾 Saving...` có chạy không?
2. Run debug script → verify file có data không
3. Check key format: phải là `friendId.toString()` (string "1", "2"...)

### Lỗi: Duplicate messages
1. Check order: Load history → Setup stream (đúng chưa?)
2. Check filter: `if (e['friendId'] != widget.friendId) return;` có không?

### Lỗi: Parse JSON failed
1. Delete file manually:
   ```bash
   # Android
   adb shell rm /data/data/com.example.flutter_application_1/app_flutter/p2p_chat_history.json
   
   # Windows (app documents folder)
   # Find and delete manually
   ```
2. Restart app

### Lỗi: UI không unlock
1. Check `_isLoading` và `_isSending` state
2. Verify finally block chạy (set về false)

---

## Performance Notes

- Lock wait time: Max 50ms per operation
- File flush: Ensures data written to disk
- Stream filter: Prevents unnecessary UI updates
- Loading overlay: Prevents race conditions

---

**QUAN TRỌNG NHẤT: Test 1 - Basic Flow**  
Nếu test này pass → tất cả core features OK!
