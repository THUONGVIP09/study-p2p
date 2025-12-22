# Trình bày về chức năng Room trong dự án

## 1. Công nghệ sử dụng
- **Flutter**: Xây dựng giao diện người dùng, quản lý trạng thái, điều phối logic.
- **WebRTC**: Kết nối P2P video/audio, chia sẻ màn hình, truyền dữ liệu trực tiếp giữa các peer.
- **DataChannel (WebRTC)**: Gửi tin nhắn chat, trạng thái chia sẻ màn hình, đồng bộ UI giữa các peer.
- **WebSocket (Signaling)**: Thiết lập kết nối, trao đổi thông tin ban đầu để các peer tìm thấy nhau.
- **Local Storage**: Lưu trữ tin nhắn chat, trạng thái tạm thời trên thiết bị.

## 2. Luồng hoạt động tổng thể
- Người dùng chọn/join phòng → signaling WebSocket kết nối tới server (hoặc peer host)
- Khi vào phòng, chuyển sang màn hình call (`call_page.dart`)
- Khởi tạo kết nối P2P WebRTC với các peer khác
- Giao diện call hiển thị video, chat, nút chia sẻ màn hình, quản lý peer
- Các peer trao đổi dữ liệu (chat, trạng thái chia sẻ màn hình) qua DataChannel
- Khi có peer mới join/leave, signaling cập nhật danh sách peer

## 3. Đường đi code và vai trò các file
- **UI & State:**
  - `call_page.dart`: Giao diện chính, quản lý trạng thái phòng, video, chat, chia sẻ màn hình, điều phối các service.
  - `screens/rooms/RoomsPage`: Giao diện chọn/join phòng.
- **Model dữ liệu:**
  - `models/room.dart`: Thông tin phòng.
  - `models/call_session.dart`: Thông tin phiên gọi.
  - `models/chat_message.dart`: Kiểu dữ liệu tin nhắn chat.
- **Service logic:**
  - `services/webrtc_p2p_chat.dart`: Quản lý kết nối WebRTC, DataChannel, gửi/nhận dữ liệu P2P.
  - `services/signaling_service.dart`: Quản lý signaling WebSocket, trao đổi thông tin peer.
  - `services/room_service.dart`: Quản lý phòng, join/leave, lấy danh sách peer.
  - `services/local_message_storage.dart`: Lưu trữ tin nhắn chat local.

## 4. Trình bày từng chức năng với thầy
- **Tham gia phòng:**
  - UI chọn phòng (`RoomsPage`), gọi hàm join room (`room_service.dart`), kết nối signaling, chuyển sang `call_page.dart`.
- **Kết nối P2P:**
  - Từ signaling, các peer khởi tạo WebRTC, tạo DataChannel, truyền video/audio trực tiếp.
- **Chat trong phòng:**
  - Nhập chat ở UI, gửi qua DataChannel (`webrtc_p2p_chat.dart`), nhận và hiển thị, lưu local.
- **Chia sẻ màn hình:**
  - Bấm nút chia sẻ ở UI, lấy stream màn hình, gửi trạng thái qua DataChannel, peer nhận được sẽ phóng to video chia sẻ.
- **Quản lý peer:**
  - Khi có peer mới join/leave, signaling cập nhật danh sách, UI cập nhật video.
- **Bật/tắt camera, micro:**
  - Bấm nút ở UI, cập nhật trạng thái track local, gửi track mới cho các peer.

## 5. Cách giải thích cho thầy
- Mỗi chức năng đều có luồng code rõ ràng, bắt đầu từ UI (`call_page.dart`), gọi sang các service xử lý logic mạng, signaling, P2P.
- Các service chia nhỏ theo nhiệm vụ: signaling, P2P, lưu trữ, quản lý phòng.
- Dữ liệu truyền giữa các peer qua DataChannel, signaling chỉ dùng để thiết lập kết nối ban đầu.
- Tất cả logic chính đều tập trung ở `call_page.dart`, các service hỗ trợ phía sau.

---

# Tổng kết
- Trình bày rõ ràng từng chức năng, đường đi code, vai trò file, công nghệ sử dụng.
- Giúp thầy hiểu tổng thể kiến trúc, cách hoạt động, và dễ kiểm tra/sửa code.

Bạn có thể dùng file này để trình bày hoặc lưu lại làm tài liệu nội bộ.