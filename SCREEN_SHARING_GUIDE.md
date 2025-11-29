# 🖥️ Screen Sharing P2P - Hướng Dẫn Sử Dụng

## 📚 **TỔNG QUAN**

Chức năng **Screen Sharing** cho phép người dùng chia sẻ màn hình của mình với tất cả người khác trong room thông qua WebRTC P2P Mesh.

### **Đặc điểm:**
- ✅ **P2P Direct**: Màn hình được stream trực tiếp đến tất cả peers (không qua server)
- ✅ **Replace Track**: Sử dụng `RTCRtpSender.replaceTrack()` để chuyển đổi mượt mà
- ✅ **Auto Detect Stop**: Tự động dừng khi user nhấn "Stop Sharing" từ browser
- ✅ **Fallback to Camera**: Tự động quay về camera khi dừng share
- ✅ **Real-time**: Không cần renegotiation SDP (không cần offer/answer mới)

---

## 🏗️ **KIẾN TRÚC KỸ THUẬT**

### **1. Luồng hoạt động**

```
┌─────────────┐
│   User A    │
│  (Sharing)  │
└──────┬──────┘
       │
       │ 1. Click "Share Screen"
       ▼
┌────────────────────────────┐
│ getDisplayMedia()          │
│ → Capture screen stream    │
└────────────┬───────────────┘
             │
             │ 2. Get screen video track
             ▼
┌────────────────────────────┐
│ For each PeerConnection:   │
│   - Find video sender      │
│   - replaceTrack(screen)   │
└────────────┬───────────────┘
             │
             │ 3. Screen stream sent to peers
             ▼
┌─────────────┬─────────────┐
│   User B    │   User C    │
│ (Watching)  │ (Watching)  │
└─────────────┴─────────────┘
```

### **2. Code Flow**

#### **2.1. Start Screen Sharing**

```dart
Future<void> _startScreenSharing() async {
  // 1️⃣ Capture màn hình
  final screenStream = await navigator.mediaDevices.getDisplayMedia({
    'video': {'width': 1920, 'height': 1080, 'frameRate': 30},
    'audio': false,
  });

  // 2️⃣ Lưu stream và update local renderer
  _screenStream = screenStream;
  _localRenderer.srcObject = screenStream;

  // 3️⃣ Listen sự kiện user stop share từ browser
  screenStream.getVideoTracks().first.onEnded = () {
    _stopScreenSharing();
  };

  // 4️⃣ Replace video track trong TẤT CẢ PeerConnections
  final screenVideoTrack = screenStream.getVideoTracks().first;
  for (final peer in _peers.values) {
    final senders = await peer.pc!.getSenders();
    final videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
    
    // 🔥 MAGIC: Replace track without renegotiation
    await videoSender.replaceTrack(screenVideoTrack);
  }
}
```

**Giải thích:**
- `getDisplayMedia()`: Browser API để capture screen/window/tab
- `replaceTrack()`: Thay track mới vào sender đã có → **KHÔNG CẦN** offer/answer mới
- `onEnded`: Event bắn khi user click "Stop Sharing" từ browser UI

#### **2.2. Stop Screen Sharing**

```dart
Future<void> _stopScreenSharing() async {
  // 1️⃣ Stop và dispose screen stream
  _screenStream!.getTracks().forEach((t) => t.stop());
  await _screenStream!.dispose();

  // 2️⃣ Quay về camera stream
  _localRenderer.srcObject = _localStream;

  // 3️⃣ Replace lại về camera track trong TẤT CẢ PeerConnections
  final cameraVideoTrack = _localStream!.getVideoTracks().first;
  for (final peer in _peers.values) {
    final senders = await peer.pc!.getSenders();
    final videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
    
    await videoSender.replaceTrack(cameraVideoTrack);
  }
}
```

---

## 🎨 **GIAO DIỆN NGƯỜI DÙNG**

### **1. Button Screen Share**

Vị trí: Bottom controls, giữa camera button và hang up button

```dart
IconButton(
  icon: Icon(
    _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
    color: _isScreenSharing ? Colors.green : null,
  ),
  onPressed: _toggleScreenSharing,
  tooltip: _isScreenSharing ? 'Dừng chia sẻ màn hình' : 'Chia sẻ màn hình',
)
```

