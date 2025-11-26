# 🔍 Hướng Dẫn Xem và Copy Logs

## Logs Ở Đâu?

### 1. VS Code Debug Console (Khuyến nghị)
- **Chạy app:** Nhấn **F5** hoặc click **Run and Debug**
- **Xem logs:** Tab **"Debug Console"** (dưới cùng màn hình)
- **Copy logs:**
  1. Click vào Debug Console
  2. **Ctrl+A** (chọn tất cả)
  3. **Ctrl+C** (copy)
  4. Paste vào file text

![Debug Console Location](https://code.visualstudio.com/assets/docs/editor/debugging/debug-console.png)

---

### 2. Terminal/Command Line
- **Chạy app:**
  ```powershell
  cd flutter-app\flutter_application_1
  flutter run
  ```
- **Xem logs:** Hiện trực tiếp trong terminal
- **Copy logs:**
  1. Click chuột phải → **Select All**
  2. **Ctrl+C**
  3. Paste vào file text

---

### 3. Logs Tự Động Lưu File (KHUYẾN NGHỊ CHO 2 INSTANCES!)

#### Sử dụng Script Tự Động:

**Bước 1:** Chạy script:
```powershell
cd D:\D_A_T_A\Du_an\DACS4\study-p2p
.\run_test_instances.ps1
```

**Bước 2:** Script sẽ:
- Mở 2 PowerShell windows
- Instance 1: Windows app
- Instance 2: Chrome app
- Tự động save logs vào:
  - `logs_instance1.txt`
  - `logs_instance2.txt`

**Bước 3:** Sau khi test xong:
- Đóng 2 app
- Gửi 2 file logs

---

## 🎯 Tìm Logs Nhanh

### Trong Debug Console/Terminal, dùng Ctrl+F tìm:

#### Tìm Storage Operations:
```
[Op #
```
Kết quả:
```
🔵 [Op #1] ADD MESSAGE to peer 2
🔵 [Op #2] ADD MESSAGE to peer 2
🔵 [Op #3] ADD MESSAGE to peer 2
```

#### Tìm UI Updates:
```
Current messages count
```
Kết quả:
```
   Current messages count: 0
   Current messages count: 1
   Current messages count: 2
```

#### Tìm Errors:
```
❌
```
Kết quả:
```
❌ [Op #5] ERROR: ...
❌ [UI] Send error: ...
```

#### Tìm Load History:
```
Loaded
```
Kết quả:
```
📖 [UI] Loaded 3 messages from storage
```

---

## 📋 Cách Copy Logs Đầy Đủ

### Phương pháp 1: Copy Thủ Công

**Instance 1:**
1. Mở Debug Console/Terminal instance 1
2. Scroll lên đầu (từ khi app khởi động)
3. **Ctrl+A** → **Ctrl+C**
4. Paste vào file `logs_user1.txt`

**Instance 2:**
1. Mở Debug Console/Terminal instance 2
2. Scroll lên đầu
3. **Ctrl+A** → **Ctrl+C**
4. Paste vào file `logs_user2.txt`

### Phương pháp 2: Dùng Script (Tự động)

Chạy script `run_test_instances.ps1` - logs tự động save!

---

## 🧪 Test Workflow Đầy Đủ

### Bước 1: Khởi động
```powershell
# Cách A: Dùng script
.\run_test_instances.ps1

# Cách B: Manual
# Terminal 1:
cd flutter-app\flutter_application_1
flutter run -d windows

# Terminal 2 (PowerShell mới):
cd flutter-app\flutter_application_1
flutter run -d chrome
```

### Bước 2: Login 2 Users
- Instance 1: Login User A
- Instance 2: Login User B
- (Phải là friends trong database)

### Bước 3: Mở Chat
- Cả 2 instances: Vào Friends tab → Click vào nhau

### Bước 4: Demo Lỗi
```
User 1: hello
User 2: hi  
User 1: how are you     ← Lỗi xảy ra ở đây
User 2: im fine
```

### Bước 5: Reload UI
- Cả 2 instances: Back về Friends → Mở lại chat

### Bước 6: Quan sát
- Đếm số tin nhắn hiển thị
- Xem có tin nhắn nào mất không

### Bước 7: Copy Logs
- **Nếu dùng script:** Đóng app → gửi `logs_instance1.txt` và `logs_instance2.txt`
- **Nếu manual:** Copy từ Debug Console/Terminal như hướng dẫn trên

---

## 📤 Format Gửi Logs

Tạo file `test_report.txt`:

```
=== THÔNG TIN TEST ===
Ngày: 2025-11-26
User 1: [ID và tên]
User 2: [ID và tên]

=== CÁC BƯỚC THỰC HIỆN ===
1. User 1 gửi: "hello"
2. User 2 reply: "hi"
3. User 1 reply: "how are you"  ← LỖI Ở ĐÂY
4. User 2 reply: "im fine"
5. Reload UI cả 2 bên

=== KẾT QUẢ ===
Instance 1 (User 1):
- Trước reload: Thấy X tin nhắn
- Sau reload: Thấy Y tin nhắn
- Mô tả lỗi: ...

Instance 2 (User 2):
- Trước reload: Thấy X tin nhắn  
- Sau reload: Thấy Y tin nhắn
- Mô tả lỗi: ...

=== LOGS ===
Xem file đính kèm:
- logs_instance1.txt
- logs_instance2.txt
```

---

## ⚠️ Lưu Ý Quan Trọng

### ✅ Phải Copy Logs TỪ ĐẦU
- Không chỉ copy lúc lỗi xảy ra
- Copy từ khi app khởi động (dòng đầu tiên)
- Bao gồm cả:
  - Bootstrap logs
  - Mỗi message gửi/nhận
  - Reload logs

### ✅ Copy CẢ 2 Instances
- Logs của User 1
- Logs của User 2
- Để so sánh cross-reference

### ✅ Chú Thích Rõ Ràng
Trong logs, thêm comment (nếu copy thủ công):
```
// User 1 gửi "hello"
🔵 [Op #1] ADD MESSAGE...

// User 2 nhận "hello"
🔵 [HYBRID] Received P2P...

// User 1 gửi "how are you" ← LỖI Ở ĐÂY!
📤 [UI] USER SENDING: how are you
```

---

## 🚀 Quick Start

**Cách nhanh nhất:**

1. Chạy:
   ```powershell
   cd D:\D_A_T_A\Du_an\DACS4\study-p2p
   .\run_test_instances.ps1
   ```

2. Login 2 users

3. Demo lỗi

4. Đóng app

5. Gửi 2 files:
   - `logs_instance1.txt`
   - `logs_instance2.txt`

**Done!** 🎉

---

## 🆘 Nếu Không Thấy Logs

### Kiểm tra:

1. **Flutter run đúng mode chưa?**
   ```powershell
   flutter run --verbose  # Thêm --verbose để nhiều logs hơn
   ```

2. **Debug Console có mở không?**
   - VS Code: View → Debug Console (Ctrl+Shift+Y)

3. **Logs bị filter?**
   - Bỏ filter nếu có
   - Check "Show all output"

4. **App có crash không?**
   - Nếu crash → logs vẫn được lưu đến trước khi crash
   - Copy phần đó

---

## 💡 Tips

### Highlight Logs Quan Trọng
Khi gửi logs, thêm comment:
```
========== LỖI XUẤT HIỆN TẠI ĐÂY ==========
📤 [UI] USER SENDING: how are you
...
========== KẾT THÚC PHẦN LỖI ==========
```

### So Sánh Logs
Mở 2 files logs cạnh nhau để so sánh:
- VS Code: Click file 1 → Right-click file 2 → "Compare with..."

### Search Specific Operation
Nếu biết operation ID (từ logs):
```
Ctrl+F: [Op #5]
```

Sẽ jump đến tất cả logs của operation đó.

---

**Bây giờ chạy test và gửi logs nhé!** 🚀
