# Hướng Dẫn: Audio-Only Mode trong P2P Call

## 🎯 Vấn đề

Khi demo trên **cùng 1 máy** với **nhiều instance** của ứng dụng:
- ✅ **Instance 1**: Có thể truy cập camera
- ❌ **Instance 2, 3, ...**: KHÔNG thể truy cập camera

**Nguyên nhân:** Camera là **exclusive hardware resource** - chỉ 1 process có thể sử dụng tại 1 thời điểm.

## ✅ Giải pháp: Graceful Degradation

### **1. Fallback Strategy**

```
Bước 1: Thử lấy Video + Audio
   ↓
   ├─ Thành công → Video Call Mode 🎥
   │
   └─ Thất bại (camera bận) → Fallback
                ↓
        Bước 2: Chỉ lấy Audio
           ↓
           ├─ Thành công → Audio-Only Mode 🎤
           │
           └─ Thất bại → Thông báo lỗi
```

### **2. Code Implementation**

**File:** `lib/call_page.dart`

#### A. Cờ trạng thái
```dart
bool _isAudioOnlyMode = false; // Flag cho chế độ audio-only
```

#### B. Hàm lấy media với fallback
```dart
Future<void> _startLocalStream({bool allowFailure = false}) async {
  try {
    // Bước 1: Thử lấy video + audio
    final stream = await getUserMedia({
      'audio': true,
      'video': {...}
    });
    // ✅ Thành công → Video mode
  } catch (e) {
    // ❌ Thất bại → Fallback
    try {
      // Bước 2: Chỉ lấy audio
      final audioStream = await getUserMedia({
        'audio': true,
        'video': false  // 🎤 Không cần video
      });
      
      _isAudioOnlyMode = true; // Đánh dấu
      // ✅ Thành công → Audio-only mode
      
    } catch (audioError) {
      // ❌ Cả audio cũng thất bại
      if (allowFailure) return;
      rethrow;
    }
  }
}
```

#### C. UI hiển thị audio-only
```dart
// Local view
_isAudioOnlyMode
  ? _buildAudioOnlyPlaceholder('You', Icons.mic)
  : RTCVideoView(_localRenderer)

// Placeholder widget
Widget _buildAudioOnlyPlaceholder(String label, IconData icon) {
  return Container(
    color: Colors.blueGrey[800],
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 64),
          Text(label),
          Text('🎤 Audio Only Mode'),
        ],
      ),
    ),
  );
}
```

## 🎬 Kịch bản Demo

### **Trên cùng 1 máy (2 instances)**

#### Instance 1 (chạy trước):
```
1. Launch → getUserMedia → ✅ Camera granted
2. UI: Hiển thị video bình thường 🎥
3. Join room → Video Call Mode
```

#### Instance 2 (chạy sau):
```
1. Launch → getUserMedia → ❌ Camera busy
2. Fallback → Audio-only → ✅ Success
3. UI: Hiển thị placeholder với icon 🎤
4. SnackBar: "📞 Camera không khả dụng. Chế độ chỉ Audio."
5. Join room → Audio-Only Mode
```

**Kết quả:**
- Instance 1: Thấy video của mình + nghe audio từ Instance 2
- Instance 2: Thấy video từ Instance 1 + placeholder audio của mình

## 🔍 Ưu điểm của giải pháp

✅ **Graceful degradation** - Không crash app
✅ **User-friendly** - Thông báo rõ ràng cho user
✅ **Vẫn có thể giao tiếp** - Voice call vẫn hoạt động
✅ **Phù hợp demo** - Có thể chạy nhiều instance trên 1 máy
✅ **Real-world scenario** - Xử lý như Discord/Teams (khi camera lỗi)

## 📊 So sánh với các app thực tế

| App | Hành vi khi camera bận |
|-----|------------------------|
| **Discord** | Chuyển sang voice-only |
| **Zoom** | Cho phép join meeting nhưng tắt camera |
| **Microsoft Teams** | Audio-only mode |
| **Dự án này** | ✅ Tương tự - Audio fallback |

## 🎓 Giải thích cho Thầy

### **Câu hỏi:** "Tại sao không có video ở instance thứ 2?"

**Trả lời:**
> "Thưa thầy, đây là giới hạn của phần cứng. Camera chỉ có thể được truy cập bởi 1 ứng dụng tại 1 thời điểm (exclusive access). 
> 
> Em đã implement **graceful degradation** - khi không lấy được camera, hệ thống tự động chuyển sang chế độ **Audio-Only**, 
> tương tự như Discord hay Microsoft Teams khi gặp lỗi camera.
> 
> Trong thực tế production, mỗi user sẽ chạy trên máy riêng nên không gặp vấn đề này."

### **Câu hỏi:** "Có thể share camera cho nhiều process không?"

**Trả lời:**
> "Về mặt kỹ thuật, có thể dùng **virtual camera driver** như OBS Virtual Camera, 
> nhưng đó là giải pháp phức tạp và nằm ngoài scope của đề tài. 
> 
> Giải pháp audio-fallback của em đảm bảo app vẫn hoạt động tốt trong mọi trường hợp,
> thể hiện được tư duy xử lý lỗi và UX design."

## 🧪 Cách test

### Test 1: Video mode (bình thường)
```bash
1. Chạy instance 1
2. Join room
3. Kết quả: Thấy video ✅
```

### Test 2: Audio-only mode (fallback)
```bash
1. Chạy instance 1 (đang dùng camera)
2. Chạy instance 2
3. Instance 2 join cùng room
4. Kết quả: 
   - Instance 2: Audio-only mode với placeholder
   - Instance 1: Vẫn thấy video của mình + nhận audio từ instance 2
   - Cả 2 đều nghe được nhau ✅
```

### Test 3: Multi-machine (production scenario)
```bash
1. Máy A: Chạy instance 1
2. Máy B: Chạy instance 2
3. Cả 2 join room
4. Kết quả: Cả 2 đều có video ✅✅
```

## 📝 Tài liệu tham khảo

- [WebRTC getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)
- [Flutter WebRTC Package](https://pub.dev/packages/flutter_webrtc)
- [Camera Exclusive Access (Windows)](https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/camera)

---

**Kết luận:** Giải pháp này thể hiện khả năng xử lý edge case và tư duy UX design, 
đồng thời cho phép demo được trên cùng 1 máy mà không cần nhiều thiết bị vật lý.