**Trạng thái:**
- 🟢 **Xanh lá** khi đang share (icon: `stop_screen_share`)
- ⚪ **Mặc định** khi chưa share (icon: `screen_share`)

### **2. Label Indicator**

Local video tile hiển thị:
- `"You (Local)"` → Bình thường
- `"🖥️ You (Sharing Screen)"` → Đang share

---

## 🧪 **HƯỚNG DẪN TEST**

### **Test 1: Screen Sharing giữa 2 người**

**Bước 1:** Chạy 2 instances, cả 2 join cùng room

**Bước 2:** User A click button "Share Screen"
- Browser hiện popup chọn: **Entire Screen / Window / Chrome Tab**
- Chọn màn hình muốn share → Click "Share"

**Bước 3:** Verify
- ✅ User A: Local tile hiển thị màn hình đang share (có label "🖥️ Sharing Screen")
- ✅ User B: Remote tile hiển thị màn hình của User A
- ✅ Button screen share của User A chuyển xanh

**Bước 4:** User A click lại button (hoặc click "Stop Sharing" từ browser)
- ✅ User A: Quay về camera
- ✅ User B: Thấy camera của User A

---

### **Test 2: Screen Sharing trong nhóm 3+ người**

**Setup:** 3 instances join cùng room

**Kịch bản:**
1. User A share màn hình
   - ✅ User B và C đều thấy màn hình của A
2. User B share màn hình (trong khi A vẫn đang share)
   - ✅ A và C thấy màn hình của B
   - ✅ B và C thấy màn hình của A
   - ✅ A thấy camera của C
3. A dừng share
   - ✅ B và C thấy camera của A
   - ✅ A và C vẫn thấy màn hình của B

**→ Kết luận:** Mỗi người có thể share độc lập, viewers thấy đúng stream của từng người

---

### **Test 3: Browser "Stop Sharing" button**

**Bước 1:** User share màn hình

**Bước 2:** Click nút **"Stop Sharing"** từ browser tab (không phải button trong app)

**Kết quả mong đợi:**
- ✅ `onEnded` event được trigger
- ✅ `_stopScreenSharing()` tự động được gọi
- ✅ App quay về camera
- ✅ Peers thấy camera (không còn màn hình)

---

## 🔧 **KỸ THUẬT & TỐI ƯU**

### **1. Tại sao dùng `replaceTrack()` thay vì tạo PC mới?**

**❌ Cách cũ (renegotiation):**
```dart
// Phải removeTrack → addTrack → createOffer → setLocal → send offer
// → peer setRemote → createAnswer → peer setLocal → send answer
// → setRemote answer → 🕐 Mất 2-3 giây
```

**✅ Cách mới (replaceTrack):**
```dart
videoSender.replaceTrack(newTrack);
// → Instant! Không cần SDP negotiation
```

**Kết quả:**
- Thời gian chuyển đổi: **<100ms** (thay vì 2-3 giây)
- Không cần signaling messages mới
- Smooth transition

---

### **2. Resolution & Bitrate**

**Cấu hình hiện tại:**
```dart
'video': {
  'width': 1920,    // Full HD
  'height': 1080,
  'frameRate': 30,  // 30 FPS
}
```

**Tùy chỉnh cho bandwidth thấp:**
```dart
'video': {
  'width': 1280,    // HD
  'height': 720,
  'frameRate': 15,  // Giảm FPS
}
```

**Adaptive Bitrate:** WebRTC tự động điều chỉnh bitrate dựa vào:
- Network conditions
- CPU usage
- Receiver feedback (REMB)

---

### **3. Audio từ màn hình**

**Hiện tại:** Chỉ capture video (không có system audio)

**Bật audio:**
```dart
'audio': true,  // ⚠️ Chỉ Chrome Desktop hỗ trợ
```

**Lưu ý:**
- Chỉ Chrome/Edge Desktop hỗ trợ capture system audio
- Firefox/Safari không hỗ trợ
- Mobile không hỗ trợ

---

## 🐛 **TROUBLESHOOTING**

### **Lỗi 1: "Permission Denied"**
```
Nguyên nhân: Browser chặn getDisplayMedia()
Giải pháp:
- Phải HTTPS (hoặc localhost)
- User phải tương tác (click button) trước khi gọi API
- Kiểm tra browser permissions
```

