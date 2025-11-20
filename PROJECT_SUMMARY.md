# 📚 Study P2P - Project Summary

## 🎯 Mô tả Dự Án
**Study P2P** là một nền tảng học nhóm trực tuyến với tích hợp AI tóm tắt tự động.

**Thành viên:**
- Lê Thị Hoài Thương (23IT.B218 – 23SE5)
- Lê Nguyễn Quang Minh (23IT.B131 – 23SE4)

**Tính năng chính:**
- ✅ Tạo/tham gia phòng học ảo
- ✅ Video call P2P (WebRTC)
- ✅ Chat nhóm real-time
- ✅ **AI tóm tắt chat tự động** (Python BART-pho)
- ✅ Quản lý phòng học (public/private)
- ✅ Danh sách bạn bè
- ✅ Xác thực người dùng (register/login)

---

## 🏗️ Tech Stack

| Layer | Công Nghệ | Phiên Bản |
|-------|-----------|---------|
| **Frontend** | Flutter | 3.24.0+ |
| **Backend** | Java (Maven) | JDK 17+ |
| **REST API** | Jersey (JAX-RS) | 3.1.6 |
| **WebSocket** | Tyrus + Jakarta EE | 2.1.3 |
| **Real-time** | WebRTC | P2P Video/Audio |
| **Database** | MySQL | - |
| **AI** | Python (BART-pho) | Local |
| **Deploy** | Railway + Firebase | - |

---

## 📁 Cấu Trúc Dự Án

```
study-p2p/
├── flutter-app/                    # 📱 Frontend Flutter
│   └── flutter_application_1/
│       ├── lib/                    # Source code chính
│       │   ├── main.dart          # Entry point - khởi tạo app, routing
│       │   ├── home_shell.dart    # Shell/layout chính sau login
│       │   ├── models/             # 📊 Data models
│       │   │   └── room.dart      # Model: phòng học (id, title, code, visibility, isGroup)
│       │   ├── services/           # 🔌 API & WebSocket services
│       │   │   ├── api_service.dart       # HTTP REST API (auth, rooms, chat)
│       │   │   ├── signaling_service.dart # WebSocket signaling (WebRTC)
│       │   │   └── rtc_service.dart      # WebRTC connection handler
│       │   └── screens/            # 🎨 UI Pages
│       │       ├── authencation/   # Màn hình đăng nhập/đăng ký
│       │       │   ├── get_started_screen.dart
│       │       │   ├── Login/signin_screen.dart
│       │       │   └── Sign_up/
│       │       │       ├── signup_info_screen.dart
│       │       │       └── signup_password_screen.dart
│       │       ├── rooms/          # Màn hình phòng học
│       │       ├── chats/          # Màn hình chat
│       │       └── friends/        # Màn hình bạn bè
│       ├── assets/images/          # 🖼️ Hình ảnh tĩnh
│       ├── pubspec.yaml            # Dependencies Flutter
│       ├── android/                # 📱 Config Android
│       ├── ios/                    # 🍎 Config iOS
│       ├── web/                    # 🌐 Config Web
│       ├── linux/                  # 🐧 Config Linux
│       ├── macos/                  # 💻 Config macOS
│       ├── windows/                # 🪟 Config Windows
│       └── test/widget_test.dart   # Unit tests
│
├── server-java/                    # 🖥️ Backend Java
│   └── demo/
│       ├── src/main/java/com/study/
│       │   ├── Main.java           # Entry point - khởi động HTTP + WebSocket servers
│       │   ├── AuthController.java # REST endpoints: /api/auth (register, login)
│       │   ├── SignalingEndpoint.java # WebSocket endpoint (WebRTC signaling)
│       │   ├── CORSFilter.java     # CORS filter - cho phép cross-origin requests
│       │   ├── Db.java             # MySQL database manager
│       │   └── room/
│       │       └── RoomsController.java # REST endpoints: /api/rooms (CRUD)
│       ├── pom.xml                 # Maven dependencies
│       ├── target/                 # 📦 Build output (JAR)
│       └── dependency-reduced-pom.xml
│
├── README.md                       # Hướng dẫn chạy dự án
├── NoteDemoAuth.md                 # Ghi chú: Auth workflow
├── NoteHowJavaAPIWork.md           # Ghi chú: Java API design
└── run-minh.ps1                    # PowerShell script chạy project
```

---

## 🔌 Backend - Cấu Trúc Java

### **Main.java** (Entry Point)
- Khởi động **HTTP server** (Jersey) trên `http://0.0.0.0:8080`
- Khởi động **WebSocket server** (Tyrus) trên `ws://0.0.0.0:8081`
- Đăng ký controllers + filters: `AuthController`, `RoomsController`, `CORSFilter`, `Db`

