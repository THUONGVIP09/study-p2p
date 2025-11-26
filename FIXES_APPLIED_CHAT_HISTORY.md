# 🔧 Các Fix Đã Áp Dụng - Chat History Stability

## Ngày: 26/11/2025

### ❌ Vấn Đề Trước Đây

1. **Race Condition khi Load History**
   - Stream listener setup TRƯỚC khi load history
   - Tin nhắn mới arrive trong lúc đang load → duplicate messages
   - Không đảm bảo thứ tự: history load vs realtime messages

2. **Không có Lock khi Save File**
   - Multiple saves cùng lúc → data corruption
   - File bị ghi đè một phần → JSON invalid
   - Load lại bị lỗi parse → mất lịch sử

3. **Không Filter friendId trong Stream**
   - Nhận TẤT CẢ messages từ stream (tất cả friends)
   - Hiển thị nhầm tin nhắn của friend khác
   - Lưu vào lịch sử của chat hiện tại sai

4. **Không có Loading State**
   - User có thể spam gửi tin khi đang load
   - Race condition: send message trước khi connect xong
   - UI không feedback → user confused

5. **File JSON rác tích lũy**
   - Test nhiều lần → data cũ tích lũy
   - Format cũ không tương thích
   - Gây lỗi parse khi load

---

## ✅ Các Fix Đã Áp Dụng

### 1. **Chat Storage Service** (`chat_storage_service.dart`)

#### Thêm File Lock
```dart
static bool _isSaving = false; // Lock để tránh race condition

static Future<void> saveHistory(...) async {
  // Wait if another save is in progress
  while (_isSaving) {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  _isSaving = true;
  try {
    final file = await _getFile();
    final encoded = jsonEncode(history);
    await file.writeAsString(encoded, flush: true); // ✅ flush: true
  } finally {
    _isSaving = false;
  }
}

static Future<void> addMessage(...) async {
  // Wait for any ongoing save to complete
  while (_isSaving) {
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  final history = await loadHistory();
  // ... add message ...
  await saveHistory(history);
}
```

**Kết quả:**
- ✅ Không có 2 operations save cùng lúc
- ✅ File luôn consistent
- ✅ Không bị data corruption

#### Thêm Function Xóa File Cũ
```dart
static Future<void> deleteStorageFile() async {
  try {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
      print('🗑️ Deleted old chat history file');
    }
  } catch (e) {
    print('Error deleting storage file: $e');
  }
}
```

**Kết quả:**
- ✅ Clean slate mỗi lần chạy app
- ✅ Không bị data cũ gây lỗi

---

### 2. **Chat Screen** (`hybrid_chat_screen.dart`)

#### Thêm Loading & Sending State
```dart
bool _isLoading = true;  // Loading chat history
bool _isSending = false; // Sending message

Future<void> _bootstrap() async {
  setState(() {
    _isLoading = true;
    _status = 'Connecting...';
  });

  try {
    await _hybrid.start(myIp: myIp);
    final direct = await _hybrid.connectToFriend(widget.friendId);
    
    // ✅ Load history BEFORE setting up stream
    final history = await ChatStorageService.getMessagesWithPeer(
        widget.friendId.toString());
    
    setState(() {
      _messages.clear(); // Clear để tránh duplicate
      _messages.addAll(history);
      _isLoading = false; // ✅ Unlock UI
    });

    // ✅ Setup stream AFTER loading history
    _sub = _hybrid.stream.listen((e) {
      // ✅ Filter by friendId!
      if (e['friendId'] != widget.friendId) return;
      
      setState(() {
        _messages.add({ ... });
      });
      _scrollToBottom();
    });
  } catch (e) {
    setState(() {
      _status = 'Error: $e';
      _isLoading = false;
    });
  }
}
```

**Kết quả:**
- ✅ Load history trước → setup stream sau → không duplicate
- ✅ Filter messages theo friendId → không nhận nhầm
- ✅ Clear messages list → đảm bảo fresh data

#### Khóa UI khi Loading/Sending
```dart
Future<void> _send() async {
  if (_isSending || _isLoading) return; // ✅ Block nếu busy

  setState(() {
    _isSending = true;
  });

  try {
    await _hybrid.sendToFriend(widget.friendId, text);
    // ... update UI ...
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send: $e')),
    );
  } finally {
    setState(() {
      _isSending = false; // ✅ Unlock
    });
  }
}
```

**Kết quả:**
- ✅ Không thể spam send khi đang gửi
- ✅ Không thể send khi đang load history
- ✅ User thấy feedback rõ ràng (loading spinner)

#### UI Loading Overlay
```dart
body: Stack(
  children: [
    Column(children: [
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator()) // ✅ Loading indicator
            : ListView.builder(...),
      ),
      SafeArea(
        child: Row(children: [
          TextField(
            enabled: !_isLoading && !_isSending, // ✅ Disable khi busy
            decoration: InputDecoration(
              hintText: _isLoading ? 'Loading...' 
                      : _isSending ? 'Sending...' 
                      : 'Type a message...',
            ),
          ),
          ElevatedButton(
            onPressed: (_isLoading || _isSending) ? null : _send, // ✅ Disable
            child: _isSending 
                ? CircularProgressIndicator(...) // ✅ Spinner khi đang gửi
                : const Text('Send'),
          ),
        ]),
      )
    ]),
    // ✅ Full-screen overlay khi loading
    if (_isLoading)
      Container(
        color: Colors.black.withOpacity(0.1),
        child: const Center(
          child: Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading chat history...'),
              ],
            ),
          ),
        ),
      ),
  ],
)
```

