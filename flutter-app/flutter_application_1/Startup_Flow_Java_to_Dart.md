# Luồng khởi động từ main.java (server) đến main.dart (client Flutter)

## 1. Khởi động server Java (`main.java`)
- **File:** `server-java/demo/src/main/java/com/study/Main.java`
- **Các bước:**
  1. Chạy file `Main.java` để khởi động backend server (Spring Boot hoặc Java HTTP server).
  2. Server lắng nghe các cổng (thường là 8080 cho API, 8081 cho signaling WebSocket).
  3. Server quản lý các phòng, xác thực, signaling, lưu trữ dữ liệu nếu cần.
  4. Khi client (Flutter) kết nối, server nhận request, xác thực, trả về thông tin phòng, peer, signaling.

## 2. Khởi động client Flutter (`main.dart`)
- **File:** `flutter-app/flutter_application_1/lib/main.dart`
- **Các bước:**
  1. Chạy `main.dart` để khởi động ứng dụng Flutter (mobile/web/desktop).
  2. Hàm `main()` gọi `runApp()`, khởi tạo widget gốc, load UI.
  3. Người dùng đăng nhập/chọn phòng, giao diện điều hướng tới `RoomsPage` hoặc màn hình tương ứng.
  4. Khi join phòng, app gọi API tới server Java để lấy thông tin phòng, xác thực, lấy danh sách peer.
  5. App khởi tạo signaling WebSocket tới server (thường cổng 8081).
  6. Khi signaling thành công, app chuyển sang màn hình call (`call_page.dart`).
  7. App khởi tạo kết nối WebRTC P2P với các peer khác, truyền video/audio, chat, chia sẻ màn hình.

## 3. Tóm tắt luồng hoạt động
- **Bước 1:** Chạy `main.java` → server sẵn sàng nhận kết nối.
- **Bước 2:** Chạy `main.dart` → app Flutter khởi động, người dùng thao tác UI.
- **Bước 3:** App gọi API tới server Java để join phòng, lấy thông tin.
- **Bước 4:** App kết nối signaling WebSocket tới server để trao đổi peer info.
- **Bước 5:** App chuyển sang màn hình call, khởi tạo P2P WebRTC, bắt đầu truyền thông tin trực tiếp giữa các peer.

## 4. Vai trò từng file
- `main.java`: Điểm khởi động backend, quản lý signaling, API, phòng, xác thực.
- `main.dart`: Điểm khởi động frontend, điều hướng UI, gọi API, điều phối logic client.

---

Bạn có thể dùng file này để trình bày với thầy về toàn bộ luồng khởi động và giao tiếp giữa backend Java và frontend Flutter.