# 🎯 HƯỚNG DẪN DEMO P2P HYBRID (Đã tích hợp bt2ltm patterns)

## 📋 Tổng quan

**Đã tích hợp 3 pattern ưu việt từ bt2ltm:**
1. ✅ **Dynamic Port Allocation**: `ServerSocket(0)` tự động chọn port khả dụng
2. ✅ **Broadcast Online List**: Server push updates qua WebSocket (không polling)
3. ✅ **Short-lived P2P Sockets**: Connect → Send → Close (đơn giản hơn persistent)

**Architecture:** P2P Hybrid = Server Registry + Broadcast + Direct P2P + Relay Fallback

**Ports:**
- `8080`: HTTP REST API (peer registry)
- `8082`: WebSocket (chat relay + online list broadcast)
- Dynamic: P2P TCP sockets (ngẫu nhiên)

**📌 Yêu cầu Database:**
- Database `study_p2p` đã có ít nhất 2 users
- 2 users đó phải là **bạn bè** của nhau (có record trong table `friendships`)
- Ví dụ: Alice (alice@study.vn) và Bob (bob@study.vn) đã kết bạn
- ⚠️ **KHÔNG ràng buộc userId cụ thể** - bất kỳ 2 users nào là bạn bè đều có thể demo!

---

## 🚀 Bước 1: Start Backend Server

```powershell
cd server-java/demo
mvn clean package
java -jar target/demo-1.0-SNAPSHOT.jar
```

**✅ Kiểm tra console phải thấy:**
```
Server started: http://127.0.0.1:8080/api
Chat Relay: ws://127.0.0.1:8082/chat-relay/{userId}
Online List: ws://127.0.0.1:8082/chat-online-list
```

---

## 🚀 Bước 2: Start Flutter Instance 1 (User A)

**Terminal 1:**
```powershell
cd flutter-app/flutter_application_1
flutter run -d windows
```

**Thao tác:**
1. Đăng nhập với **User A** (ví dụ: `alice@study.vn` / `pass123`)
2. Click tab **"Friends"**
3. **✅ KIỂM TRA CONSOLE LOG:**
   ```
   🟢 Hybrid Chat started on port XXXXX for userId <A_ID>
   ✅ Registered to server: 127.0.0.1:XXXXX
   Connected to online list broadcast
   ```
   - ⚠️ **Port XXXXX là số ngẫu nhiên** (không phải 9001 cố định nữa!)
   - `<A_ID>` là userId của User A (có thể là 1, 3, 15, bất kỳ số nào)

---

## 🚀 Bước 3: Start Flutter Instance 2 (User B)

**Terminal 2 (PowerShell mới):**
```powershell
cd flutter-app/flutter_application_1
flutter run -d windows
```

**Thao tác:**
1. Đăng nhập với **User B** - phải là **bạn bè** của User A (ví dụ: `bob@study.vn` / `pass123`)
2. Click tab **"Friends"** → phải thấy User A trong danh sách
3. **✅ KIỂM TRA CONSOLE LOG:**
   ```
   🟢 Hybrid Chat started on port YYYYY for userId <B_ID>
   ✅ Registered to server: 127.0.0.1:YYYYY
   Connected to online list broadcast
   ```
   - ⚠️ **Port YYYYY khác hoàn toàn với XXXXX** (vd: XXXXX=51234, YYYYY=52456)
   - `<B_ID>` là userId của User B (khác với `<A_ID>`)

---

## 🎉 Bước 4: Kiểm tra Online Status (NEW!)

**Tại CẢ 2 instances:**

### **UI Friends Tab:**
- ✅ Bạn bè hiển thị **chấm xanh ●** + text `"online"` nếu đang online
- ✅ **Chấm xám ●** + text `"offline"` nếu offline

### **Realtime Update (không cần refresh!):**
1. Khi Instance 2 vừa start → Instance 1 **TỰ ĐỘNG** cập nhật status Bob thành online
2. Khi đóng Instance 2 → sau ~60s, Instance 1 sẽ thấy Bob chuyển sang offline

