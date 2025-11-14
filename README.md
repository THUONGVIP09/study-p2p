# AI Learning Group Platform (study-p2p)

> **Website học nhóm trực tuyến + AI tóm tắt chat**  

## Thành viên
- **Lê Thị Hoài Thương** – 23IT.B218 – 23SE5  
- **Lê Nguyễn Quang Minh** – 23IT.B131 – 23SE4  

## Mô tả
- Tạo/tham gia phòng học ảo  
- Video call P2P (WebRTC)  
- Chat nhóm real-time  
- **AI tóm tắt chat tự động** (Python local)  
-** Module AI (Hoài Thương) 

## Tech Stack
| Layer | Công nghệ |
|------|----------|
| Frontend | Flutter (Web/Mobile) |
| Backend | **Java Maven + Tyrus WebSocket** |
| Database | MySQL |
| AI | Python (BART-pho) |
| Real-time | WebRTC + Tyrus |
| Deploy | Railway + Firebase |



🧩 1️⃣ Chuẩn bị môi trường

Đảm bảo đã cài:

✅ JDK 17+

✅ Maven (mvn -v để kiểm tra)

✅ MySQL (và database study_p2p đã sẵn sàng)

✅ Flutter SDK

⚙️ 2️⃣ Chạy backend Java

📍 Mở terminal và làm đúng thứ tự sau:

cd D:\D_A_T_A\Du_an\DACS4\study-p2p\server-java\demo


Rồi build lại toàn bộ project:

mvn clean package


✅ Khi thấy dòng BUILD SUCCESS, tiếp tục chạy server:

java -jar target/demo-1.0-SNAPSHOT.jar


🟢 Nếu thấy dòng:

Server chạy tại: http://0.0.0.0:8080/


→ Nghĩa là backend đã khởi động thành công.

Đừng đóng terminal này! Giữ nó mở, vì server đang chạy.

💻 3️⃣ Chạy frontend Flutter

📍 Mở một terminal mới, sau đó:

cd D:\D_A_T_A\Du_an\DACS4\study-p2p\flutter-app


Chạy ứng dụng Flutter Web:

flutter run -d chrome


🟢 Khi chạy xong, nó sẽ mở trình duyệt với đường dẫn kiểu:
http://localhost:xxxxx/

🔗 4️⃣ Kiểm tra kết nối

Trong file Flutter, đảm bảo API URL trỏ đúng backend:

const String apiUrl = "http://localhost:8080/api/auth";


Sau đó test các chức năng: Đăng ký / Đăng nhập

Nếu đăng ký thành công → server log hiển thị email bạn nhập.

Nếu sai email hoặc trùng → server trả lỗi JSON tương ứng.

🧠 Tóm tắt logic chạy:
1️⃣ Backend (Java) bật trước  → mở cổng 8080
2️⃣ Flutter (Frontend) bật sau → gửi request đến port 8080
3️⃣ Hai bên giao tiếp qua JSON


