🧩 1️⃣ Chuẩn bị môi trường

Đảm bảo đã cài:

✅ JDK 25 Link tải: | https://download.oracle.com/java/25/latest/jdk-25_windows-x64_bin.exe (sha256) |

✅ Maven (mvn -v để kiểm tra)

✅ MySQL (và database study_p2p đã sẵn sàng)

✅ Flutter SDK

⚙️ 2️⃣ Chạy backend Java

📍 Mở terminal và làm đúng thứ tự sau (trong Window powerShell, CMD hoặc Terminal trong VSCode)

- cd đến thư mục của dự án

cd ....\study-p2p\server-java\demo ̣( tự sửa đường dẫn)     


- Rồi build lại toàn bộ project:
    
mvn clean package

 
✅ Khi thấy dòng BUILD SUCCESS, tiếp tục chạy server:

- java -jar target/demo-1.0-SNAPSHOT.jar


🟢 Nếu thấy dòng:

Server chạy tại: http://0.0.0.0:8080/


→ Nghĩa là backend đã khởi động thành công.

- Đừng đóng terminal này! Giữ nó mở, vì server đang chạy.

💻 3️⃣ Chạy frontend Flutter

📍 Mở một terminal mới, sau đó:

cd ...\study-p2p\flutter-app (tự sửa)


- Chạy ứng dụng Flutter Web:

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

