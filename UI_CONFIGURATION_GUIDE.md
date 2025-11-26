# 🎯 Hướng Dẫn Sử Dụng Chat Đa Máy - UI Improvements

## ✨ Tính Năng Mới

### 1. 🖥️ **Hiển thị IP Máy Server** (Góc dưới phải)

Ứng dụng tự động hiển thị IP của máy bạn ở góc dưới màn hình chính:

```
📍 Vị trí: Góc dưới bên phải màn hình chính
🎨 Giao diện: 
   - Thu gọn: Hiển thị icon "IP" nhỏ
   - Mở rộng: Hiển thị IP đầy đủ + nút copy
```

**Cách sử dụng:**
1. Click vào icon "IP" ở góc dưới phải
2. Widget sẽ mở rộng và hiển thị IP của bạn
3. Click icon copy để copy IP vào clipboard
4. Share IP này cho người dùng khác muốn kết nối từ máy khác

**Ví dụ:**
```
Collapsed:  [📡 IP]
Expanded:   ┌─────────────────────┐
            │ 🖥️ My Server IP      │
            │ ┌─────────────────┐ │
            │ │ 192.168.1.100 📋│ │
            │ └─────────────────┘ │
            │ Tap to collapse     │
            └─────────────────────┘
```

### 2. 🔧 **Màn Hình Cấu Hình Connection** (Trước khi chat)

Khi click "Message" bạn bè, app sẽ hiển thị màn hình setup thay vì vào chat trực tiếp:

**Thông tin hiển thị:**
- ✅ Your IP Address: IP máy bạn
- ✅ Current Server IP: Server đang config
- ✅ Mode: Same Machine / Network (LAN)

**Quick Actions:**
```
🖥️ [Same Machine]  → Set IP = 127.0.0.1 (cùng máy)
📡 [This Machine]   → Set IP = Your IP (máy này là server)
```

**Input Field:**
- Nhập IP của máy chạy server
- Ví dụ: `192.168.1.100`

**Help Section:**
```
❓ Need help?
  🖥️ Same Machine (Testing)
     Use: 127.0.0.1
     Both apps running on this computer
  
  🌐 Different Machines (LAN)
     Use: Server's LAN IP (e.g., 192.168.1.100)
     Find it on the server machine's app
  
  📡 Server on This Machine
     Use: 192.168.1.100 (your IP shown above)
```

---

## 📋 Kịch Bản Sử Dụng

### Scenario 1: Test trên cùng 1 máy (như hiện tại)

```
User A (Instance 1):
1. Vào app → Thấy IP indicator ở góc: 192.168.1.100
2. Click "Message" friend → Màn hình setup xuất hiện
3. Click button [Same Machine] → IP = 127.0.0.1
4. Click "Connect & Start Chat"

User B (Instance 2 - cùng máy):
1. Làm tương tự User A
2. Set IP = 127.0.0.1
3. Kết nối thành công ✅
```

### Scenario 2: Chat giữa 2 máy khác nhau

```
SETUP:
- Máy A: 192.168.1.100 (chạy Java server)
- Máy B: 192.168.1.101 (client)
- Cùng WiFi: 192.168.1.x

🖥️ MÁY A (Server):
1. Mở app → Click IP indicator ở góc
2. Thấy IP: 192.168.1.100
3. Click copy, share cho Máy B (qua chat/email/...)
4. Đảm bảo Java server đang chạy

📱 MÁY B (Client):
1. Vào app → Click "Message" friend
2. Màn hình setup hiện lên
3. Nhập IP của Máy A: 192.168.1.100
4. Click "Connect & Start Chat"
5. Bắt đầu chat với Máy A ✅
```

### Scenario 3: Máy hiện tại vừa là server vừa là client

```
User on Machine A (192.168.1.100):
1. Check IP indicator: 192.168.1.100
2. Click [This Machine] button
3. App tự động fill: 192.168.1.100
4. Connect ✅

→ Máy khác có thể kết nối đến 192.168.1.100
```

---

## 🔄 Flow Diagram

```
┌─────────────────────────────────────────────────┐
│  Friend List Screen                             │
│  - Chọn friend                                  │
│  - Click "Message"                              │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│  🆕 Chat Connection Setup Screen                │
│                                                 │
│  📊 Network Info Card:                          │
│     Your IP: 192.168.1.100        [Copy]        │
│     Server IP: 127.0.0.1          [Copy]        │
│     Mode: Same Machine                          │
│                                                 │
│  📝 Server IP Configuration:                    │
│     ┌─────────────────────────┐                 │
│     │ 127.0.0.1              │                 │
│     └─────────────────────────┘                 │
│                                                 │
│  🚀 Quick Actions:                              │
│     [🖥️ Same Machine] [📡 This Machine]        │
│                                                 │
│  ❓ Help Section (expandable)                   │
│                                                 │
│  ┌─────────────────────────────────┐            │
│  │  Connect & Start Chat           │            │
│  └─────────────────────────────────┘            │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
         AppConfig.setServerIp(ip)
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│  Hybrid Chat Screen                             │
│  - P2P với server IP đã config                  │
│  - Relay fallback                               │
└─────────────────────────────────────────────────┘
```

---

## 💻 Technical Details

### Files Changed:

