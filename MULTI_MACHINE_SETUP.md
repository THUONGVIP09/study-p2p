# 🌐 Hướng Dẫn Chạy Chat Trên 2 Máy Tính Khác Nhau

## 📋 Yêu Cầu

### 1. Phần Cứng & Mạng
- ✅ **2 máy tính** trong **cùng mạng WiFi/LAN**
- ✅ Firewall **KHÔNG chặn** port Java server (8080, 8082)
- ✅ Firewall **KHÔNG chặn** port P2P Flutter (random ports)

### 2. Phần Mềm
- ✅ Java 17+ (cho server)
- ✅ Flutter 3.x (cho app)
- ✅ MySQL/PostgreSQL (cho database)

## 🔧 Cấu Hình Chi Tiết

### **Bước 1: Xác Định IP Của Máy Chạy Server**

#### Trên Windows:
```powershell
ipconfig

# Tìm dòng "IPv4 Address" trong WiFi adapter
# Ví dụ: 192.168.1.100
```

#### Trên macOS/Linux:
```bash
ifconfig
# hoặc
ip addr show

# Tìm IP của interface WiFi (wlan0, en0, etc.)
# Ví dụ: 192.168.1.100
```

**Lưu lại IP này!** Ví dụ: `192.168.1.100`

---

### **Bước 2: Cấu Hình Server Java**

Server Java **PHẢI** listen trên tất cả interfaces, không chỉ localhost!

#### Kiểm Tra File `application.properties`:
```properties
# server-java/demo/src/main/resources/application.properties

# ĐÚNG - Listen trên tất cả interfaces:
server.address=0.0.0.0
server.port=8080

# SAI - Chỉ localhost:
# server.address=127.0.0.1
```

#### Hoặc Kiểm Tra `Main.java`:
```java
// Đảm bảo WebSocket server bind 0.0.0.0, không phải 127.0.0.1
```

---

### **Bước 3: Cấu Hình Flutter App**

Mở file: `lib/config/app_config.dart`

```dart
class AppConfig {
  // ==================== THAY ĐỔI NÀY ====================
  
  /// Chọn 1 trong 2 mode:

  // MODE 1: Chạy trên CÙNG MÁY (development/testing)
  // static const String serverIp = '127.0.0.1';

  // MODE 2: Chạy trên 2 MÁY KHÁC NHAU (production)
  static const String serverIp = '192.168.1.100'; // ← Thay bằng IP từ Bước 1!

  // ======================================================
  
  static const int httpPort = 8080;
  static const int websocketPort = 8082;
  
  // ... rest of config
}
```

**QUAN TRỌNG:**
- ✅ `192.168.1.100` → Chạy trên 2 máy khác nhau
- ✅ `127.0.0.1` → Chỉ chạy trên cùng máy

---

### **Bước 4: Cấu Hình Firewall**

#### Trên Máy Chạy Server (Windows):

1. **Mở Windows Defender Firewall**
2. **Advanced Settings** → **Inbound Rules** → **New Rule**
3. **Port** → Next
4. **TCP** → Specific ports: `8080, 8082` → Next
5. **Allow the connection** → Next
6. **Domain, Private, Public** (check all) → Next
7. Name: `Java Chat Server` → Finish

#### Trên Máy Chạy Flutter App:

1. **Mở Windows Defender Firewall**
2. **Advanced Settings** → **Inbound Rules** → **New Rule**
3. **Program** → Browse → Chọn `flutter_application_1.exe`
4. **Allow the connection** → Finish

Hoặc đơn giản hơn:
```powershell
# Chạy PowerShell as Administrator
New-NetFirewallRule -DisplayName "Flutter P2P Chat" -Direction Inbound -Action Allow -Protocol TCP
```

---

## 🚀 Chạy Ứng Dụng

### **Setup Ban Đầu**

