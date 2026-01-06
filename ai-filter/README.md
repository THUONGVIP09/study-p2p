# AI Filter - Toxic Comment Classifier

## 📋 Mô tả

Hệ thống phân loại bình luận thô tục (toxic comment classifier) sử dụng Machine Learning.
Được phát triển cho đồ án DACS4 - Study P2P Application.

## 🧠 Thuật toán

Sử dụng kết hợp:
- **TF-IDF Vectorization**: Chuyển văn bản thành vector số
- **Multiple Classifiers**:
  - Naive Bayes (MultinomialNB)
  - Logistic Regression
  - Support Vector Machine (LinearSVC)
  - Random Forest

Model tốt nhất sẽ được tự động chọn dựa trên accuracy.

## 📁 Cấu trúc thư mục

```
ai-filter/
├── data/
│   └── toxic_dataset.csv    # Dataset training (Vietnamese + English)
├── models/
│   ├── toxic_classifier.pkl  # Model đã train
│   └── model_metadata.json   # Thông tin model
├── train_model.py           # Script training
├── api_server.py            # Flask API server
├── requirements.txt         # Python dependencies
└── README.md               # Documentation
```

## 🚀 Hướng dẫn sử dụng

### 1. Cài đặt dependencies

```bash
cd ai-filter
pip install -r requirements.txt
```

### 2. Train model

```bash
python train_model.py
```

Output:
- `models/toxic_classifier.pkl` - Model đã train
- `models/model_metadata.json` - Thông tin về model

### 3. Chạy API Server

```bash
python api_server.py
```

Server sẽ chạy tại `http://localhost:5000`

## 📡 API Endpoints

### POST /api/filter
Kiểm tra một tin nhắn.

**Request:**
```json
{
    "text": "Xin chào bạn"
}
```

**Response:**
```json
{
    "text": "Xin chào bạn",
    "is_toxic": false,
    "confidence": 0.95,
    "label": "non-toxic"
}
```

### POST /api/filter/batch
Kiểm tra nhiều tin nhắn.

**Request:**
```json
{
    "texts": ["Xin chào", "Đồ ngu"]
}
```

**Response:**
```json
{
    "results": [
        {"text": "Xin chào", "is_toxic": false, ...},
        {"text": "Đồ ngu", "is_toxic": true, ...}
    ]
}
```

### GET /api/filter/check?text=...
Quick check với query parameter.

### GET /api/health
Health check endpoint.

## 📊 Dataset

Dataset bao gồm:
- **Non-toxic (label=0)**: Các câu bình thường, lịch sự
- **Toxic (label=1)**: Các câu chứa từ ngữ thô tục, xúc phạm

Ngôn ngữ hỗ trợ:
- 🇻🇳 Tiếng Việt
- 🇺🇸 Tiếng Anh

## 🔧 Tùy chỉnh

### Thêm từ vào dataset
Chỉnh sửa file `data/toxic_dataset.csv`:
```csv
text,label
"từ mới",1
"câu bình thường",0
```

Sau đó chạy lại `python train_model.py`.

### Thay đổi thuật toán
Chỉnh sửa trong `train_model.py`, function `create_pipelines()`.

## 📝 Ghi chú

- Model sử dụng TF-IDF nên cần train lại nếu muốn thêm từ mới
- Confidence score cho biết độ tin cậy của dự đoán
- Hỗ trợ cả tiếng Việt có dấu và không dấu
