# 🎯 Hướng Dẫn Demo Chat Trên Cùng 1 Máy

## 📋 Chuẩn Bị

### Yêu Cầu:
- Java server đang chạy (Main.java)
- 2 users trong database là **bạn bè** của nhau (ví dụ: userId=1 và userId=2)

---

## 🚀 Các Bước Demo

### **Bước 1: Start Java Server**

```powershell
cd D:\D_A_T_A\Du_an\DACS4\study-p2p\server-java\demo
mvn clean package
java -jar target\demo-*.jar
```

**Kiểm tra console** phải thấy:
```
REST: http://127.0.0.1:8080
WS  : ws://127.0.0.1:8081/ws
Chat Relay: ws://127.0.0.1:8082/chat-relay/{userId}
```

---

### **Bước 2: Start Flutter Instance 1 (User ID = 1)**

```powershell
cd D:\D_A_T_A\Du_an\DACS4\study-p2p\flutter-app\flutter_application_1
flutter run
```

**Quan trọng**: 
- Login với user ID = 1 (ví dụ: `alice@study.vn`)
- **GHI NHỚ WINDOW NÀY LÀ "ALICE"**

---

### **Bước 3: Start Flutter Instance 2 (User ID = 2)**

**MỞ TERMINAL MỚI**, chạy:

```powershell
cd D:\D_A_T_A\Du_an\DACS4\study-p2p\flutter-app\flutter_application_1
flutter run
```

**Quan trọng**:
- Login với user ID = 2 (ví dụ: `bob@study.vn`)
- **GHI NHỚ WINDOW NÀY LÀ "BOB"**

---

### **Bước 4: Alice Gửi Tin Cho Bob**

1. Trong **WINDOW ALICE** (user=1):
   - Vào tab **Friends**
   - Tìm user **Bob** (userId=2)
   - Nhấn **3 chấm (⋮)** → Chọn **"Message"**

2. Màn hình chat mở ra:
   - **Status sẽ hiển thị**:
     - 🟢 `"P2P Direct"` nếu kết nối thành công
     - 🔵 `"Via Server"` nếu dùng relay
     - 🟡 `"Connecting..."` khi đang kết nối

3. **Gõ tin nhắn** và nhấn **Send**

---

### **Bước 5: Bob Nhận Tin và Trả Lời**

1. Trong **WINDOW BOB** (user=2):
   - Vào tab **Friends**
   - Tìm user **Alice** (userId=1)
   - Nhấn **⋮** → **"Message"**

2. **Bạn sẽ thấy** tin nhắn từ Alice!

3. **Gõ trả lời** và send

---

## 🔍 Cách Hoạt Động

### **Kịch Bản 1: P2P Direct (Same Machine)**

```
Alice (Port 9001)  ←──P2P TCP──→  Bob (Port 9002)
     ↓ register                        ↓ register
   Server Registry              Server Registry
   { userId:1, ip:127.0.0.1, port:9001 }
   { userId:2, ip:127.0.0.1, port:9002 }
```

1. Alice start → bind port **9001** ✅
2. Bob start → port 9001 bận → bind port **9002** ✅
3. Cả hai **register** IP:Port lên server
4. Alice nhấn Message → server trả về Bob ở `127.0.0.1:9002`
5. Alice **kết nối P2P** đến `127.0.0.1:9002` → **SUCCESS** 🟢

---

### **Kịch Bản 2: Relay Mode (Nếu P2P Fail)**

```
Alice  ──WebSocket──→  Server Relay  ──WebSocket──→  Bob
                        (Port 8082)
```

1. Nếu P2P không kết nối được (firewall, etc.)
2. Tự động dùng **WebSocket Relay**
3. Alice send → Server → Bob
4. Status hiển thị: 🔵 `"Via Server"`

---

## 🐛 Troubleshooting

### ❌ "Không thấy tin nhắn"

