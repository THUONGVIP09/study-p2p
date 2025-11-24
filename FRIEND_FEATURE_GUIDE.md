# Friend Feature User Guide

## Tổng Quan

Chức năng Friend (Bạn bè) đã được hoàn thành và sẵn sàng để demo. Tính năng này cho phép người dùng:
- Tìm kiếm và kết bạn với người dùng khác
- Quản lý lời mời kết bạn (gửi, nhận, chấp nhận, từ chối)
- Quản lý danh sách bạn bè
- Chặn/bỏ chặn người dùng

## Cấu Trúc

### Backend (Java)
Các controller đã được đăng ký trong `Main.java`:
- **FriendsController**: Quản lý danh sách bạn bè
- **FriendRequestsController**: Quản lý lời mời kết bạn
- **BlockedUsersController**: Quản lý người dùng bị chặn
- **FindFriendsController**: Tìm kiếm người dùng mới

### Frontend (Flutter)
Giao diện người dùng có 4 tab chính:
1. **Friends**: Danh sách bạn bè hiện tại
2. **Friend Requests**: Lời mời kết bạn nhận được
3. **Blocked Users**: Danh sách người dùng đã chặn
4. **Find Friends**: Tìm kiếm và kết bạn mới

## Hướng Dẫn Sử Dụng

### 1. Tìm Kiếm Bạn Bè Mới

**Bước 1:** Mở tab "Find Friends"
**Bước 2:** Nhập tên hoặc email của người dùng (tối thiểu 2 ký tự)
**Bước 3:** Nhấn nút "Add" để gửi lời mời kết bạn

**Ghi chú:** 
- Nếu đã gửi lời mời, sẽ hiển thị badge "Pending" (màu cam)
- Nếu người dùng bị chặn, sẽ hiển thị badge "Blocked" (màu đỏ)

### 2. Quản Lý Lời Mời Kết Bạn

#### Nhận Lời Mời
**Tab:** Friend Requests

**Hành động:**
- ✅ **Accept** (biểu tượng check màu xanh): Chấp nhận lời mời
- ❌ **Reject** (biểu tượng cancel màu đỏ): Từ chối lời mời

#### Lời Mời Đã Gửi
Để xem lời mời đã gửi, sử dụng API endpoint:
```
GET /api/friend-requests/sent
```

### 3. Quản Lý Bạn Bè

**Tab:** Friends

**Chức năng:**
- 🔍 Tìm kiếm bạn bè theo tên hoặc email
- 💬 Message (chức năng sẽ có trong tương lai)
- 🗑️ Remove Friend: Xóa bạn bè
- 🚫 Block: Chặn người dùng

**Xóa Bạn Bè:**
1. Nhấn vào menu (3 chấm) bên cạnh tên bạn
2. Chọn "Remove Friend"
3. Xác nhận trong dialog popup
4. Danh sách sẽ tự động cập nhật

**Chặn Người Dùng:**
1. Nhấn vào menu (3 chấm) bên cạnh tên bạn
2. Chọn "Block"
3. Đọc và xác nhận cảnh báo trong dialog
   - Sẽ xóa khỏi danh sách bạn bè
   - Sẽ xóa tất cả lời mời kết bạn liên quan
4. Người dùng sẽ được chuyển sang danh sách "Blocked Users"

### 4. Quản Lý Người Dùng Bị Chặn

**Tab:** Blocked Users

**Chức năng:**
- Xem danh sách người dùng đã chặn
- Bỏ chặn người dùng

**Bỏ Chặn:**
1. Nhấn nút "Unblock" bên cạnh tên người dùng
2. Xác nhận trong dialog popup
3. Người dùng sẽ bị xóa khỏi danh sách chặn

## API Endpoints

### Friend Management
```
GET    /api/friends              - Danh sách bạn bè
GET    /api/friends/{userId}     - Chi tiết bạn bè
DELETE /api/friends/{userId}     - Xóa bạn bè
```

### Friend Requests
```
GET    /api/friend-requests              - Lời mời nhận được
GET    /api/friend-requests/sent         - Lời mời đã gửi
POST   /api/friend-requests              - Gửi lời mời mới
POST   /api/friend-requests/{id}/accept  - Chấp nhận
POST   /api/friend-requests/{id}/reject  - Từ chối
DELETE /api/friend-requests/{id}         - Hủy lời mời
```

