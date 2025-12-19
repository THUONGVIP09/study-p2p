# ML Service - Chat Summarization

Service Python sử dụng Flask và Hugging Face Transformers để tóm tắt chat.

## Cài đặt

```bash
pip install -r requirements.txt
```

## Chạy service

```bash
python ml_service.py
```

Service sẽ chạy trên `http://localhost:5001`

## API Endpoints

### 1. Health Check
```
GET /health
```

### 2. Tóm tắt văn bản đơn
```
POST /summarize
Content-Type: application/json

{
  "text": "văn bản cần tóm tắt",
  "max_length": 130,
  "min_length": 30
}
```

### 3. Tóm tắt batch messages
```
POST /summarize/batch
Content-Type: application/json

{
  "messages": [
    {"sender": "User1", "content": "Xin chào"},
    {"sender": "User2", "content": "Chào bạn"}
  ],
  "max_length": 150,
  "min_length": 40
}
```

## Model

Mặc định sử dụng `facebook/bart-large-cnn` cho tiếng Anh.

Để dùng model tiếng Việt, thay đổi trong `ml_service.py`:
```python
summarizer = pipeline("summarization", model="VietAI/vit5-base-vietnews-summarization")
```

## Lưu ý

- Model sẽ được tải khi service khởi động (có thể mất vài phút lần đầu)
- Văn bản quá dài (>4000 ký tự) sẽ bị cắt bớt
- Văn bản quá ngắn (<50 ký tự) sẽ trả về nguyên bản