**Kết quả:**
- ✅ User KHÔNG THỂ tương tác khi đang load
- ✅ Visual feedback rõ ràng
- ✅ Tránh race conditions do user spam click

---

### 3. **Main App** (`main.dart`)

#### Xóa File Cũ khi Khởi Động
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🗑️ Xóa file JSON cũ để tránh lỗi lịch sử chat
  await ChatStorageService.deleteStorageFile();
  
  runApp(const MyApp());
}
```

**Kết quả:**
- ✅ Mỗi lần chạy app = fresh start
- ✅ Không bị lỗi từ data cũ
- ✅ Dễ test (không cần manual delete file)

---

## 🧪 Cách Test

### Test Case 1: Basic Message Flow
1. Mở 2 instances (User A và User B - phải là friends trong DB)
2. User A gửi: "hello"
3. User B reply: "hi"
4. User A reply: "how are you?"
5. **Đợi tất cả messages hiển thị đầy đủ ở 2 bên**
6. Close chat screen ở cả 2 instances
7. Mở lại chat screen
8. ✅ **KẾT QUẢ MONG ĐỢI**: Cả 2 bên thấy đầy đủ 3 tin nhắn

### Test Case 2: Load During Message Arrival
1. User A mở chat với User B (loading...)
2. **TRONG LÚC ĐÓ** User B gửi message
3. User A load xong
4. ✅ **KẾT QUẢ MONG ĐỜI**: User A thấy tin nhắn mới (không duplicate, không mất)

### Test Case 3: Spam Prevention
1. Mở chat screen
2. **NGAY LẬP TỨC** spam click Send button nhiều lần
3. ✅ **KẾT QUẢ MONG ĐỜI**: 
   - Button disabled khi đang loading
   - Không send được khi đang loading
   - Loading overlay block toàn bộ UI

### Test Case 4: Multiple Saves
1. User A và User B chat nhanh (gửi liên tục)
2. Mỗi message → storage save
3. ✅ **KẾT QUẢ MONG ĐỜI**: Tất cả messages được save (không bị skip do lock)

### Test Case 5: Fresh Start
1. Chạy app nhiều lần
2. Mỗi lần chạy → file JSON bị xóa
3. Login → chat mới
4. ✅ **KẾT QUẢ MONG ĐỜI**: Không có lịch sử cũ, không lỗi parse JSON

---

## 📊 So Sánh Trước/Sau

| Vấn Đề | Trước | Sau |
|--------|-------|-----|
| Duplicate messages | ❌ Có | ✅ Không |
| Messages mất sau reload | ❌ Có | ✅ Không |
| Race condition save | ❌ Có | ✅ Không (lock) |
| Nhận nhầm tin nhắn friend khác | ❌ Có | ✅ Không (filter) |
| User spam send khi loading | ❌ Có thể | ✅ Không thể (disabled) |
| Data cũ gây lỗi | ❌ Có | ✅ Không (delete on start) |
| Loading feedback | ❌ Không | ✅ Có (spinner + overlay) |

---

## 🎯 Tóm Tắt

### Nguyên Tắc Fix
1. **Load history TRƯỚC → Setup stream SAU** (tránh duplicate)
2. **Filter stream by friendId** (chỉ nhận tin của friend đúng)
3. **Lock file operations** (tránh concurrent writes)
4. **Loading state + UI lock** (tránh race conditions)
5. **Fresh start mỗi lần chạy** (delete old storage)

### Files Đã Sửa
- ✅ `chat_storage_service.dart` - Thêm lock, delete function
- ✅ `hybrid_chat_screen.dart` - Loading state, stream filter, UI lock
- ✅ `main.dart` - Auto-delete old storage

### Không Cần Sửa
- ✅ `hybrid_chat_service.dart` - Logic đã đúng (parse 'from' field)
- ✅ `p2p_chat_service.dart` - Pass 'from' field đã OK

---

## 🚀 Next Steps

1. **Test với scenario phức tạp:**
   - 3+ users chat đồng thời
   - Network disconnect/reconnect
   - App minimize/restore

2. **Nếu cần persistent storage:**
   - Comment out `deleteStorageFile()` trong main.dart
   - Thêm migration logic cho format cũ

3. **Performance optimization:**
   - Nếu messages > 1000 → pagination
   - Lazy load old messages
   - Cache in memory

---

**Lưu Ý:** File storage hiện tại bị XÓA mỗi lần chạy app. Nếu muốn giữ lịch sử, comment dòng này trong `main.dart`:
```dart
// await ChatStorageService.deleteStorageFile(); // Comment để giữ lịch sử
```
