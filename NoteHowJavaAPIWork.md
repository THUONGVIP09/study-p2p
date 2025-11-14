# 🚀 Kết nối Flutter Frontend với Java Backend (Spring Boot)

## 💡 1. Cấu trúc tổng quát

- **Java Backend (Spring Boot)**  
  → Chạy như một **web server**, cung cấp các **API REST** (ví dụ: `/api/login`, `/api/register`, `/api/getData`, ...).  
  Flutter sẽ gửi request đến các API này, Java xử lý và **trả về dữ liệu JSON**.

  > Ví dụ:  
  > Flutter gửi `POST /api/login` → Java kiểm tra database → trả về  
  > `{ "status": "success" }`

- **Flutter Frontend**  
  → Giao diện ứng dụng. Khi cần lấy hoặc gửi dữ liệu (đăng nhập, tải danh sách, ...), Flutter dùng thư viện **`http`** để gọi tới server Java.

---

## ⚙️ 2. Luồng hoạt động

### 🧩 Bước 1: Chạy Server Java

```bash
cd server-java/demo
mvn clean package
java -jar target/demo-1.0-SNAPSHOT.jar
Server sẽ chạy ở địa chỉ:
http://localhost:8080

🖥️ Bước 2: Flutter gọi API từ Backend
dart

import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('http://localhost:8080/api/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode == 200) {
    print('Đăng nhập thành công: ${response.body}');
  } else {
    print('Lỗi: ${response.statusCode}');
  }
}
☕ Bước 3: Java xử lý yêu cầu
java

@RestController
@RequestMapping("/api")
public class AuthController {

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody User user) {
        if (user.getEmail().equals("test@gmail.com") && user.getPassword().equals("123456")) {
            return ResponseEntity.ok(Map.of("status", "success"));
        } else {
            return ResponseEntity.status(401).body(Map.of("status", "fail"));
        }
    }
}
🧭 3. Tóm tắt nhanh
Bước	Thực hiện ở đâu	Mục đích
1️⃣	Java Backend	Tạo API REST (đường dẫn /api/...)
2️⃣	Flutter	Gọi API bằng http
3️⃣	Java	Xử lý dữ liệu, trả JSON
4️⃣	Flutter	Hiển thị kết quả trên UI

