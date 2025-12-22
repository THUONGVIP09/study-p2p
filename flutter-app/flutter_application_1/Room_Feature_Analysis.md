# Phân tích chức năng Room (P2P Video Call)

## 1. Tham gia phòng (Join Room)
- **Luồng code:**
  - `screens/rooms/` (UI chọn/join room)
  - `call_page.dart` (màn hình call chính)
  - `services/room_service.dart` (quản lý phòng)
  - `services/signaling_service.dart` (signaling WebSocket)
  - `services/webrtc_p2p_chat.dart` (WebRTC P2P)
- **Các bước:**
  1. Người dùng chọn/join room ở UI (`screens/rooms/RoomsPage`)
  2. Gọi hàm join room (`room_service.dart`), gửi request lên server (nếu có)
  3. Tạo/kết nối signaling WebSocket (`signaling_service.dart`)
  4. Khi vào phòng, chuyển sang `call_page.dart` để hiển thị giao diện call
  5. Khởi tạo kết nối P2P WebRTC với các peer khác (`webrtc_p2p_chat.dart`)

## 2. Chat trong phòng
- **Luồng code:**
  - `call_page.dart` (UI chat panel)
  - `models/chat_message.dart` (kiểu dữ liệu chat)
  - `services/webrtc_p2p_chat.dart` (gửi/nhận chat qua DataChannel)
  - `services/local_message_storage.dart` (lưu chat local)
- **Các bước:**
  1. Người dùng nhập chat ở panel chat (`call_page.dart`)
  2. Gửi message qua DataChannel tới các peer (`webrtc_p2p_chat.dart`)
  3. Nhận message, hiển thị lên UI và lưu vào local (`local_message_storage.dart`)

## 3. Chia sẻ màn hình
- **Luồng code:**
  - `call_page.dart` (nút chia sẻ, UI phóng to)
  - `services/webrtc_p2p_chat.dart` (gửi trạng thái qua DataChannel)
- **Các bước:**
  1. Người dùng bấm nút chia sẻ màn hình (`call_page.dart`)
  2. Lấy stream màn hình, thay thế video local gửi đi
  3. Gửi message `{type: 'screen_share', uid, active}` qua DataChannel tới các peer (`webrtc_p2p_chat.dart`)
  4. Peer nhận được message sẽ cập nhật UI phóng to video của peer chia sẻ

## 4. Quản lý peer (thêm/xóa peer, rời phòng)
- **Luồng code:**
  - `call_page.dart` (quản lý danh sách peer)
  - `services/webrtc_p2p_chat.dart` (kết nối/disconnect peer)
  - `services/signaling_service.dart` (thông báo peer join/leave)
- **Các bước:**
  1. Khi có peer mới join, signaling gửi thông báo, thêm peer vào danh sách (`call_page.dart`)
  2. Khi peer rời phòng, signaling gửi thông báo, xóa peer khỏi danh sách
  3. Đóng kết nối WebRTC với peer đó (`webrtc_p2p_chat.dart`)

## 5. Bật/tắt camera, micro
- **Luồng code:**
  - `call_page.dart` (nút UI, xử lý bật/tắt)
- **Các bước:**
  1. Người dùng bấm nút bật/tắt camera/mic
  2. Cập nhật trạng thái track local, gửi track mới cho các peer

---

# Ghi chú
- File trung tâm điều phối logic là `call_page.dart` (UI, state, điều phối các service)
- Các service trong `lib/services/` xử lý logic mạng, signaling, P2P, lưu trữ, v.v.
- Model dữ liệu nằm ở `lib/models/`
- UI phòng, chat, chia sẻ màn hình đều bắt đầu từ `call_page.dart`

Bạn có thể tra cứu chi tiết code theo đường đi trên để trình bày với thầy hoặc sửa đổi.