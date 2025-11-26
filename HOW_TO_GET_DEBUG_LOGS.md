# 📋 Hướng Dẫn Lấy Logs Debug Chi Tiết

## 🎯 Mục đích
Logs sẽ giúp tìm hiểu **chính xác** tại sao tin nhắn cuối bị mất khi reload.

## 📝 Các Logs Đã Được Thêm

### 1. **Message Receive & Storage Tracking**
```
🔵 [HYBRID] Received P2P/Relay from friend X
   Content: ...
💾 [HYBRID] Calling ChatStorageService.addMessage...
   📊 Current pending saves: X
   📊 After add - pending saves: X
✅ [HYBRID] Storage save completed: [content]
   📊 Remaining pending saves: X
   ✂️ [HYBRID] Removed from pending saves, remaining: X
```

### 2. **Storage Operation Details**
```
🔵 [Op #X] START - Adding message to peer Y
   Content: ...
   Sender: peer/me
📖 [Op #X] Loading current history from file...
📄 [Op #X] File exists, size: XXX bytes
📚 [Op #X] Loaded X peers from file
📊 [Op #X] Peer Y current messages: X
💾 [Op #X] Saving: X → Y messages
✅ [Op #X] COMPLETED
```

### 3. **Dispose & Cleanup Tracking**
```
🔴 [UI] WIDGET DISPOSE CALLED for friend X
   📊 Current UI messages count: X
🔄 [UI] Calling HybridChatService.dispose()...

🔴 [HYBRID] DISPOSE CALLED
   📊 Current pending saves: X
⏳ [HYBRID] Waiting for X pending saves before dispose...
✅ [HYBRID] All pending saves completed in Xms
🔌 [HYBRID] Closing connections and streams...
✅ [HYBRID] Dispose completed
✅ [UI] HybridChatService disposed after pending saves
✅ [UI] Widget dispose completed
```

## 🔍 Cách Lấy Logs

### **Phương Pháp 1: Debug Console trong VS Code (KHUYẾN NGHỊ)**

#### Bước 1: Mở Debug Console
1. Nhấn **Ctrl + Shift + Y** (hoặc View → Debug Console)
2. Hoặc click vào tab "Debug Console" ở dưới cùng màn hình

#### Bước 2: Chạy Test
```powershell
# Trong Terminal, chạy:
cd flutter-app/flutter_application_1
flutter run
```

#### Bước 3: Thực Hiện Scenario Test
**Scenario để tái hiện bug "mất tin nhắn cuối":**

1. **Login 2 users:**
   - Instance 1: Login User A (ví dụ: userId 15)
   - Instance 2: Login User B (ví dụ: userId 16)

2. **Gửi tin nhắn test:**
   - User A gửi: "Message 1"
   - User B gửi: "Reply 1"
   - User A gửi: "Message 2"
   - User B gửi: "Reply 2"
   - **User A gửi: "Final message"** ← Tin nhắn này bị mất?

3. **Reload ngay:**
   - Trong VS Code Debug Console, nhấn **r** (hot reload)
   - Hoặc đóng chat screen và mở lại

4. **Kiểm tra:**
   - Xem có còn "Final message" không?

#### Bước 4: Copy Logs
1. **Click vào Debug Console**
2. **Ctrl + A** (chọn tất cả)
3. **Ctrl + C** (copy)
4. **Paste vào file text** hoặc **gửi trực tiếp cho tôi**

### **Phương Pháp 2: Lưu Logs Vào File Tự Động**

#### Sử dụng Script Đã Có
```powershell
# Chạy script có sẵn (đã tạo trước đó)
.\run_test_instances.ps1
```

Script này sẽ:
- Tự động chạy 2 Flutter instances
- Lưu logs vào `logs_instance1.txt` và `logs_instance2.txt`

#### Xem Logs
```powershell
# Xem logs instance 1
Get-Content logs_instance1.txt -Tail 100

# Xem logs instance 2
Get-Content logs_instance2.txt -Tail 100

# Hoặc mở trong VS Code
code logs_instance1.txt
code logs_instance2.txt
```

## 🎯 Test Case Cụ Thể

### **Scenario: Mất tin nhắn cuối khi reload**

```
┌─────────────────────────────────────────────────────┐
│ USER A (Instance 1)          USER B (Instance 2)   │
├─────────────────────────────────────────────────────┤
│ 1. Login userId=15           Login userId=16        │
│ 2. Mở chat với B             Mở chat với A         │
│ 3. Gửi: "hi"          ──────>                       │
│ 4.                           Nhận: "hi"             │
│ 5.                    <────── Gửi: "hello"          │
│ 6. Nhận: "hello"                                    │
│ 7. Gửi: "how r u?"    ──────>                       │
│ 8.                           Nhận: "how r u?"       │
│ 9.                    <────── Gửi: "good thanks"    │
│ 10. Nhận: "good thanks"                             │
│ 11. Gửi: "FINAL MSG"  ──────> ← TIN NHẮN NÀY       │
│ 12. *** RELOAD NGAY (nhấn r) ***                    │
│ 13. Kiểm tra: "FINAL MSG" còn không?               │
└─────────────────────────────────────────────────────┘
```