**Nguyên nhân có thể**:

1. **Chưa là bạn bè**:
   ```sql
   -- Check trong database:
   SELECT * FROM friendships WHERE user_id_a IN (1,2) AND user_id_b IN (1,2);
   ```
   - Nếu không có record → cần add friend trước

2. **Server chưa chạy**:
   - Check console có thấy "Chat Relay: ws://127.0.0.1:8082..." không
   - Thử `curl http://127.0.0.1:8080/api/chat/peer/1`

3. **Port conflict**:
   - Check console Flutter, phải thấy:
     ```
     🟢 Hybrid Chat started on port 9001 for userId 1
     🟢 Hybrid Chat started on port 9002 for userId 2
     ```
   - Nếu cả 2 đều port 9001 → có lỗi!

4. **currentUserId sai**:
   - Trong `friends_tab.dart` đang hardcode `currentUserId: 1`
   - Nếu cả 2 instances đều login user khác nhau nhưng đều gửi `currentUserId=1` → lỗi!
   - **FIX**: Phải lấy real userId từ AuthService

---

### ❌ "Connection timeout"

- **Firewall**: Windows Defender có thể block port 9001, 9002
- **Giải pháp**: Tạm tắt firewall hoặc allow `dart.exe`

---

### ❌ "Cả 2 đều là user 1"

- Vấn đề: `friends_tab.dart` hardcode `currentUserId: 1`
- **FIX tạm thời**: 
  - Edit file, instance 2 đổi thành `currentUserId: 2`
  - Rebuild app

---

## ✅ Kết Quả Mong Đợi

### Console Logs:

**Instance Alice (userId=1)**:
```
🟢 Hybrid Chat started on port 9001 for userId 1
🔵 Trying P2P to friend 2 at 127.0.0.1:9002
✅ P2P connected to 127.0.0.1:9002
📤 Sending via P2P to 127.0.0.1:9002
```

**Instance Bob (userId=2)**:
```
🟢 Hybrid Chat started on port 9002 for userId 2
🔵 Trying P2P to friend 1 at 127.0.0.1:9001
✅ P2P connected to 127.0.0.1:9001
📨 Received from 127.0.0.1:9001: Hello Bob!
```

### UI:
- Chat screen hiển thị: **🟢 "P2P Direct"**
- Tin nhắn xuất hiện **ngay lập tức** ở cả 2 bên
- Bubble chat màu **xanh** (tin của mình) và **xám** (tin của bạn)

---

## 🎓 Giải Thích Cho Thầy

**Demo này chứng minh**:

1. ✅ **P2P Networking**: 2 clients kết nối **trực tiếp** qua TCP socket
2. ✅ **Server Registry**: Server giúp **discovery** (tìm IP:Port của friend)
3. ✅ **Hybrid Architecture**: Tự động fallback về Relay nếu P2P fail
4. ✅ **Local Storage**: Lịch sử chat lưu JSON trên mỗi máy

**Lưu ý**: Đây là P2P **Hybrid**, không phải pure P2P, vì:
- Có server giúp discovery
- Có relay làm backup khi P2P không khả dụng
- Nhưng vẫn **ưu tiên P2P** khi có thể → nhanh hơn, giảm tải server

---

## 🔧 Nâng Cao (Optional)

### Demo Relay Mode

Để test relay mode, tắt P2P bằng cách:

1. Edit `hybrid_chat_service.dart`:
   ```dart
   Future<bool> connectToFriend(int friendId) async {
     // Force relay mode for testing
     // Comment out P2P logic:
     /*
     final info = await ChatApiService.getFriendPeerInfo(friendId);
     if (info['online'] == true) { ... }
     */
     
     // Directly open relay:
     final ws = await WebSocket.connect(...);
     ...
   }
   ```

2. Rebuild app → Status sẽ luôn hiển thị 🔵 "Via Server"

---

**Good luck với demo! 🚀**