### **AuthController.java** - Xác thực
- `POST /api/auth/register` → Đăng ký user (email, password, displayName)
- `POST /api/auth/login` → Đăng nhập, trả JWT token

### **RoomsController.java** - Quản lý phòng
- `GET /api/rooms` → Liệt kê phòng (filter, search)
- `POST /api/rooms` → Tạo phòng mới
- `GET /api/rooms/{id}` → Chi tiết phòng
- `PUT /api/rooms/{id}` → Cập nhật phòng
- `DELETE /api/rooms/{id}` → Xóa phòng

### **SignalingEndpoint.java** - WebSocket Signaling
- WebSocket endpoint cho **WebRTC P2P** 
- Xử lý `onOpen`, `onMessage`, `onClose` events
- Quản lý danh sách clients và routing messages (offer, answer, ICE candidates)

### **Db.java** - Database Manager
- Singleton quản lý MySQL connection
- Thực thi SQL queries

### **CORSFilter.java** - CORS Headers
- Cho phép cross-origin requests từ Frontend

---

## 📱 Frontend - Cấu Trúc Flutter

### **main.dart** - Entry Point
- Khởi tạo ứng dụng Material Design
- Định nghĩa routes: `/home`, `/signin`, `/signup`, `/signup/password`
- Home screen ban đầu: `GetStartedScreen` (welcome screen)

### **home_shell.dart** - Main Layout
- Layout chính sau khi login
- Navigation drawer/tabs cho các màn hình: Rooms, Chats, Friends

### **Models/room.dart**
```dart
class Room {
  int id;
  String roomCode;      // ROOM-0001
  String title;         // Tên phòng
  String description;   // Mô tả
  String visibility;    // "public" hoặc "private"
  bool isGroup;         // true = phòng nhóm, false = 1-on-1
}
```

### **Services**

#### **api_service.dart** - HTTP REST Client
```dart
// Đăng ký
ApiService.register(email, password, displayName)

// Đăng nhập
ApiService.login(email, password) → trả JWT token

// Phòng học
ApiService.getRooms()         // GET /api/rooms
ApiService.createRoom(...)    // POST /api/rooms
ApiService.updateRoom(...)    // PUT /api/rooms/{id}
ApiService.deleteRoom(...)    // DELETE /api/rooms/{id}

// Lưu token vào SharedPreferences
```

#### **signaling_service.dart** - WebSocket Signaling
```dart
// Kết nối WebSocket
SignalingService.connect(wsUrl)

// Gửi signaling messages (offer, answer, ICE candidates)
send(message)

// Listening events
onOpen, onMessage, onClose
```

#### **rtc_service.dart** - WebRTC Handler
- Tạo local MediaStream
- Tạo PeerConnection
- Xử lý remote tracks
- Gửi/nhận ICE candidates

---

## 🎨 Screens (UI Pages)

### **Authentication Screens**
- **get_started_screen.dart** → Welcome + Buttons: Sign In / Sign Up
- **signin_screen.dart** → Form: email, password → POST /api/auth/login
- **signup_info_screen.dart** → Form: email, displayName
- **signup_password_screen.dart** → Form: password → POST /api/auth/register