### **Console Log:**
**Instance 1 (User A):**
```
Received online list: [{"userId":<A_ID>,"ip":"127.0.0.1","port":51234}, {"userId":<B_ID>,"ip":"127.0.0.1","port":52456}]
```

**Instance 2 (User B):**
```
Received online list: [{"userId":<A_ID>,"ip":"127.0.0.1","port":51234}, {"userId":<B_ID>,"ip":"127.0.0.1","port":52456}]
```

💡 `<A_ID>` và `<B_ID>` là userId thực tế từ database của 2 users đã đăng nhập

---

## 💬 Bước 5: Test P2P Chat

### **Instance 1 (User A):**
1. Tab "Friends" → click icon **message** (💬) bên cạnh tên User B
2. Chat screen mở ra
3. **✅ Kiểm tra status indicator** (góc trên):
   - `"P2P Direct"` hoặc `"Via Server"` → OK!
   - `"Connecting..."` → đợi 2-3 giây
4. Gửi tin nhắn: **"Hi from User A!"**
5. **✅ CONSOLE LOG:**
   ```
   ✅ Friend <B_ID> is online (from broadcast)
   📤 Sent to friend <B_ID> via P2P at 127.0.0.1:YYYYY
   ✅ P2P connection successful to 127.0.0.1:YYYYY
   ```

### **Instance 2 (User B):**
1. **✅ CONSOLE LOG:**
   ```
   📥 Received message from 127.0.0.1:XXXXX
   ```
   - Tin nhắn **tự động hiển thị** trong chat UI (nếu đang mở chat với User A)
2. Reply: **"Hello from User B!"**
3. **✅ CONSOLE LOG Instance 1:**
   ```
   📥 Received message from 127.0.0.1:YYYYY
   ```

---

## ⚠️ Bước 6: Test Relay Fallback

**Đóng Instance 2 (User B) hoàn toàn**

**Instance 1 (User A) gửi tin nhắn mới:**
- **✅ CONSOLE LOG:**
  ```
  ❌ P2P connection failed to 127.0.0.1:YYYYY
  📤 Sent via relay to friend <B_ID>
  ```
- ✅ Server nhận relay message nhưng không chuyển được (vì User B offline)

---

## 🔍 Các Log Quan Trọng

### **Backend Server Console:**
```
POST /api/chat/register - 200 OK (userId: <A_ID>)
Broadcast online list to 0 subscribers
POST /api/chat/register - 200 OK (userId: <B_ID>)
Broadcast online list to 2 subscribers
POST /api/chat/heartbeat - 200 OK (userId: <A_ID>)
Broadcast online list to 2 subscribers
```

💡 `<A_ID>` và `<B_ID>` là userId thực tế của 2 users đã đăng nhập

### **Flutter Console (Instance 1 - User A):**
```
🟢 Hybrid Chat started on port 51234 for userId <A_ID>
✅ Registered to server: 127.0.0.1:51234
Connected to online list broadcast
Received online list: [{"userId":<A_ID>,"ip":"127.0.0.1","port":51234}]

[30s sau khi Instance 2 start]
Received online list: [{"userId":<A_ID>,"ip":"127.0.0.1","port":51234}, {"userId":<B_ID>,"ip":"127.0.0.1","port":52456}]

[Khi chat với User B]
✅ Friend <B_ID> is online (from broadcast)
📤 Sent to friend <B_ID> via P2P at 127.0.0.1:52456
📥 Received message from 127.0.0.1:52456
```

### **Flutter Console (Instance 2 - User B):**
```
🟢 Hybrid Chat started on port 52456 for userId <B_ID>
✅ Registered to server: 127.0.0.1:52456
Connected to online list broadcast
Received online list: [{"userId":<A_ID>,"ip":"127.0.0.1","port":51234}, {"userId":<B_ID>,"ip":"127.0.0.1","port":52456}]

📥 Received message from 127.0.0.1:51234
📤 Sent to friend <A_ID> via P2P at 127.0.0.1:51234
```

---

## 🛠️ Troubleshooting

