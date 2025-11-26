# Hướng dẫn Setup Database cho Call Feature

## Dành cho cộng sự (đường dẫn: D:\dev\doan4\study-p2p)

### Bước 1: Tìm MySQL Client

Chạy lệnh này để tìm MySQL client trên máy:

```powershell
Get-ChildItem -Path "C:\Program Files\MySQL" -Recurse -Filter "mysql.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
```

**Lưu ý đường dẫn MySQL client trả về**, ví dụ: `C:\Program Files\MySQL\MySQL Server 9.5\bin\mysql.exe`

### Bước 2: Chạy SQL Setup Script

**Thay thế các thông tin sau:**
- `<MYSQL_PATH>`: Đường dẫn MySQL client từ bước 1
- `<YOUR_PASSWORD>`: Mật khẩu MySQL của bạn
- `<DATABASE_NAME>`: Tên database (mặc định là `study_p2p`)

```powershell
# Chuyển đến thư mục dự án
cd D:\dev\doan4\study-p2p

# Chạy file setup_call_tables.sql
Get-Content "D:\dev\doan4\study-p2p\server-java\demo\sql\setup_call_tables.sql" | & "C:\Program Files\MySQL\MySQL Server 9.5\bin\mysql.exe" -u root -p<YOUR_PASSWORD> study_p2p
```

**Ví dụ cụ thể** (nếu password là `123456`):

```powershell
Get-Content "D:\dev\doan4\study-p2p\server-java\demo\sql\setup_call_tables.sql" | & "C:\Program Files\MySQL\MySQL Server 9.5\bin\mysql.exe" -u root -p123456 study_p2p
```

### Bước 3: Verify Tables và Views đã được tạo

```powershell
& "C:\Program Files\MySQL\MySQL Server 9.5\bin\mysql.exe" -u root -p<YOUR_PASSWORD> study_p2p -e "SHOW TABLES LIKE '%call%';"
```

**Kết quả mong đợi:**
```
+------------------------------+
| Tables_in_study_p2p (%call%) |
+------------------------------+
| call_participants            |
| call_sessions                |
| v_call_session_live          |
+------------------------------+
```

### Bước 4: Kiểm tra chi tiết View

```powershell
& "C:\Program Files\MySQL\MySQL Server 9.5\bin\mysql.exe" -u root -p<YOUR_PASSWORD> study_p2p -e "DESCRIBE v_call_session_live;"
```

---

## Lệnh All-in-One (Copy & Run)

**Thay `YOUR_PASSWORD` và `MYSQL_PATH` trước khi chạy:**

```powershell
# 1. Tìm MySQL
$mysqlPath = Get-ChildItem -Path "C:\Program Files\MySQL" -Recurse -Filter "mysql.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
Write-Host "MySQL found at: $mysqlPath" -ForegroundColor Green

# 2. Đặt biến
$projectPath = "D:\dev\doan4\study-p2p"
$sqlFile = "$projectPath\server-java\demo\sql\setup_call_tables.sql"
$dbPassword = "YOUR_PASSWORD"  # <-- THAY MẬT KHẨU Ở ĐÂY
$dbName = "study_p2p"

# 3. Chạy SQL
Write-Host "Running SQL setup..." -ForegroundColor Yellow
Get-Content $sqlFile | & $mysqlPath -u root -p$dbPassword $dbName

# 4. Verify
Write-Host "`nVerifying tables..." -ForegroundColor Yellow
& $mysqlPath -u root -p$dbPassword $dbName -e "SHOW TABLES LIKE '%call%';"

Write-Host "`nSetup completed!" -ForegroundColor Green
```

---

## Troubleshooting

### Lỗi: "mysql: command not found"
- MySQL chưa được cài hoặc chưa có trong PATH
- Sử dụng đường dẫn đầy đủ như ví dụ trên

### Lỗi: "Access denied"
- Kiểm tra lại username/password
- Đảm bảo user có quyền CREATE TABLE và CREATE VIEW

### Lỗi: "Unknown database 'study_p2p'"
- Tạo database trước:
```powershell
& "C:\Program Files\MySQL\MySQL Server 9.5\bin\mysql.exe" -u root -p<YOUR_PASSWORD> -e "CREATE DATABASE IF NOT EXISTS study_p2p CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

---

## Files được tạo

1. **call_sessions** - Bảng lưu thông tin call sessions
2. **call_participants** - Bảng lưu thông tin participants trong call
3. **v_call_session_live** - VIEW đếm số participants đang active

## Sau khi setup xong

1. Restart Java server
2. Test join call từ Flutter app
3. API `/api/calls/latest` sẽ hoạt động bình thường