1. **`lib/config/app_config.dart`**
   - Changed from `const serverIp` to `static String _serverIp`
   - Added `setServerIp()`, `currentServerIp` getter
   - Runtime configuration support

2. **`lib/screens/chat/chat_connection_setup_screen.dart`** (NEW)
   - Full UI for server IP configuration
   - Auto-detect current network info
   - Quick action buttons
   - Help section

3. **`lib/widgets/server_ip_indicator.dart`** (NEW)
   - Floating widget at bottom-right
   - Expandable/collapsible
   - Copy to clipboard

4. **`lib/screens/friends/friends_tab.dart`**
   - Navigate to `ChatConnectionSetupScreen` instead of direct chat
   - User can configure before entering chat

5. **`lib/home_shell.dart`**
   - Added `ServerIpIndicator` widget in Stack
   - Always visible at bottom-right

### Configuration Flow:

```dart
// Default
AppConfig._serverIp = '127.0.0.1'

// User changes in UI
ChatConnectionSetupScreen → AppConfig.setServerIp('192.168.1.100')

// All services use updated IP
- chat_api_service.dart → AppConfig.httpBaseUrl
- hybrid_chat_service.dart → AppConfig.chatRelayUrl()
- Network detection → NetworkHelper.getLocalIpAddress()
```

---

## 🎨 UI Preview

### Server IP Indicator (Bottom Right)

**Collapsed State:**
```
    ┌──────┐
    │ 📡 IP│
    └──────┘
```

**Expanded State:**
```
┌───────────────────────┐
│ 🖥️ My Server IP       │
│ ┌───────────────────┐ │
│ │ 192.168.1.100  📋 │ │
│ └───────────────────┘ │
│ Tap to collapse       │
└───────────────────────┘
```

### Connection Setup Screen

```
╔═══════════════════════════════════════════════╗
║  ← Connect to John Doe                        ║
╠═══════════════════════════════════════════════╣
║                                               ║
║  ┌─────────────────────────────────────────┐  ║
║  │ ℹ️ Your Network Info                    │  ║
║  ├─────────────────────────────────────────┤  ║
║  │ Your IP Address:   192.168.1.100  [📋] │  ║
║  │ Current Server IP: 127.0.0.1       [📋] │  ║
║  │ Mode:              🖥️ Same Machine      │  ║
║  └─────────────────────────────────────────┘  ║
║                                               ║
║  Server IP Configuration                      ║
║  Enter the IP address where the chat server   ║
║  is running:                                  ║
║                                               ║
║  ┌─────────────────────────────────┐          ║
║  │ 127.0.0.1                    [✕]│          ║
║  └─────────────────────────────────┘          ║
║                                               ║
║  [🖥️ Same Machine] [📡 This Machine]        ║
║                                               ║
║  ▼ Need help?                                 ║
║                                               ║
║  ┌─────────────────────────────────────────┐  ║
║  │      Connect & Start Chat               │  ║
║  └─────────────────────────────────────────┘  ║
║                                               ║
╚═══════════════════════════════════════════════╝
```

---

## ✅ Benefits

### Before (Manual Configuration):
```
❌ User phải mở cmd → ipconfig
❌ User phải edit code app_config.dart
❌ Phải rebuild app mỗi lần đổi server
❌ Không rõ đang kết nối đến đâu
```

### After (UI Configuration):
```
✅ App tự hiển thị IP ở góc màn hình
✅ User config trong UI, không cần edit code
✅ Không cần rebuild, thay đổi runtime
✅ Rõ ràng: Thấy IP hiện tại, mode kết nối
✅ Quick actions: 1 click set localhost/LAN
✅ Help section: Hướng dẫn từng scenario
```

---

## 🚀 Quick Start Guide

### Lần đầu sử dụng:

1. **Mở app** → Thấy IP indicator ở góc dưới phải
2. **Click để xem IP** của máy bạn
3. **Vào Friends** → Click "Message" một friend
4. **Màn hình setup** xuất hiện:
   - Nếu test trên cùng máy → Click [Same Machine]
   - Nếu connect máy khác → Nhập IP của server
5. **Click Connect** → Vào chat

### Các lần sau:

- App nhớ server IP đã config
- Chỉ cần đổi nếu server thay đổi địa chỉ

---

## 🔧 Troubleshooting

### Không thấy IP indicator?

```
Check: home_shell.dart đã có ServerIpIndicator trong Stack chưa
Fix: Restart app
```

### IP hiển thị "Detecting..." mãi?

```
Check: NetworkHelper.getLocalIpAddress() có lỗi
Debug: Xem console logs
```

### Kết nối failed sau khi config IP?

```
1. Check Java server có chạy không
2. Check firewall (port 8080, 8082)
3. Check IP đã đúng chưa (ping từ cmd)
4. Xem logs trong console
```

---

## 📖 Related Documentation

- `MULTI_MACHINE_SETUP.md` - Server configuration guide
- `lib/config/app_config.dart` - Configuration class
- `lib/services/network_helper.dart` - IP detection

---

## 🎉 Summary

Với UI improvements này, người dùng:
- **Không cần mở CMD** để tìm IP
- **Không cần edit code** để đổi server
- **Thấy rõ ràng** đang kết nối đến đâu
- **Quick actions** cho các scenario phổ biến
- **Help built-in** ngay trong app

Trải nghiệm người dùng tốt hơn nhiều! 🚀
