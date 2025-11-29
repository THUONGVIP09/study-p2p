# 🌐 P2P Mesh Topology - Hướng Dẫn Sử Dụng

## 📚 **MÔ HÌNH MẠNG P2P MESH**

### **1. Lý thuyết**

**P2P Mesh** là mô hình mạng ngang hàng (peer-to-peer) trong đó mỗi người tham gia kết nối **trực tiếp** với **tất cả** người khác trong room.

#### **Công thức số kết nối:**
```
Số kết nối = n × (n - 1) / 2
```

Trong đó `n` = số người tham gia.

**Ví dụ:**
- 2 người: 1 kết nối
- 3 người: 3 kết nối  
- 4 người: 6 kết nối
- 5 người: 10 kết nối
- 10 người: 45 kết nối

#### **Ưu điểm:**
- ✅ Độ trễ thấp (kết nối trực tiếp)
- ✅ Không phụ thuộc server trung gian để relay media
- ✅ Chất lượng video/audio tốt hơn

#### **Nhược điểm:**
- ❌ Tăng băng thông tại mỗi client (upload × (n-1))
- ❌ Không phù hợp với số lượng lớn (>10 người)
- ❌ Yêu cầu kết nối mạng tốt

---

## 🏗️ **KIẾN TRÚC HỆ THỐNG**

### **1. Backend (Java WebSocket)**

File: `server-java/demo/src/main/java/com/study/SignalingEndpoint.java`

**Chức năng:**
- Quản lý danh sách peers trong từng room
- Gửi thông báo `peers` khi client join (danh sách người có sẵn)
- Broadcast sự kiện `peer.joined` / `peer.left`
- Relay SDP (offer/answer) và ICE candidates giữa các peers

**WebSocket messages:**
```json
// Client → Server: Join room
{"t": "join", "room": "R000001", "uid": "123-abc", "name": "User 1"}

// Server → Client: Danh sách peers có sẵn
{"t": "peers", "peers": [{"uid": "456-def", "name": "User 2"}]}

// Server → Broadcast: Có người mới join
{"t": "peer.joined", "uid": "789-ghi", "name": "User 3"}

// Client → Server: Gửi offer cho peer cụ thể
{"t": "offer", "from": "123-abc", "to": "456-def", "sdp": "...", "type": "offer"}

// Server → Client: Relay answer
{"t": "answer", "from": "456-def", "to": "123-abc", "sdp": "...", "type": "answer"}

// Client → Server: Gửi ICE candidate
{"t": "ice", "from": "123-abc", "to": "456-def", "candidate": "...", "sdpMid": "...", "sdpMLineIndex": 0}

// Server → Broadcast: Có người rời phòng
{"t": "peer.left", "uid": "456-def"}
```

---

### **2. Frontend (Flutter WebRTC)**

File: `lib/call_page.dart`

**Thay đổi chính:**

#### **2.1. State variables (trước và sau)**

**Trước (P2P đơn giản):**
```dart
RTCVideoRenderer _remoteRenderer;
RTCPeerConnection? _pc;
String? _remoteUid;
```

**Sau (P2P Mesh):**
```dart
// 🌐 Map lưu thông tin từng peer
Map<String, PeerInfo> _peers = {};

class PeerInfo {
  final String uid;
  final String name;
  final RTCVideoRenderer renderer;  // Mỗi peer có renderer riêng
  RTCPeerConnection? pc;             // Mỗi peer có PC riêng
}
```

#### **2.2. Luồng xử lý khi join room**

**Kịch bản 1: Mình vào phòng có SẴN 2 người (A, B)**
```
1. Mình gửi: {t: "join", room: "R000001", uid: "C"}
2. Server trả: {t: "peers", peers: [{uid: "A"}, {uid: "B"}]}
3. Mình tạo PC cho A → gửi offer(C→A)
4. Mình tạo PC cho B → gửi offer(C→B)
5. A nhận offer(C→A) → gửi answer(A→C)
6. B nhận offer(C→B) → gửi answer(B→C)
7. Trao đổi ICE candidates
8. Kết nối thành công: C↔A, C↔B
```