## 📊 Logs Quan Trọng Cần Chú Ý

### ✅ **Logs Bình Thường (Không Bug):**
```
📨 [HYBRID] SEND to friend 16: FINAL MSG
💾 [HYBRID] Calling ChatStorageService.addMessage for sent P2P...
   📊 Current pending saves: 0
   📊 After add - pending saves: 1
🔵 [Op #5] START - Adding message to peer 16
   Content: FINAL MSG
   Sender: me
📖 [Op #5] Loading current history from file...
📄 [Op #5] File exists, size: 842 bytes
📚 [Op #5] Loaded 1 peers from file
📊 [Op #5] Peer 16 current messages: 4
💾 [Op #5] Saving: 4 → 5 messages
✅ [Op #5] COMPLETED
✅ [HYBRID] Storage save completed: FINAL MSG
   📊 Remaining pending saves: 0
   ✂️ [HYBRID] Removed from pending saves, remaining: 0

[Sau đó reload...]

🔴 [UI] WIDGET DISPOSE CALLED for friend 16
   📊 Current UI messages count: 5
🔄 [UI] Calling HybridChatService.dispose()...
🔴 [HYBRID] DISPOSE CALLED
   📊 Current pending saves: 0  ← QUAN TRỌNG: Phải = 0!
✅ [HYBRID] No pending saves to wait for
```

### ❌ **Logs Khi Có Bug (Tin nhắn mất):**
Có thể thấy:
```
📨 [HYBRID] SEND to friend 16: FINAL MSG
💾 [HYBRID] Calling ChatStorageService.addMessage...
   📊 Current pending saves: 0
   📊 After add - pending saves: 1
🔵 [Op #5] START - Adding message...

[RELOAD NGAY LẬP TỨC - TRƯỚC KHI Op #5 HOÀN THÀNH!]

🔴 [UI] WIDGET DISPOSE CALLED
   📊 Current UI messages count: 5
🔴 [HYBRID] DISPOSE CALLED
   📊 Current pending saves: 1  ← STILL PENDING!
⏳ [HYBRID] Waiting for 1 pending saves...

[Có thể bị timeout hoặc error ở đây]
```

## 🔑 Keywords Để Filter Logs

Tìm kiếm theo keywords:
- `🔴 DISPOSE` - Xem khi nào dispose được gọi
- `📊 Current pending saves` - Xem có bao nhiêu saves đang chờ
- `⏳ Waiting for` - Xem có đợi saves không
- `❌` - Tìm tất cả errors
- `FINAL MSG` - Tìm tin nhắn test cụ thể
- `[Op #` - Xem storage operations
- `✅ COMPLETED` - Xem operations nào hoàn thành

## 📤 Gửi Logs Cho Tôi

### **Format tốt nhất:**
```
Scenario:
- User A (ID: 15) gửi 5 tin nhắn cho User B (ID: 16)
- Tin nhắn cuối: "FINAL MSG"
- Reload ngay sau khi gửi
- Kết quả: Tin nhắn cuối MẤT

Logs từ Debug Console:
[paste toàn bộ logs ở đây]
```

### **Hoặc gửi file:**
```
logs_instance1.txt (User A - người gửi)
logs_instance2.txt (User B - người nhận)
```

## 🆘 Troubleshooting

### **Không thấy logs trong Debug Console?**
1. Đảm bảo đã chạy `flutter run` từ Terminal
2. Kiểm tra tab "Debug Console" (không phải "Terminal")
3. Logs có thể bị trộn lẫn - tìm theo emoji icons

### **Quá nhiều logs?**
1. Dùng Filter (Ctrl + F) với keywords trên
2. Hoặc copy tất cả và gửi cho tôi, tôi sẽ filter

### **Script không chạy?**
```powershell
# Nếu lỗi permission:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Sau đó chạy lại:
.\run_test_instances.ps1
```

## ✅ Checklist Khi Gửi Logs

- [ ] Đã thực hiện đúng scenario test (gửi tin → reload ngay)
- [ ] Đã xác nhận tin nhắn bị mất
- [ ] Đã copy toàn bộ logs từ Debug Console (hoặc file)
- [ ] Đã ghi rõ: userId nào gửi, userId nào nhận
- [ ] Đã ghi rõ: tin nhắn nào bị mất

---

**Sau khi có logs, tôi sẽ phân tích và tìm ra chính xác:**
1. Tin nhắn có được gọi `addMessage()` không?
2. Operation có hoàn thành không?
3. Dispose có đợi pending saves không?
4. Có error nào xảy ra trong quá trình save không?

👉 **Hãy gửi logs cho tôi ngay!**