#### Máy A (Chạy Server + App):
```bash
# 1. Start database
# MySQL/PostgreSQL phải running

# 2. Start Java server
cd server-java/demo
mvn spring-boot:run
# Hoặc: java -jar target/demo.jar

# Server sẽ in ra:
# Server listening on 0.0.0.0:8080
# WebSocket listening on 0.0.0.0:8082

# 3. Start Flutter app
cd flutter-app/flutter_application_1
flutter run
```

#### Máy B (Chỉ chạy App):
```bash
# 1. ĐẢM BẢO đã đổi serverIp trong app_config.dart!

# 2. Start Flutter app
cd flutter-app/flutter_application_1
flutter run
```

---

## ✅ Kiểm Tra Kết Nối

### Logs Khi Mọi Thứ Hoạt Động Đúng:

#### App trên Máy A (User 15):
```
📡 ========== APP CONFIGURATION ==========
   Server IP: 192.168.1.100
   HTTP URL:  http://192.168.1.100:8080
   WS URL:    ws://192.168.1.100:8082
   Mode:      LAN (multi-machine)
==========================================

🔍 Available network interfaces:
   Wi-Fi: 192.168.1.101
✅ Using WiFi IP: 192.168.1.101

🔌 [UI] Starting hybrid service...
✅ P2P Chat listening on 192.168.1.101:63096
🟢 Hybrid Chat started on port 63096 for userId 15

🔌 [HYBRID] Opening relay connection as backup...
   URL: ws://192.168.1.100:8082/chat-relay/15
✅ [HYBRID] Relay connection opened successfully

📡 [HYBRID] Subscribing to online list: ws://192.168.1.100:8082/chat-online-list
📡 Received online list: 2 peers
```

#### App trên Máy B (User 16):
```
📡 ========== APP CONFIGURATION ==========
   Server IP: 192.168.1.100
   HTTP URL:  http://192.168.1.100:8080
   WS URL:    ws://192.168.1.100:8082
   Mode:      LAN (multi-machine)
==========================================

🔍 Available network interfaces:
   Wi-Fi: 192.168.1.102
✅ Using WiFi IP: 192.168.1.102

🔌 [UI] Starting hybrid service...
✅ P2P Chat listening on 192.168.1.102:65089
🟢 Hybrid Chat started on port 65089 for userId 16

🔌 [HYBRID] Opening relay connection as backup...
   URL: ws://192.168.1.100:8082/chat-relay/16
✅ [HYBRID] Relay connection opened successfully

🔵 [HYBRID] Got friend 15 info from API: 192.168.1.101:63096
✅ [UI] Connection mode: P2P Direct
```

**Dấu hiệu thành công:**
- ✅ IP addresses KHÁC NHAU: `192.168.1.101` vs `192.168.1.102`
- ✅ Mode: `LAN (multi-machine)`
- ✅ P2P connection tới IP thật: `192.168.1.101:63096`

---

## ❌ Troubleshooting

### **Lỗi 1: Connection Refused**
```
❌ Failed to connect to server: Connection refused
```

**Nguyên nhân:**
- Server chưa chạy
- Firewall chặn port
- IP sai

**Giải pháp:**
1. Kiểm tra server đang chạy: `netstat -an | findstr "8080"`
2. Ping server: `ping 192.168.1.100`
3. Tắt tạm thời firewall để test
4. Kiểm tra IP trong `app_config.dart`

---

### **Lỗi 2: WebSocket Connection Failed**
```
❌ [HYBRID] Relay WebSocket closed
```

**Nguyên nhân:**
- WebSocket server chưa chạy
- Port 8082 bị chặn

**Giải pháp:**
1. Kiểm tra WebSocket: `netstat -an | findstr "8082"`
2. Test WebSocket trong browser: `ws://192.168.1.100:8082/chat-online-list`

---

### **Lỗi 3: P2P Connection Refused**
```
❌ [HYBRID] P2P send failed: Connection refused
```

**Nguyên nhân:**
- Firewall chặn P2P port
- NAT không cho phép inbound connection

