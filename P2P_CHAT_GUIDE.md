# P2P Chat - Hướng Dẫn Sử Dụng

## 🎯 Mô Tả

Chức năng chat P2P (Peer-to-Peer) cho phép 2 thiết bị kết nối trực tiếp với nhau **KHÔNG CẦN SERVER**.

### ✨ Tính Năng

- ✅ **P2P thuần túy**: Kết nối TCP trực tiếp giữa 2 thiết bị
- ✅ **Hoạt động offline**: Không phụ thuộc vào Java server
- ✅ **Lưu local**: Lịch sử chat lưu trong JSON file trên mỗi máy
- ✅ **Auto discovery**: Tự động tìm peers trong cùng mạng LAN (UDP broadcast)
- ✅ **Manual connect**: Kết nối thủ công bằng IP:Port

---

## 🏗️ Kiến Trúc

```
Peer A (Flutter)                    Peer B (Flutter)
┌─────────────────┐               ┌─────────────────┐
│ TCP Listener    │ ◄──────────── │ TCP Client      │
│ Port: 9001      │               │                 │
│                 │               │                 │
│ Local Storage   │               │ Local Storage   │
│ (JSON File)     │               │ (JSON File)     │
│                 │               │                 │
│ UDP Discovery   │ ◄────────────►│ UDP Discovery   │
│ Port: 9002      │               │ Port: 9002      │
└─────────────────┘               └─────────────────┘
```

---

## 📱 Cách Sử Dụng

### 1. Mở P2P Chat

Trong app Flutter, navigate đến màn hình `P2PPeersListScreen`:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const P2PPeersListScreen()),
);
```

### 2. Xem Thông Tin Của Mình

- Nhấn icon **ℹ️** trên AppBar
- Sẽ hiện IP:Port của bạn (ví dụ: `192.168.1.100:9001`)
- Share thông tin này cho bạn bè

### 3. Kết Nối với Peer

**Cách 1: Auto Discovery (cùng mạng LAN)**
- Đợi vài giây
- Peers trong cùng mạng sẽ tự động xuất hiện
- Tap vào peer để chat

**Cách 2: Manual Connect**
- Nhập IP address của peer (ví dụ: `192.168.1.100`)
- Nhập Port (mặc định: `9001`)
- Nhấn **Connect**

### 4. Chat

- Gõ tin nhắn và nhấn **Send** hoặc **Enter**
- Tin nhắn được lưu tự động vào JSON file local
- Tắt app và mở lại → lịch sử vẫn còn

### 5. Xóa Lịch Sử

- Trong màn chat, nhấn icon **🗑️**
- Chọn **Delete** để xóa lịch sử với peer đó

---

## 🧪 Test P2P Chat

### Test trên 2 thiết bị thật (khuyến nghị)

1. **Thiết bị A**: Chạy app, xem IP:Port
2. **Thiết bị B**: Chạy app, manual connect đến A
3. Chat qua lại
4. Tắt app, mở lại → check lịch sử

### Test trên emulator + thiết bị thật

1. **Emulator** (Android): 
   - Emulator thường dùng IP `10.0.2.15` (internal)
   - Cần port forwarding: `adb forward tcp:9001 tcp:9001`
   
2. **Thiết bị thật**: Connect đến `<IP_máy_tính>:9001`

### Test khi TẮT server Java

```powershell
# TẮT server Java (Ctrl+C hoặc stop process)
# App Flutter vẫn chat P2P được vì không dùng server!
```

---

## 📂 Cấu Trúc Code

```
lib/
├── services/
│   ├── p2p_chat_service.dart         # TCP socket P2P
│   ├── peer_discovery_service.dart   # UDP broadcast discovery
│   └── chat_storage_service.dart     # JSON local storage
│
└── screens/
    └── p2p_chat/
        ├── p2p_peers_list.dart       # Danh sách peers
        └── p2p_chat_screen.dart      # Màn hình chat
```

---

## 🔧 Cấu Hình

### Ports

- **TCP Chat**: `9001` (có thể đổi trong `P2PChatService.DEFAULT_PORT`)
- **UDP Discovery**: `9002` (có thể đổi trong `PeerDiscoveryService.DISCOVERY_PORT`)

### File JSON

- **Vị trí**: `<AppDocuments>/p2p_chat_history.json`
- **Format**:
```json
{
  "192.168.1.100:9001": [
    {
      "sender": "me",
      "content": "Hello!",
      "timestamp": "2025-11-26T10:30:00.000Z"
    },
    {
      "sender": "peer",
      "content": "Hi there!",
      "timestamp": "2025-11-26T10:30:05.000Z"
    }
  ]
}
```

---

## 🚨 Lưu Ý

### Firewall

- Đảm bảo port `9001` và `9002` không bị block
- Android: Cần permission `INTERNET`
- Windows: Có thể cần allow app qua Firewall

### Network

- **LAN/WiFi**: Auto discovery hoạt động tốt
- **Internet**: Cần biết IP public + port forwarding
- **Cellular**: Thường không kết nối trực tiếp được (cần STUN/TURN)

### Platform Support

- ✅ Android
- ✅ iOS (cần test permission)
- ✅ Windows
- ✅ macOS
- ✅ Linux
- ❌ Web (dart:io không support web)

---

## 🎓 Giải Thích cho Thầy

### Đáp ứng yêu cầu:

1. ✅ **Mô hình P2P**: Kết nối TCP trực tiếp, không qua server
2. ✅ **Lưu local JSON**: Mỗi máy lưu file riêng
3. ✅ **Độc lập server**: Tắt Java server vẫn chat được
4. ✅ **Không xung đột**: Hoàn toàn tách biệt với WebSocket (port 8081) của room

### So sánh với Room (của bạn bạn):

| Tính năng | P2P Chat (của bạn) | Room (của bạn bạn) |
|-----------|-------------------|-------------------|
| Kiến trúc | P2P (2 peers trực tiếp) | Client-Server (qua WebSocket) |
| Server | Không cần | Cần Java server (port 8081) |
| Port | 9001, 9002 | 8081 |
| Lưu trữ | JSON local | Database (MySQL) |
| Mạng | TCP socket | WebSocket |
| Offline | ✅ Hoạt động | ❌ Cần server |

---

## 📝 TODO (Nâng cao - optional)

- [ ] NAT traversal (STUN/TURN) cho Internet
- [ ] Encryption (mã hóa tin nhắn)
- [ ] File transfer (gửi file/hình)
- [ ] Group chat P2P (mesh network)
- [ ] Voice/Video P2P (WebRTC)

---

**Tác giả**: Lê Thị Hoài Thương  
**Ngày**: 26/11/2025