### Blocked Users
```
GET    /api/blocked-users           - Danh sách người bị chặn
POST   /api/blocked-users           - Chặn người dùng
DELETE /api/blocked-users/{userId}  - Bỏ chặn
```

### Find Friends
```
GET /api/find-friends?q=search  - Tìm kiếm người dùng
```

## Xử Lý Lỗi

Tất cả các hành động đều có xử lý lỗi:
- **Thành công:** Hiển thị SnackBar màu xanh với thông báo thành công
- **Lỗi:** Hiển thị SnackBar màu đỏ với mô tả lỗi
- **Xác nhận:** Dialog popup cho các hành động quan trọng

## Database Schema

### Tables
- `users`: Thông tin người dùng
- `friendships`: Quan hệ bạn bè (ACTIVE/BLOCKED/REMOVED)
- `friend_requests`: Lời mời kết bạn (PENDING/ACCEPTED/REJECTED/CANCELED)
- `user_blocks`: Danh sách chặn

### Validations
Backend thực hiện các kiểm tra:
- Không thể gửi lời mời cho chính mình
- Không thể gửi lời mời nếu đã là bạn bè
- Không thể gửi lời mời nếu đã tồn tại
- Không thể gửi lời mời nếu bị chặn
- Chỉ người nhận mới có thể chấp nhận/từ chối
- Chỉ người gửi mới có thể hủy lời mời

## Demo Flow

### Kịch Bản 1: Kết Bạn Thành Công
1. User A: Tìm kiếm User B trong "Find Friends"
2. User A: Nhấn "Add" để gửi lời mời
3. User B: Mở tab "Friend Requests", thấy lời mời từ User A
4. User B: Nhấn Accept
5. Cả hai user đều thấy nhau trong tab "Friends"

### Kịch Bản 2: Xóa Bạn Bè
1. User A: Mở tab "Friends"
2. User A: Nhấn menu → "Remove Friend" → Confirm
3. User B biến mất khỏi danh sách

### Kịch Bản 3: Chặn Người Dùng
1. User A: Mở tab "Friends"
2. User A: Nhấn menu → "Block" → Confirm
3. User B chuyển sang tab "Blocked Users"
4. User B không thể gửi lời mời cho User A

### Kịch Bản 4: Bỏ Chặn
1. User A: Mở tab "Blocked Users"
2. User A: Nhấn "Unblock" → Confirm
3. User B biến mất khỏi danh sách chặn
4. Có thể kết bạn lại

## Ghi Chú Kỹ Thuật

### Frontend
- Sử dụng `http` package cho REST API calls
- Tất cả request đều có Authorization header (Bearer token)
- Tự động refresh danh sách sau khi thực hiện hành động
- Confirmation dialogs cho hành động xóa/chặn

### Backend
- Jersey (JAX-RS) cho REST endpoints
- MySQL database
- Hardcoded userId = 1 (TODO: thay bằng JWT token parsing)
- CORS filter cho phép cross-origin requests

## TODO / Future Enhancements

1. **Authentication:** Thay userId hardcoded bằng JWT token parsing thực tế
2. **Notifications:** Gửi thông báo khi có lời mời kết bạn
3. **Real-time Updates:** WebSocket cho cập nhật real-time
4. **Message Feature:** Hoàn thiện tính năng nhắn tin giữa bạn bè
5. **Online Status:** Hiển thị trạng thái online/offline
6. **Pagination:** Thêm phân trang cho danh sách dài

## Testing

### Manual Testing Checklist
- [ ] Tìm kiếm người dùng mới
- [ ] Gửi lời mời kết bạn
- [ ] Chấp nhận lời mời kết bạn
- [ ] Từ chối lời mời kết bạn
- [ ] Xóa bạn bè
- [ ] Chặn người dùng
- [ ] Bỏ chặn người dùng
- [ ] Search functionality trong mỗi tab
- [ ] Confirmation dialogs hiển thị đúng
- [ ] Error messages hiển thị khi có lỗi

## Support

Nếu có vấn đề khi sử dụng tính năng:
1. Kiểm tra backend server đang chạy (port 8080)
2. Kiểm tra database đã được setup
3. Kiểm tra network logs trong browser DevTools
4. Xem server logs để debug

---

**Last Updated:** 2025-11-24  
**Version:** 1.0  
**Status:** ✅ Complete and Ready for Demo