### **Lỗi 2: "No video sender found"**
```
Nguyên nhân: PeerConnection chưa có video track
Giải pháp:
- Đảm bảo đã add camera track trước khi share screen
- Check _localStream != null
```

### **Lỗi 3: Màn hình đen sau khi stop share**
```
Nguyên nhân: Camera track đã bị stop
Giải pháp:
- Không stop camera track khi start screen share
- Giữ _localStream active suốt session
```

### **Lỗi 4: Peers không thấy màn hình**
```
Nguyên nhân: replaceTrack() failed hoặc không được call
Debug:
- Check console: "🖥️ Replaced video track for peer=xxx"
- Verify peer.pc != null
- Check PC connection state
```

---

## 📊 **SO SÁNH SCREEN SHARE vs CAMERA**

| Tiêu chí              | Camera              | Screen Share         |
|-----------------------|---------------------|----------------------|
| **Resolution**        | 640×480 (VGA)       | 1920×1080 (Full HD)  |
| **Frame Rate**        | 30 FPS              | 30 FPS               |
| **Bitrate**           | ~500 kbps           | ~2-3 Mbps            |
| **CPU Usage**         | Thấp                | Cao hơn (encoding)   |
| **Bandwidth (upload)**| ~500 kbps × (n-1)   | ~2-3 Mbps × (n-1)    |
| **Use Case**          | Video call          | Demo, presentation   |

**Lưu ý:** Screen share tốn bandwidth và CPU nhiều hơn → Nên giới hạn số người (<6)

---

## ✅ **CHECKLIST IMPLEMENTATION**

- [x] Thêm `_isScreenSharing` flag
- [x] Thêm `_screenStream` state variable
- [x] Implement `_startScreenSharing()` với `getDisplayMedia()`
- [x] Implement `_stopScreenSharing()` quay về camera
- [x] Implement `_toggleScreenSharing()`
- [x] Replace video track trong tất cả PeerConnections
- [x] Listen `onEnded` event để auto stop
- [x] Thêm screen share button vào UI
- [x] Update label hiển thị "Sharing Screen"
- [x] Cleanup screen stream trong `dispose()` và `_leave()`
- [x] Hiển thị SnackBar notification
- [x] Handle errors gracefully

---

## 🎓 **TRẢ LỜI CÂU HỎI GIẢNG VIÊN**

### **1. Screen sharing hoạt động như thế nào?**
> Sử dụng `getDisplayMedia()` để capture màn hình thành MediaStream, sau đó dùng `RTCRtpSender.replaceTrack()` để thay video track trong PeerConnection. Không cần renegotiation SDP nên chuyển đổi rất nhanh.

### **2. Tại sao không cần offer/answer mới?**
> `replaceTrack()` chỉ thay track trong sender đã có sẵn, không thay đổi cấu trúc SDP. WebRTC spec cho phép thay track cùng loại (video→video) mà không cần renegotiate.

### **3. Xử lý như thế nào khi nhiều người cùng share?**
> Mỗi peer quản lý stream riêng. Peer A share → A gửi screen đến B,C. Peer B share → B gửi screen đến A,C. Viewer thấy đúng stream của từng người theo PeerConnection tương ứng.

### **4. Bandwidth tăng bao nhiêu?**
> Screen Full HD ~2-3 Mbps. Với 4 người, người share cần upload: 3 × 2.5 Mbps = **7.5 Mbps**. Tốn gấp 15× so với camera 640×480.

---

## 🚀 **FUTURE ENHANCEMENTS**

### **1. Multiple Screen Sources**
- Cho phép chọn: Entire Screen / Specific Window / Browser Tab
- UI selector trước khi share

### **2. Screen + Camera Picture-in-Picture**
- Hiển thị camera nhỏ ở góc khi đang share screen
- Layout: Screen (chính) + Camera (PiP)

### **3. Annotation Tools**
- Vẽ trên màn hình đang share
- Highlight, arrow, text

### **4. Recording**
- Record screen share vào file
- Export MP4/WebM

---

**📅 Ngày tạo:** 29/11/2025  
**👨‍💻 Người thực hiện:** GitHub Copilot + User  
**🎯 Mục đích:** Đồ án học phần DACS4 - Screen Sharing P2P WebRTC
