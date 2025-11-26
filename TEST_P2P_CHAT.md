# 🧪 Hướng Dẫn Test P2P Chat Nhanh

## Chuẩn Bị

### Dependencies đã cài
```bash
cd flutter-app/flutter_application_1
flutter pub get
```

### Build & Run
```bash
flutter run
# Hoặc chạy trên 2 thiết bị/emulator khác nhau
```

---

## 🎯 Test Scenarios

### Scenario 1: Test trên 1 máy (localhost)

1. **Mở App 1** (emulator hoặc device)
   - Login
   - Nhấn tab "Chat" (icon 💬)
   - Xem IP:Port của mình (nhấn ℹ️) → Ví dụ: `127.0.0.1:9001`

2. **Mở App 2** (emulator khác hoặc browser)
   - Login
   - Tab "Chat"
   - Manual Connect: IP = `127.0.0.1`, Port = `9001`
   - Nhấn **Connect**

3. **Chat**
   - Gõ tin và send
   - App 1 sẽ nhận được realtime

4. **Kiểm tra lưu local**
   - Tắt cả 2 app
   - Mở lại → lịch sử vẫn còn

---

### Scenario 2: Test trên 2 thiết bị thật (cùng WiFi)

1. **Device A**
   - Kết nối WiFi
   - Chạy app, vào tab Chat
   - Xem IP (nhấn ℹ️) → Ví dụ: `192.168.1.100:9001`
   - Share IP này cho Device B

2. **Device B**
   - Cùng WiFi với A
   - Chạy app, vào tab Chat
   - Manual Connect: IP = `192.168.1.100`, Port = `9001`
   - Chat

3. **Auto Discovery (nếu cùng subnet)**
   - Đợi 3-5 giây
   - Device B sẽ tự động thấy Device A trong danh sách
   - Tap để chat

---

### Scenario 3: Test khi TẮT Server Java ✅

1. **Đang chat P2P giữa 2 device**

2. **TẮT server Java**
   ```bash
   # Tắt terminal chạy java -jar ...
   # Hoặc Ctrl+C
   ```

3. **Tiếp tục chat**
   - Vẫn gửi/nhận được message!
   - Vì P2P không cần server

4. **So sánh**
   - Thử mở tab "Call" hoặc "Rooms" → Sẽ lỗi vì cần WebSocket server
   - Nhưng tab "Chat" (P2P) vẫn hoạt động bình thường

---

## 🐛 Troubleshooting

### Không kết nối được

**Check 1: Cùng mạng?**
```bash
# Android/Windows: ipconfig / ifconfig
# iOS: Settings → WiFi → IP
```

**Check 2: Firewall?**
- Windows: Allow port 9001, 9002
- Android: Không cần (app tự request permission)

**Check 3: Port đã được dùng?**
```bash
# Windows
netstat -ano | findstr :9001

# Linux/Mac
lsof -i :9001
```

### Auto Discovery không hoạt động

- Cùng subnet? (192.168.1.x vs 192.168.2.x → khác subnet)
- Router có block UDP broadcast?
- Thử Manual Connect trước

### Lịch sử không lưu

- Check permission storage (Android 13+)
- Check logs: `flutter logs` để xem lỗi

---

## 📊 Demo cho Thầy

### Bước 1: Chuẩn bị
- 2 điện thoại Android (hoặc 1 phone + 1 emulator)
- Cùng WiFi

### Bước 2: Show P2P
1. Mở app trên cả 2 device
2. Vào tab Chat
3. Manual connect device A → device B
4. Chat qua lại
5. **Tắt server Java** (quan trọng!)
6. Tiếp tục chat → vẫn hoạt động
7. Tắt app, mở lại → lịch sử còn

### Bước 3: Show Local Storage
- Vào `Android/data/com.example.flutter_application_1/files/`
- Mở file `p2p_chat_history.json`
- Show JSON content

### Bước 4: So sánh với Room
- Tab "Rooms" (của bạn bạn) → cần server → tắt server sẽ lỗi
- Tab "Chat" (của bạn) → P2P → tắt server vẫn chạy

---

## ✅ Checklist Demo

- [ ] Show IP:Port của mỗi device
- [ ] Kết nối thành công (manual hoặc auto)
- [ ] Gửi/nhận message realtime
- [ ] Tắt server Java → chat vẫn hoạt động
- [ ] Tắt app → mở lại → lịch sử còn
- [ ] Show file JSON local
- [ ] Giải thích kiến trúc P2P vs Client-Server

---

## 📸 Screenshots cho Báo Cáo

1. Danh sách peers (với IP:Port)
2. Màn hình chat (bubble messages)
3. File JSON local (Notepad/VS Code)
4. Terminal shows "Server stopped" nhưng chat vẫn chạy
5. Diagram kiến trúc P2P

---

**Good luck! 🚀**