**Giải pháp:**
1. Cho phép Flutter app trong firewall (cả 2 máy)
2. Nếu vẫn lỗi → Relay sẽ tự động fallback

---

### **Lỗi 4: Vẫn Dùng Localhost**
```
📡 Server IP: 127.0.0.1
   Mode: LOCALHOST (same machine)
```

**Giải pháp:**
1. Mở `lib/config/app_config.dart`
2. Đổi `serverIp = '127.0.0.1'` → `serverIp = '192.168.1.100'`
3. Hot restart app (R)

---

## 🧪 Test Case

### Scenario: 2 Máy Chat Với Nhau

```
┌─────────────────────────────────────────────────────┐
│ Máy A (192.168.1.101)      Máy B (192.168.1.102)   │
├─────────────────────────────────────────────────────┤
│ 1. Login User 15           Login User 16            │
│ 2. Friends tab → User 16   Friends tab → User 15    │
│ 3. Click "Messages"        Click "Messages"         │
│ 4. Gửi: "Hello from A" ──────────────────────────>  │
│ 5.                         Nhận: "Hello from A"     │
│ 6.                    <────────────────────────────  │
│ 7. Nhận: "Hi from B"       Gửi: "Hi from B"         │
│ 8. ✅ P2P hoặc Relay       ✅ Messages persist      │
└─────────────────────────────────────────────────────┘
```

### Expected Logs:

**Máy A gửi tin:**
```
📨 [HYBRID] SEND to friend 16: Hello from A
   Attempting P2P to 192.168.1.102:65089...
✅ [HYBRID] Sent via P2P to 192.168.1.102:65089
```

**Máy B nhận tin:**
```
📥 Peer connected: 192.168.1.101:63096
📨 Received from 192.168.1.101:63096: Hello from A
🔵 [HYBRID] Received P2P from friend 15
   Content: Hello from A
```

---

## 📊 Architecture Overview

```
┌──────────────┐                  ┌──────────────┐
│   Máy A      │                  │   Máy B      │
│ 192.168.1.101│                  │ 192.168.1.102│
│              │                  │              │
│ Flutter App  │                  │ Flutter App  │
│ (User 15)    │                  │ (User 16)    │
│              │                  │              │
│ P2P:   63096 │◄────────────────►│ P2P:   65089 │
│              │   Direct P2P     │              │
└──────┬───────┘   Connection     └──────┬───────┘
       │                                  │
       │         ┌──────────────┐        │
       └────────►│ Server Máy A │◄───────┘
                 │192.168.1.100 │
                 │              │
                 │ HTTP:   8080 │
                 │ WS:     8082 │
                 │              │
                 │ - REST API   │
                 │ - WebSocket  │
                 │ - Relay      │
                 └──────────────┘
```

**Luồng hoạt động:**
1. **HTTP API**: Register, heartbeat, friend list
2. **WebSocket**: Online list broadcast, relay messages
3. **P2P Direct**: Point-to-point messaging (fastest)
4. **Relay Fallback**: Qua server khi P2P fail

---

## 🎯 Tóm Tắt

### ✅ Để Chạy Trên 2 Máy:

1. **Server Java:**
   - Bind `0.0.0.0` (không phải `127.0.0.1`)
   - Mở port 8080, 8082 trong firewall

2. **Flutter App:**
   - Đổi `serverIp` trong `app_config.dart`
   - Cho phép app qua firewall

3. **Network:**
   - Cùng WiFi/LAN
   - Ping được IP của nhau

### ✅ Để Chạy Trên Cùng Máy (Development):

1. **Giữ nguyên:**
   ```dart
   static const String serverIp = '127.0.0.1';
   ```

2. **Không cần config firewall**

3. **Chạy nhiều instance Flutter:**
   ```bash
   flutter run -d windows
   flutter run -d chrome
   ```

---

**🎉 Chúc bạn thành công!**

Nếu có lỗi, hãy gửi logs để tôi debug nhé!
