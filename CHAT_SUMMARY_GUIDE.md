# Chat Summary - Hướng dẫn Triển khai và Sử dụng

## Tổng quan

Chức năng Chat Summary sử dụng AI để tóm tắt nội dung chat trong phòng hoặc cuộc trò chuyện 1-1. Hệ thống bao gồm 3 thành phần chính:

1. **Python ML Service** - Service AI chạy local với Hugging Face Transformers
2. **Java Backend** - API endpoints để xử lý request từ client
3. **Flutter Frontend** - UI để hiển thị nút tóm tắt và kết quả

## Kiến trúc

```
Flutter App (UI)
    ↓ HTTP
Java Backend (API)
    ↓ HTTP
Python ML Service (AI)
    ↓
Hugging Face Model (BART)
```

## Cài đặt và Chạy

### 1. Python ML Service

#### Cài đặt dependencies

```bash
cd ml-service
pip install -r requirements.txt
```

**Lưu ý:** Lần đầu chạy sẽ tải model (~500MB), có thể mất vài phút.

#### Chạy service

```bash
python ml_service.py
```

Service sẽ chạy trên `http://localhost:5001`

#### Kiểm tra health

```bash
curl http://localhost:5001/health
```

Kết quả:
```json
{
  "status": "healthy",
  "model_loaded": true
}
```

### 2. Java Backend

Java backend đã có sẵn endpoints, chỉ cần đảm bảo:

- `ChatSummaryController.java` - Endpoints `/api/chat/summary/room` và `/api/chat/summary/conversation`
- `ChatSummaryService.java` - Service gọi Python ML service

Endpoints:
- `GET /api/chat/summary/health` - Kiểm tra ML service
- `POST /api/chat/summary/room` - Tóm tắt chat trong phòng
- `POST /api/chat/summary/conversation` - Tóm tắt chat 1-1

### 3. Flutter App

Flutter app đã được tích hợp:

- `ApiService.summarizeRoomChat()` - Gọi API tóm tắt room
- `ApiService.summarizeConversation()` - Gọi API tóm tắt conversation
- Nút "Tóm tắt" trong `call_page.dart` (chat panel)
- Icon tóm tắt trong `hybrid_chat_screen.dart` (AppBar)

## Sử dụng

### 1. Trong Call (Room Chat)

1. Tham gia một phòng call
2. Mở chat panel (icon chat ở sidebar)
3. Nhấn nút "Tóm tắt" ở đầu chat panel
4. Xem kết quả tóm tắt và điểm chính

### 2. Trong Chat 1-1

1. Mở conversation với bạn bè
2. Nhấn icon "summarize" (📝) trên AppBar
3. Xem kết quả tóm tắt

## API Reference

### POST /api/chat/summary/room

Tóm tắt chat trong phòng

**Request:**
```json
{
  "roomId": 123,
  "limit": 100,
  "maxLength": 150,
  "minLength": 40
}
```

**Response:**
```json
{
  "success": true,
  "summary": "Cuộc thảo luận tập trung vào...",
  "keyPoints": [
    "Điểm 1: ...",
    "Điểm 2: ..."
  ],
  "messageCount": 45,
  "originalLength": 2340,
  "summaryLength": 125
}
```

### POST /api/chat/summary/conversation

Tóm tắt chat 1-1

**Request:**
```json
{
  "friendId": 456,
  "limit": 100,
  "maxLength": 150,
  "minLength": 40
}
```

**Response:** Tương tự như `/room`

## Troubleshooting

### ML Service không khả dụng

**Lỗi:** "ML Service không khả dụng. Vui lòng khởi động ml-service trước."

**Giải pháp:**
1. Kiểm tra Python service đang chạy: `curl http://localhost:5001/health`
2. Khởi động lại: `python ml-service/ml_service.py`
3. Kiểm tra port 5001 không bị chiếm bởi app khác

### Model tải chậm

**Nguyên nhân:** Lần đầu chạy phải tải model từ Hugging Face

**Giải pháp:**
- Đợi model tải xong (xem log trong terminal)
- Chuyển sang model nhỏ hơn nếu cần:
  ```python
  # Trong ml_service.py
  summarizer = pipeline("summarization", model="facebook/bart-base")  # Nhỏ hơn
  ```

### Chat quá ngắn

**Lỗi:** "Không có tin nhắn để tóm tắt"

**Nguyên nhân:** Chat có ít hơn 50 ký tự

**Giải pháp:** Gửi thêm tin nhắn để có đủ nội dung tóm tắt

### Tóm tắt không chính xác

**Nguyên nhân:** Model tiếng Anh không hiểu tiếng Việt tốt

**Giải pháp:** Chuyển sang model tiếng Việt:
```python
# Trong ml_service.py, dòng 23
summarizer = pipeline("summarization", model="VietAI/vit5-base-vietnews-summarization")
```

## Tùy chỉnh

### Thay đổi độ dài tóm tắt

Trong Flutter app, khi gọi API:

```dart
final result = await ApiService.summarizeRoomChat(
  roomId: roomId,
  limit: 100,      // Số tin nhắn lấy
  maxLength: 200,  // Tăng độ dài tóm tắt
  minLength: 50,   // Độ dài tối thiểu
);
```

### Thay đổi model AI

Trong `ml_service.py`:

```python
# Model tiếng Anh (mặc định)
summarizer = pipeline("summarization", model="facebook/bart-large-cnn")

# Model tiếng Việt
summarizer = pipeline("summarization", model="VietAI/vit5-base-vietnews-summarization")

# Model nhỏ hơn, nhanh hơn
summarizer = pipeline("summarization", model="facebook/bart-base")
```

## Performance

- **Thời gian xử lý:** 2-5 giây cho 100 tin nhắn
- **RAM:** ~2GB khi model loaded
- **Giới hạn:** Tối đa 100 tin nhắn/lần (có thể tăng trong code)

## Bảo mật

- ML service chỉ chạy local, không gửi dữ liệu ra ngoài
- Cần xác thực JWT từ Java backend
- Room chat chỉ có thể tóm tắt bởi members trong room

## Tính năng tương lai

- [ ] Cache kết quả tóm tắt trong database
- [ ] Hỗ trợ tóm tắt theo khoảng thời gian
- [ ] Export tóm tắt ra file PDF/Word
- [ ] Tóm tắt tự động định kỳ
- [ ] Phân tích sentiment (tích cực/tiêu cực)
- [ ] Gợi ý chủ đề chính trong cuộc trò chuyện
