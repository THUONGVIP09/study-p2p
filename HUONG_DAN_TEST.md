# Hướng Dẫn Test P2P Chat

## ✅ Checklist Test

### 1️⃣ Test Kết Nối P2P

**Bước thực hiện**:
1. Mở 2 trình duyệt (ví dụ: Chrome và Edge)
2. Vào cùng 1 room
3. Mở Console (F12) ở cả 2 trình duyệt

**Kết quả mong đợi** (trong Console):
```
✅ WebRTC P2P Chat peer init for peer_xxx
📤 Sending WebRTC offer to peer_xxx
📥 Received WebRTC answer from peer_xxx
📥 Received ICE candidate from peer_xxx
✅ DataChannel opened with peer_xxx
```

**Nếu thấy**: ✅ → Kết nối P2P thành công!

---

### 2️⃣ Test Gửi Tin Nhắn P2P

**Bước thực hiện**:
1. Gõ tin nhắn ở Peer A
2. Bấm Gửi
3. Kiểm tra Console ở cả 2 peer

**Console Peer A** (người gửi):
```
📤 Broadcast to 1 peers via P2P DataChannel
```

**Console Peer B** (người nhận):
```
📥 Received P2P message from peer_A
```

**Kết quả mong đợi**:
- Tin nhắn hiện ở Peer B NGAY LẬP TỨC
- **KHÔNG** có log "Server relay" ở server

---

### 3️⃣ Test Server KHÔNG Relay Chat

**Bước thực hiện**:
1. Gửi tin nhắn
2. Kiểm tra log của Java server

**Server log phải hiển thị**:
```
🚫 P2P Mode - Skip server chat relay
```

**KHÔNG ĐƯỢC** thấy:
```
❌ Forwarding chat to peer_xxx
❌ Broadcasting chat to room
```

**Nếu server đang relay chat** → Kiểm tra lại:
- `SignalingEndpoint.java` line 270-292 đã disabled chưa?
- `call_page.dart` `_broadcastToPeersP2P()` có dùng `_ws?.sink.add()` không?

---

### 4️⃣ Test Server Shutdown (Bằng Chứng P2P Thật)

⚠️ **ĐÂY LÀ TEST QUAN TRỌNG NHẤT** - chứng minh P2P thật sự!

**Bước thực hiện**:
1. Mở 2 trình duyệt, join cùng room
2. Chờ kết nối WebRTC thiết lập (thấy "DataChannel opened" trong Console)
3. **TẮT server Java** (stop Spring Boot application)
4. Gửi tin nhắn giữa 2 peer

**Kết quả mong đợi**:
- ✅ Tin nhắn **VẪN HOẠT ĐỘNG** dù server đã tắt!
- ✅ Chat hiện ngay lập tức ở peer kia

**Tại sao?**
→ Chat đi trực tiếp peer-to-peer qua WebRTC DataChannel, KHÔNG qua server!

**Nếu tin nhắn không hoạt động khi tắt server**:
❌ → Chưa phải P2P thật, còn dính server relay
→ Kiểm tra lại code `_broadcastToPeersP2P()`

---

## 🐛 Xử Lý Lỗi Thường Gặp

### ❌ Lỗi: DataChannel không mở

**Triệu chứng**:
```
❌ Failed to init WebRTC P2P for peer_xxx
```

**Nguyên nhân**:
1. STUN server không kết nối được
2. Signaling message không đến peer (kiểm tra WebSocket)
3. ICE candidates không được trao đổi

**Cách fix**:
- Kiểm tra kết nối mạng
- Verify server có forward signaling messages không (offer/answer/ice)
- Thử STUN server khác: `stun.l.google.com:19302`

---

### ❌ Lỗi: Gửi được nhưng không nhận

**Triệu chứng**: Bấm gửi OK nhưng peer kia không nhận được

**Debug**:
1. Check DataChannel state trong Console:
   ```
   DataChannel state: open
   ```
   Phải là `open`, không phải `connecting` hay `closed`

2. Verify `_broadcastToPeersP2P()` có gọi P2P method:
   ```dart
   _webrtcP2PChat!.broadcast(message); // ✅ Phải có dòng này
   ```

3. Check server log KHÔNG được relay:
   ```
   🚫 P2P Mode - Skip server chat relay  // ✅ Phải thấy dòng này
   ```

---

### ❌ Lỗi: Tắt server thì chat ngừng hoạt động

**Vấn đề**: Chưa phải P2P thật, vẫn còn relay qua server

**Kiểm tra**:
1. File `call_page.dart`, method `_broadcastToPeersP2P()`:
   ```dart
   // ❌ SAI - Vẫn dùng server
   if (_ws != null) {
     _ws!.sink.add(jsonEncode({...}));
   }
   
   // ✅ ĐÚNG - Pure P2P
   if (kIsWeb && _webrtcP2PChat != null) {
     _webrtcP2PChat!.broadcast(message);
   }
   ```

2. File `SignalingEndpoint.java`:
   ```java
   case "chat":
     debugPrint("🚫 P2P Mode - Skip server chat relay");
     break;  // ✅ PHẢI break, KHÔNG được forward
   ```

---

## 📊 So Sánh Trước vs Sau

### Trước (Server Relay)
```
Peer A → Server → Peer B
```
- Server xử lý mọi tin nhắn
- Tắt server → Chat ngừng
- Tốn băng thông server

### Sau (Pure P2P)
```
Peer A ══► Peer B (Trực tiếp)
```
- Server CHỈ giúp kết nối ban đầu
- Tắt server → Chat **VẪN HOẠT ĐỘNG**
- Không tốn băng thông server

---

## 🎯 Các Loại Message

### Server Signaling (qua WebSocket)
```json
// Chỉ dùng để thiết lập kết nối P2P
{
  "type": "webrtc.offer",
  "to": "peer_B",
  "from": "peer_A",
  "sdp": "..."
}
```

### Chat P2P (qua DataChannel)
```json
// Đi trực tiếp peer-to-peer, KHÔNG qua server
{
  "type": "chat",
  "text": "Hello",
  "senderId": "peer_A",
  "timestamp": "..."
}
```

---

## 🚀 Sau Khi Test Thành Công

**Bạn đã có**:
- ✅ WebRTC P2P Chat thật sự
- ✅ Server chỉ quản lý peer list
- ✅ Chat không qua server relay
- ✅ Hoạt động ngay cả khi server tắt

**Optional - Có thể thêm**:
- TURN server cho NAT phức tạp
- File sharing qua DataChannel
- Video/Audio call qua WebRTC
- Connection quality indicator

---

**Chúc test thành công! 🎉**