### ❌ Không thấy bạn bè trong danh sách Friends

**Nguyên nhân**: 2 users chưa kết bạn trong database

**Giải pháp:**
1. Kiểm tra table `friendships` trong database `study_p2p`:
   ```sql
   SELECT * FROM friendships WHERE user_id = <A_ID> AND friend_id = <B_ID>;
   ```
2. Nếu chưa có, tạo friendship:
   - Dùng API endpoint `/api/friends/request` để gửi lời mời kết bạn
   - Dùng API endpoint `/api/friends/accept` để chấp nhận
   - Hoặc insert trực tiếp vào database (chỉ để test)

### ❌ Không thấy chấm xanh online

**Nguyên nhân**: WebSocket broadcast chưa kết nối

**Giải pháp:**
1. Kiểm tra backend log có `"Broadcast online list"` không
2. Check Flutter console có `"Connected to online list broadcast"` không
3. Restart cả backend và app

### ❌ Port vẫn conflict (cùng số)

**Nguyên nhân**: Code chưa build lại sau khi sửa

**Giải pháp:**
```powershell
cd flutter-app/flutter_application_1
flutter clean
flutter pub get
flutter run -d windows
```

### ❌ Tin nhắn không đến

**Nguyên nhân 1**: Chưa lưu userId vào SharedPreferences
**Giải pháp**: Logout → Login lại cả 2 instances

**Nguyên nhân 2**: Server chưa có OnlineListEndpoint
**Giải pháp**:
```powershell
cd server-java/demo
mvn clean package
java -jar target/demo-1.0-SNAPSHOT.jar
```

### ❌ App crash khi gửi tin nhắn

**Kiểm tra console log:**
- `"No route to host"` → IP sai (dùng 127.0.0.1)
- `"Connection refused"` → Port sai hoặc P2P listener chưa start

---

## 📊 So sánh với bt2ltm

| Feature | bt2ltm | Study P2P Hybrid |
|---------|--------|------------------|
| Dynamic Ports | ✅ ServerSocket(0) | ✅ Đã tích hợp |
| Broadcast Online List | ✅ Server push | ✅ Đã tích hợp |
| Short-lived Sockets | ✅ Connect→Send→Close | ✅ Đã tích hợp |
| Relay Fallback | ❌ Không có | ✅ WebSocket relay |
| Persistent Storage | ❌ Không lưu | ✅ JSON local |
| Friends System | ❌ Không có | ✅ Full friends API |
| Cross-platform | ❌ Java Swing desktop only | ✅ Flutter (Win/Mac/Linux/iOS/Android) |
| Architecture | Simple P2P Hybrid | Advanced P2P Hybrid |
| UI Framework | Java Swing (desktop) | Flutter (modern) |

---

## ✅ Kết luận

### **Ưu điểm đã tích hợp từ bt2ltm:**
1. ✅ **Dynamic Port Allocation** → Không giới hạn số instances trên cùng máy
2. ✅ **Broadcast Online List** → Realtime updates, không cần polling
3. ✅ **Short-lived Sockets** → Đơn giản hơn, ít lỗi hơn

### **Ưu điểm giữ lại từ Study P2P:**
1. ✅ **Relay Fallback** → Chat vẫn hoạt động khi P2P fail
2. ✅ **Persistent Storage** → Lịch sử chat không mất khi restart
3. ✅ **Friends System** → Tích hợp với backend user management
4. ✅ **Cross-platform** → Flutter hỗ trợ mọi nền tảng

### **Kết quả:**
🎉 **Kết hợp tốt nhất của 2 thế giới**: bt2ltm's simplicity + Study P2P's features!

---

## 📝 Ghi chú

- File demo guide cũ: `DEMO_GUIDE_SAME_MACHINE.md` (outdated)
- File này: `DEMO_GUIDE_BT2LTM_INTEGRATED.md` (latest)
- Backend code: `server-java/demo/src/main/java/com/study/chat/OnlineListEndpoint.java`
- Frontend code: `lib/services/hybrid_chat_service.dart`, `lib/screens/friends/friends_tab.dart`
