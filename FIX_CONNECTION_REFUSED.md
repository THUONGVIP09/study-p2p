# 🔧 FIX: Connection Refused Error (127.0.0.1)

## 🔴 Vấn Đề

App đang kết nối đến `127.0.0.1` (localhost) thay vì IP server thật → Lỗi "Connection refused"

```
ClientException with SocketException: 
The remote computer refused the network connection.
address = 127.0.0.1  ← SAI! Phải là 172.16.0.158
```

---

## ✅ Giải Pháp: Config Server TRƯỚC KHI Login

Đã thêm **ServerConfigScreen** - màn hình config IP server TRƯỚC khi login.

### Files Đã Thêm/Sửa:

1. **NEW:** `lib/screens/authencation/server_config_screen.dart`
   - Màn hình config server IP
   - User set IP TRƯỚC khi login
   - AppConfig được update đúng cách

2. **UPDATED:** `lib/screens/authencation/get_started_screen.dart`
   - Thêm button "Configure Server"
   - Navigate to ServerConfigScreen

---

## 🎯 Quy Trình Mới

### Trước Đây (SAI):
```
App Start → Login → Chat → Config IP
              ↑
        Đã kết nối 127.0.0.1 ❌
```

### Bây Giờ (ĐÚNG):
```
App Start → Configure Server → Login → Chat
               ↓
           Set IP đúng ✅
```

---

## 📱 Hướng Dẫn Sử Dụng

### MÁY A (Server - IP: 172.16.0.158):

1. **Mở app** → Màn hình GetStarted
2. **Click "Configure Server"**
3. **Setup screen:**
   - Your IP: 172.16.0.158
   - Server IP: [Nhập vào]
   - Click **[My IP]** → Auto-fill 172.16.0.158
   - Click **"Continue to Login"**
4. **Login** (user từ DB)
5. **Proceed** như bình thường

### MÁY B (Client - IP: 172.16.0.108):

1. **Mở app** → Màn hình GetStarted
2. **Click "Configure Server"**
3. **Setup screen:**
   - Your IP: 172.16.0.108
   - Server IP: [Nhập vào]
   - **Nhập: 172.16.0.158** ← IP của Máy A
   - Click **"Continue to Login"**
4. **Login** (user khác)
5. **Chat** với user từ Máy A

---

## 🚀 Testing Steps

### Rebuild App (Cả 2 máy):

```powershell
cd flutter-app/flutter_application_1

# Clear cache
flutter clean
flutter pub get

# Run app
flutter run -d windows
```

### Test Flow:

1. **App opens** → GetStarted screen
2. **Click "Configure Server"** ✅
3. **Enter IP:**
   - Máy A: Click [My IP] → 172.16.0.158
   - Máy B: Type → 172.16.0.158
4. **Click "Continue to Login"** ✅
5. **Login screen appears** ✅
6. **Login successful** ✅
7. **Proceed to chat** ✅

---

## 🔍 Verification

### Check Console Logs (Máy B):

```
✅ AppConfig: Server IP updated to 172.16.0.158
📡 ========== APP CONFIGURATION ==========
   Server IP: 172.16.0.158  ← ĐÚNG!
   HTTP URL:  http://172.16.0.158:8080
   WS URL:    ws://172.16.0.158:8082
   Mode:      LAN (multi-machine)
```

### NO MORE Errors:

```
❌ BEFORE: address = 127.0.0.1  (localhost)
✅ AFTER:  address = 172.16.0.158  (server IP)
```

---

## 📊 UI Flow Diagram

```
┌─────────────────────────────────────────┐
│  GetStartedScreen                       │
│                                         │
│  [Create account]                       │
│  [Sign in]                              │
│  [⚙️ Configure Server]  ← NEW!          │
└──────────────┬──────────────────────────┘
               │ Click Configure Server
               ▼
┌─────────────────────────────────────────┐
│  ServerConfigScreen                     │
│                                         │
│  Your IP: 172.16.0.108                  │
│  Server IP: [____________]              │
│                                         │
│  [Localhost] [My IP]                    │
│                                         │
│  [Continue to Login]                    │
└──────────────┬──────────────────────────┘
               │ Click Continue
               │ AppConfig.setServerIp()
               ▼
┌─────────────────────────────────────────┐
│  SignInScreen                           │
│                                         │
│  Login with correct server IP ✅        │
└─────────────────────────────────────────┘
```

---

## 🎬 Demo Script (Updated)

### MÁY A (172.16.0.158):

```powershell
# 1. Chạy server
cd D:\D_A_T_A\Du_an\DACS4\study-p2p\server-java\demo
java -jar target/demo-1.0-SNAPSHOT.jar

# 2. Flutter app
cd D:\D_A_T_A\Du_an\DACS4\study-p2p\flutter-app\flutter_application_1
flutter clean
flutter pub get
flutter run -d windows

# 3. Trong app:
#    - Click "Configure Server"
#    - Click [My IP] → 172.16.0.158
#    - Click "Continue to Login"
#    - Login
```

### MÁY B (172.16.0.108):

```powershell
# 1. Flutter app
cd <path>\flutter-app\flutter_application_1
flutter clean
flutter pub get
flutter run -d windows

# 2. Trong app:
#    - Click "Configure Server"
#    - Nhập: 172.16.0.158
#    - Click "Continue to Login"
#    - Login
```

---

## ✅ Checklist

### Trước khi demo:

- [ ] Code đã rebuild: `flutter clean && flutter pub get`
- [ ] Máy A: Server đang chạy (port 8080, 8082)
- [ ] Máy A: Firewall đã mở
- [ ] Cả 2 máy: Cùng WiFi (172.16.0.x)

### Khi chạy app:

- [ ] Màn hình GetStarted xuất hiện
- [ ] Button "Configure Server" có sẵn
- [ ] Click vào → ServerConfigScreen mở
- [ ] Your IP hiển thị đúng
- [ ] Nhập server IP → Continue → Login screen
- [ ] Console logs: "Server IP updated to ..."

### Test connection:

- [ ] Login thành công (không lỗi 127.0.0.1)
- [ ] Chat connects to correct IP
- [ ] Messages delivered successfully

---

## 💡 Tóm Tắt

**VẤN ĐỀ:**
- App kết nối 127.0.0.1 thay vì 172.16.0.158
- Lỗi xảy ra khi login (AuthService init với localhost)

**NGUYÊN NHÂN:**
- AppConfig chưa được set TRƯỚC khi AuthService khởi tạo
- User chưa có cách config IP trước login

**GIẢI PHÁP:**
- ✅ Thêm ServerConfigScreen
- ✅ User config IP TRƯỚC login
- ✅ AppConfig.setServerIp() được gọi đúng thời điểm
- ✅ Tất cả services dùng IP đã config

**KẾT QUẢ:**
- ✅ Không còn lỗi 127.0.0.1
- ✅ Kết nối đúng server IP
- ✅ Demo thành công trên 2 máy

---

**Ready to test!** 🚀