### **Main Screens**
- **rooms/** → Danh sách phòng, tạo phòng mới, tham gia phòng
- **chats/** → Chat nhóm, AI tóm tắt chat
- **friends/** → Danh sách bạn bè, kết bạn

---

## 🔄 API Endpoints

### **Authentication**
```
POST /api/auth/register
  Body: { email, password, displayName }
  Response: { userId, token, ... }

POST /api/auth/login
  Body: { email, password }
  Response: { userId, token, ... }
```

### **Rooms (Phòng Học)**
```
GET /api/rooms?q=search_query
  Response: [ { id, roomCode, title, description, visibility, isGroup }, ... ]

POST /api/rooms
  Body: { title, description, visibility, isGroup }
  Response: { id, roomCode, ... }

PUT /api/rooms/{id}
  Body: { title, description, visibility }
  Response: { success: true }

DELETE /api/rooms/{id}
  Response: { success: true }
```

### **WebSocket (Real-time Signaling)**
```
ws://localhost:8081/
  
Message Format:
{
  "type": "offer|answer|ice-candidate|ping|...",
  "from": "userId",
  "to": "targetUserId",
  "data": { ... }
}
```

---

## 📦 Dependencies

### **Frontend (pubspec.yaml)**
```yaml
- flutter           # UI framework
- http              # HTTP client (REST API)
- shared_preferences # Local storage (token)
- web_socket_channel # WebSocket client
- flutter_webrtc    # WebRTC P2P
- intl              # Localization
- cupertino_icons   # Icons
```

### **Backend (pom.xml)**
```xml
- Jersey 3.1.6              # JAX-RS REST framework
- Tyrus 2.1.3               # WebSocket implementation
- Jakarta EE 10.0.0         # Modern Java EE APIs
- Jackson                   # JSON parsing
- MySQL JDBC Driver         # Database connection
- Grizzly 2.x               # HTTP server
```

---

## 🚀 Hướng Dẫn Chạy

### **1. Chuẩn Bị Môi Trường**
```bash
# Kiểm tra cài đặt
java -version              # JDK 17+
mvn -v                     # Maven 3.x+
flutter --version          # Flutter 3.24.0+

# Đảm bảo MySQL đang chạy
mysql -u root -p           # Đăng nhập MySQL
CREATE DATABASE study_p2p; # Tạo DB
```

### **2. Chạy Backend Java**
```bash
cd D:\D_A_T_A\Du_an\DACS4\study-p2p\server-java\demo
mvn clean package
java -jar target/demo-1.0-SNAPSHOT.jar
# ✅ Khi thấy "Server chạy tại: http://0.0.0.0:8080/" → backend OK
```

### **3. Chạy Frontend Flutter**
```bash
cd D:\D_A_T_A\Du_an\DACS4\study-p2p\flutter-app\flutter_application_1
flutter run -d chrome
# ✅ Browser sẽ mở http://localhost:xxxxx/
```

### **4. Kiểm Tra Kết Nối**
```
API URL: http://localhost:8080/api/auth
WebSocket URL: ws://localhost:8081/

Test: Đăng ký → Backend log hiển thị email
```

---

## 📊 Database Schema (MySQL)

```sql
-- Users
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) UNIQUE,
  password VARCHAR(255),
  displayName VARCHAR(255),
  created_at TIMESTAMP
);

-- Rooms
CREATE TABLE rooms (
  id INT PRIMARY KEY AUTO_INCREMENT,
  roomCode VARCHAR(50) UNIQUE,
  title VARCHAR(255),
  description TEXT,
  visibility VARCHAR(50), -- 'public' or 'private'
  is_group BOOLEAN,
  created_by INT,
  created_at TIMESTAMP
);

-- Room Members
CREATE TABLE room_members (
  id INT PRIMARY KEY AUTO_INCREMENT,
  room_id INT,
  user_id INT,
  joined_at TIMESTAMP,
  FOREIGN KEY (room_id) REFERENCES rooms(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Chat Messages
CREATE TABLE messages (
  id INT PRIMARY KEY AUTO_INCREMENT,
  room_id INT,
  user_id INT,
  content TEXT,
  created_at TIMESTAMP,
  FOREIGN KEY (room_id) REFERENCES rooms(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

---

## 🔐 Security

- JWT Token authentication
- CORS filter cho phép safe cross-origin
- Password hashing (bcrypt recommended)
- HTTPS on production

---

## 🎯 Workflow Chính

```
1. User mở ứng dụng → GetStartedScreen
2. Chọn "Sign Up" → SignupInfoScreen → SignupPasswordScreen
3. Backend: register → lưu user vào DB → trả JWT token
4. Frontend: lưu token vào SharedPreferences
5. Auto redirect → HomeShell (list rooms)
6. Chọn phòng → join room → open WebRTC + WebSocket
7. Chat real-time → AI tóm tắt chat → display summary
```

---

## 📝 File Quan Trọng

| File | Mục Đích |
|------|---------|
| `main.dart` | Entry point, routing |
| `api_service.dart` | REST API client |
| `signaling_service.dart` | WebSocket signaling |
| `Main.java` | Backend entry point |
| `AuthController.java` | Auth endpoints |
| `RoomsController.java` | Room endpoints |
| `SignalingEndpoint.java` | WebSocket handler |
| `Db.java` | Database connection |
| `pubspec.yaml` | Flutter dependencies |
| `pom.xml` | Java dependencies |

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| Backend không khởi động | Kiểm tra JDK 17+, Maven installed, MySQL running |
| Frontend không kết nối backend | Kiểm tra API URL trong `api_service.dart`, backend port 8080 |
| WebSocket error | Kiểm tra signaling service, WebSocket port 8081 |
| Database error | Tạo database `study_p2p`, kiểm tra MySQL user/password |
| Flutter run error | `flutter clean`, `flutter pub get`, kiểm tra Chrome installed |

---

## 📚 Tài Liệu Bổ Sung

- `NoteDemoAuth.md` - Chi tiết Auth workflow
- `NoteHowJavaAPIWork.md` - Chi tiết Java API design
- `README.md` - Hướng dẫn chạy chi tiết

---

**Last Updated:** November 16, 2025
**Version:** 1.0