**Kịch bản 2: Mình vào phòng TRỐNG → D join sau**
```
1. Mình vào → Server trả: {t: "peers", peers: []} (rỗng)
2. D join → Server broadcast: {t: "peer.joined", uid: "D"}
3. D tự nhận peers=[{uid: "C"}] → D tạo PC → gửi offer(D→C)
4. Mình nhận offer(D→C) → tạo PC cho D → gửi answer(C→D)
5. Trao đổi ICE
6. Kết nối: C↔D
```

#### **2.3. Grid Layout (UI)**

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: _calculateColumns(totalParticipants),
    childAspectRatio: 1.0,
  ),
  itemCount: 1 + _peers.length,  // local + remotes
  itemBuilder: (context, index) {
    if (index == 0) return _buildLocalVideoTile();
    else return _buildRemoteVideoTile(_peers.values.toList()[index - 1]);
  },
)
```

**Số cột tự động:**
- 1 người: 1 cột (fullscreen)
- 2 người: 2 cột (chia đôi màn hình)
- 3-4 người: 2 cột × 2 hàng
- 5-9 người: 3 cột × 3 hàng
- 10+ người: 4 cột

---

## 🧪 **HƯỚNG DẪN TEST**

### **Test 1: 2 Instance trên cùng 1 máy**

**Bước 1: Chạy backend**
```bash
cd server-java/demo
mvn spring-boot:run
```

**Bước 2: Chạy Flutter instance 1**
```bash
cd flutter-app/flutter_application_1
flutter run -d windows
```

**Bước 3: Chạy Flutter instance 2 (terminal khác)**
```bash
cd flutter-app/flutter_application_1
flutter run -d windows
```

**Bước 4: Tạo room và join**
- Instance 1: Tạo room "Test Mesh"
- Instance 2: Join room "Test Mesh"

**Kết quả mong đợi:**
- ✅ Instance 1: GridView 2 ô (Local + Remote từ Instance 2)
- ✅ Instance 2: GridView 2 ô (Local + Remote từ Instance 1)
- ⚠️ Chỉ 1 instance có camera (hardware limitation)
- ✅ Instance không có cam → Audio-only mode với placeholder

---

### **Test 2: 3 Instance (giả lập 3 người)**

**Cách 1: 3 máy khác nhau**
- Máy A, B, C join cùng 1 room
- Mỗi máy thấy GridView 3 ô (local + 2 remotes)

**Cách 2: 1 máy + 2 mobile emulator/device**
- Windows: `flutter run -d windows`
- Android Emulator 1: `flutter run -d emulator-5554`
- Android Emulator 2: `flutter run -d emulator-5556`

**Kết quả mong đợi:**
- ✅ Mỗi instance thấy **3 ô video** trong grid
- ✅ Grid tự động chuyển sang **2 cột × 2 hàng**
- ✅ Tổng **3 kết nối WebRTC** (A↔B, A↔C, B↔C)

---

### **Test 3: 4+ Instance (stress test)**

**Setup:**
```bash
# Terminal 1-4
flutter run -d windows
flutter run -d chrome
flutter run -d emulator-5554
flutter run -d edge
```

**Kết quả mong đợi:**
- ✅ Grid **2 cột × 2 hàng** (4 người)
- ✅ Tổng **6 kết nối** (4×3/2)
- ⚠️ Bandwidth tăng đáng kể (upload × 3)

---

## 🔍 **DEBUG & TROUBLESHOOTING**

### **1. Kiểm tra console logs**

**Tìm các messages:**
```
🔌 WS connect: ws://192.168.x.x:8081/ws
📋 Received peers: 2
✅ Added peer: 456-def (User 2)
📤 send OFFER to=456-def
📥 setRemoteDescription(answer) from=456-def
📺 onTrack from peer=456-def stream=xxx kind=video
```

### **2. Lỗi thường gặp**

#### **Lỗi 1: Không nhận được video từ remote**
```
Nguyên nhân: ICE candidates không trao đổi
Giải pháp: 
- Kiểm tra STUN server: stun.l.google.com:19302
- Kiểm tra firewall
- Xem console có message "❄️ addCandidate" không
```

#### **Lỗi 2: GridView bị blank**
```
Nguyên nhân: renderer.srcObject = null
Giải pháp:
- Kiểm tra onTrack có bắn không
- Verify setState() được gọi khi set srcObject
- Xem PC.connectionState
```

#### **Lỗi 3: Camera conflict (2 instance cùng máy)**
```
Nguyên nhân: Hardware limitation
Giải pháp:
- Instance 2 tự động fallback audio-only
- Hiển thị placeholder với icon microphone
- SnackBar thông báo: "📞 Camera không khả dụng. Chế độ chỉ Audio."
```

---

## 📊 **SO SÁNH P2P MESH vs SFU**

| Tiêu chí              | P2P Mesh                | SFU (Selective Forwarding Unit) |
|-----------------------|-------------------------|----------------------------------|
| **Độ trễ**            | ✅ Thấp (direct)        | ⚠️ Cao hơn (qua server)          |
| **Upload bandwidth**  | ❌ Cao (n-1 streams)    | ✅ Thấp (1 stream)               |
| **Số người tối đa**   | ❌ ~10 người            | ✅ 100+ người                    |
| **Chất lượng**        | ✅ Tốt nhất             | ⚠️ Phụ thuộc server              |
| **Phức tạp backend**  | ✅ Đơn giản (signaling) | ❌ Phức tạp (media relay)        |
| **Chi phí server**    | ✅ Thấp                 | ❌ Cao (bandwidth + CPU)         |

**Kết luận:**
- **P2P Mesh**: Phù hợp cho **cuộc gọi nhỏ** (2-6 người), yêu cầu chất lượng cao
- **SFU**: Phù hợp cho **webinar, lớp học online** với nhiều người

---

## ✅ **CHECKLIST HOÀN THÀNH**

- [x] Refactor state: `Map<String, PeerInfo>` thay vì single peer
- [x] Handle `peers` message → tạo offer cho từng peer
- [x] Handle `peer.joined` → tạo PC mới
- [x] Handle `peer.left` → cleanup PC + renderer
- [x] Implement offer/answer/ICE cho từng peer riêng biệt
- [x] GridView tự động điều chỉnh số cột (1→2→3→4)
- [x] Label hiển thị tên peer trên từng video tile
- [x] Audio-only mode cho peer không có camera
- [x] Cleanup tất cả PC khi leave room
- [x] Dispose tất cả renderer khi dispose widget

---

## 🎓 **TRẢ LỜI CÂU HỎI GIẢNG VIÊN**

### **1. Em dùng mô hình mạng gì?**
> P2P Mesh topology - mỗi người kết nối trực tiếp với tất cả người khác trong room. Số kết nối = n×(n-1)/2.

### **2. Tại sao không dùng SFU?**
> Vì đề tài học tập, mục tiêu hiểu rõ WebRTC cơ bản. P2P Mesh đơn giản hơn SFU (không cần media server relay), phù hợp cho demo nhóm nhỏ.

### **3. Xử lý như thế nào khi có 10 người?**
> Sẽ tạo 45 kết nối (10×9/2). Upload bandwidth = 9× stream gốc. Trên thực tế sẽ giảm resolution/bitrate tự động (WebRTC adaptive bitrate). Nhưng nên giới hạn <6 người cho trải nghiệm tốt.

### **4. Có test được không?**
> Có. Đã test 2 instance trên cùng máy (1 có cam, 1 audio-only). Có thể test 3-4 người với mobile emulator hoặc nhiều máy khác nhau.

---

## 📚 **TÀI LIỆU THAM KHẢO**

- [WebRTC for the Curious](https://webrtcforthecurious.com/)
- [Flutter WebRTC Plugin](https://pub.dev/packages/flutter_webrtc)
- [P2P Mesh vs SFU](https://bloggeek.me/webrtc-multiparty-video-alternatives/)
- [ICE, STUN, TURN explained](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Connectivity)

---

**📅 Ngày tạo:** 29/11/2025  
**👨‍💻 Người thực hiện:** GitHub Copilot + User  
**🎯 Mục đích:** Đồ án học phần DACS4 - WebRTC P2P Video Call
