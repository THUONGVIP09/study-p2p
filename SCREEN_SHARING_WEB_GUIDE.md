# 🌐 Hướng Dẫn Chạy Screen Sharing trên Web

## ⚠️ **VẤN ĐỀ**

Screen sharing **KHÔNG hoạt động** trên Flutter Desktop (Windows/Linux/macOS) do:
- `getDisplayMedia()` API không được hỗ trợ đầy đủ
- Không có UI picker để chọn màn hình
- Flutter Desktop sử dụng native WebRTC mà thiếu một số Web APIs

**Lỗi:** `Unable to getDisplayMedia: source not found!`

---

## ✅ **GIẢI PHÁP: CHẠY TRÊN WEB**

Screen sharing hoạt động **HOÀN HẢO** trên các trình duyệt web (Chrome, Edge, Firefox).

### **Bước 1: Chạy trên Chrome**

```bash
cd flutter-app/flutter_application_1
flutter run -d chrome
```

### **Bước 2: Hoặc chạy trên Edge**

```bash
flutter run -d edge
```

### **Bước 3: Join room và click Screen Share**

1. App sẽ mở trên browser
2. Login và join room như bình thường
3. Click button **Screen Share** (biểu tượng màn hình)
4. Browser hiện popup chọn:
   - **Entire Screen** (toàn màn hình)
   - **Window** (cửa sổ cụ thể)
   - **Chrome Tab** (tab browser)
5. Click **Share**
6. ✅ Tất cả người trong room thấy màn hình của bạn!

---

## 🧪 **TEST SCREEN SHARING TRÊN WEB**

### **Scenario 1: Test với 2 browser tabs**

**Terminal 1:**
```bash
flutter run -d chrome
```

**Terminal 2:**
```bash
# Chạy thêm 1 instance nữa (sẽ mở tab mới)
flutter run -d chrome
```

**Test:**
1. Tab 1: Login user A, tạo room
2. Tab 2: Login user B, join room
3. Tab 1: Click screen share → Chọn **Chrome Tab** → Share tab YouTube/PDF
4. ✅ Tab 2 thấy nội dung tab đang share

---

### **Scenario 2: Test với nhiều devices**

**Máy 1 (Desktop - Chrome):**
```bash
flutter run -d chrome
```

**Máy 2 (Mobile):**
```bash
flutter run -d <device-id>
```

**Test:**
1. Cả 2 join cùng room
2. Desktop click screen share → Share entire screen
3. ✅ Mobile thấy màn hình desktop

---

## 🎯 **CÁC LOẠI SCREEN SHARE**

### **1. Entire Screen (Toàn màn hình)**
- Share toàn bộ màn hình
- Người xem thấy tất cả (desktop, taskbar, notifications)
- **Use case:** Demo, presentation

### **2. Window (Cửa sổ cụ thể)**
- Share 1 ứng dụng cụ thể (VS Code, PowerPoint, Excel...)
- Chỉ cửa sổ đó được share, phần còn lại ẩn
- **Use case:** Code demo, document review

### **3. Chrome Tab**
- Share 1 tab browser (YouTube, PDF viewer, Google Docs...)
- Không lộ tab khác
- **Use case:** Video playback, online documents

---

## 🔧 **DEBUG TRÊN WEB**

### **Mở DevTools trong Chrome:**

1. App đang chạy trên Chrome
2. Press **F12** hoặc Right-click → **Inspect**
3. Tab **Console** → Xem logs:
   ```
   🖥️ Starting screen share...
   🖥️ Screen capture OK: 1 tracks
   🖥️ Replaced video track for peer=xxx
   ```

4. Tab **Network** → Filter **WS** → Xem WebSocket messages:
   - ICE candidates
   - SDP offer/answer
   - Track events

---

## 📊 **SO SÁNH DESKTOP vs WEB**

| Feature                  | Desktop (Windows) | Web (Chrome/Edge) |
|--------------------------|-------------------|-------------------|
| **Camera**               | ✅ Hoạt động       | ✅ Hoạt động       |
| **Microphone**           | ✅ Hoạt động       | ✅ Hoạt động       |
| **Screen Sharing**       | ❌ Không hỗ trợ    | ✅ Hoạt động       |
| **Screen Audio**         | ❌ Không hỗ trợ    | ✅ Hoạt động (Chrome) |
| **UI Picker**            | ❌ Không có        | ✅ Native picker   |
| **Performance**          | ⚡ Tốt hơn        | 🔥 Tốt             |

**Kết luận:** Dùng **Web** cho screen sharing, **Desktop** cho camera/mic call

---

## 🚀 **BUILD WEB VERSION**

### **Build cho production:**

```bash
cd flutter-app/flutter_application_1
flutter build web --release
```

**Output:** `build/web/`

### **Deploy lên server:**

**Option 1: Firebase Hosting**
```bash
firebase init hosting
firebase deploy
```

**Option 2: GitHub Pages**
```bash
# Copy build/web/* vào gh-pages branch
```

**Option 3: Nginx/Apache**
```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/build/web;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 💡 **TIPS & TRICKS**

### **1. Thay đổi default browser:**

```bash
# Set Edge làm default
flutter config --enable-web
export CHROME_EXECUTABLE=/path/to/msedge.exe

# Hoặc thêm vào .bashrc / .zshrc
```

### **2. Hot reload trên Web:**

Press **r** trong terminal để reload nhanh (giữ state)

### **3. Open DevTools ngay:**

```bash
flutter run -d chrome --web-browser-flag "--auto-open-devtools-for-tabs"
```

### **4. Disable CORS (nếu gặp lỗi):**

```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

⚠️ **Chỉ dùng cho development!**

---

## ❓ **FAQ**

### **Q: Tại sao Desktop không hỗ trợ screen sharing?**
A: Flutter Desktop sử dụng `libwebrtc` (C++ library) mà không có `getDisplayMedia()` API. API này chỉ có trong browser.

### **Q: Có cách nào bypass không?**
A: Có, nhưng phức tạp:
- Dùng native plugin (JNI on Windows, Objective-C on macOS)
- Capture screen bằng `screen_capturer` package
- Convert thành MediaStream
→ **Không đáng**, dùng Web đơn giản hơn nhiều

### **Q: Mobile có hỗ trợ không?**
A: 
- **iOS Safari**: ✅ Hỗ trợ (iOS 15+)
- **Android Chrome**: ❌ Không hỗ trợ (API limitation)
- **Flutter Mobile App**: ❌ Không hỗ trợ

### **Q: Làm sao test nhiều users trên 1 máy?**
A: Mở nhiều browser tabs/windows:
```bash
# Tab 1
flutter run -d chrome

# Tab 2 - Incognito (tránh conflict cookies)
chrome --incognito http://localhost:xxxx
```

---

## 🎓 **KẾT LUẬN**

✅ **Screen Sharing hoạt động hoàn hảo trên Web (Chrome/Edge)**

✅ **Đã thêm error handling thân thiện:**
- Dialog cảnh báo khi dùng Desktop
- Hướng dẫn rõ ràng cách chạy Web
- SnackBar với action "Hướng dẫn"

✅ **Code đã được fix:**
- Check `kIsWeb` trước khi getDisplayMedia
- Thông báo lỗi chi tiết
- Dialog giải thích cách sử dụng đúng

**📱 Để demo đầy đủ screen sharing:**
```bash
flutter run -d chrome
```

---

**📅 Ngày cập nhật:** 29/11/2025  
**👨‍💻 Người thực hiện:** GitHub Copilot + User  
**🎯 Mục đích:** Fix screen sharing error trên Desktop
