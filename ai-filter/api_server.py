"""
Toxic Comment Filter - Flask API Server
========================================
Đồ án DACS4 - Study P2P Application

API endpoint để kiểm tra tin nhắn có chứa nội dung thô tục hay không.
Sử dụng model đã được train từ train_model.py

Endpoints:
- POST /api/filter - Kiểm tra một tin nhắn
- POST /api/filter/batch - Kiểm tra nhiều tin nhắn
- GET /api/health - Health check

Author: Study P2P Team
"""

import os
import pickle
import json
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging

# Cấu hình logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Khởi tạo Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS cho Flutter web

# Đường dẫn
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, 'models', 'toxic_classifier.pkl')
METADATA_PATH = os.path.join(BASE_DIR, 'models', 'model_metadata.json')

# Global model variable
model = None
metadata = None

# Ngưỡng confidence - chỉ chặn khi confidence >= 75%
TOXIC_CONFIDENCE_THRESHOLD = 0.75

# Whitelist - các từ/cụm từ phổ biến KHÔNG BAO GIỜ là toxic
WHITELIST_WORDS = {
    # English greetings
    'hello', 'hi', 'hey', 'yo', 'sup', 'howdy', 'greetings',
    'good morning', 'good afternoon', 'good evening', 'good night',
    'morning', 'afternoon', 'evening', 'night',
    # Common words
    'yes', 'no', 'ok', 'okay', 'sure', 'thanks', 'thank you', 'please',
    'sorry', 'excuse me', 'welcome', 'bye', 'goodbye', 'see you',
    'how are you', 'fine', 'good', 'great', 'nice', 'cool', 'awesome',
    # Vietnamese greetings
    'xin chào', 'chào', 'chào bạn', 'chào mọi người',
    'cảm ơn', 'cám ơn', 'xin lỗi', 'không sao', 'được',
    'tốt', 'hay', 'tuyệt', 'đẹp', 'xinh', 'giỏi',
    # Single letters/numbers (prevent false positives)
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
}


def is_whitelisted(text):
    """Kiểm tra xem text có nằm trong whitelist không"""
    text_lower = text.lower().strip()
    # Exact match
    if text_lower in WHITELIST_WORDS:
        return True
    # Check if text is just a greeting with punctuation
    text_clean = ''.join(c for c in text_lower if c.isalnum() or c.isspace())
    if text_clean in WHITELIST_WORDS:
        return True
    return False


def load_model():
    """Load model từ file pickle"""
    global model, metadata
    
    try:
        logger.info(f"Loading model from {MODEL_PATH}...")
        with open(MODEL_PATH, 'rb') as f:
            model = pickle.load(f)
        
        logger.info(f"Loading metadata from {METADATA_PATH}...")
        with open(METADATA_PATH, 'r', encoding='utf-8') as f:
            metadata = json.load(f)
        
        logger.info("✅ Model loaded successfully!")
        return True
        
    except FileNotFoundError:
        logger.error("❌ Model file not found! Please run train_model.py first.")
        return False
    except Exception as e:
        logger.error(f"❌ Error loading model: {e}")
        return False


def predict_toxic(text):
    """
    Dự đoán một văn bản có toxic hay không
    
    Returns:
        dict: {
            'text': original text,
            'is_toxic': boolean,
            'confidence': float (0-1),
            'label': 'toxic' or 'non-toxic'
        }
    """
    if model is None:
        return {'error': 'Model not loaded'}
    
    # Tiền xử lý
    text_clean = str(text).lower().strip()
    
    # Kiểm tra whitelist trước
    if is_whitelisted(text_clean):
        return {
            'text': text,
            'is_toxic': False,
            'confidence': 0.0,
            'label': 'non-toxic',
            'reason': 'whitelisted'
        }
    
    # Predict
    prediction = model.predict([text_clean])[0]
    
    # Lấy confidence nếu có
    try:
        probabilities = model.predict_proba([text_clean])[0]
        # Lấy probability của class toxic (label=1)
        toxic_prob = float(probabilities[1])
        confidence = float(probabilities[prediction])
    except:
        toxic_prob = 1.0 if prediction == 1 else 0.0
        confidence = 1.0  # SVM không có predict_proba
    
    # Áp dụng ngưỡng confidence
    # Chỉ đánh dấu là toxic nếu probability >= threshold
    is_toxic = toxic_prob >= TOXIC_CONFIDENCE_THRESHOLD
    
    return {
        'text': text,
        'is_toxic': is_toxic,
        'confidence': toxic_prob,  # Trả về toxic probability thay vì confidence
        'label': 'toxic' if is_toxic else 'non-toxic',
        'threshold': TOXIC_CONFIDENCE_THRESHOLD
    }


# ============================================
# API ENDPOINTS
# ============================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None,
        'metadata': metadata
    })


@app.route('/api/filter', methods=['POST'])
def filter_message():
    """
    Kiểm tra một tin nhắn
    
    Request body:
        {
            "text": "message to check"
        }
    
    Response:
        {
            "text": "original message",
            "is_toxic": true/false,
            "confidence": 0.95,
            "label": "toxic"/"non-toxic"
        }
    """
    try:
        data = request.get_json()
        
        if not data or 'text' not in data:
            return jsonify({'error': 'Missing "text" field'}), 400
        
        text = data['text']
        result = predict_toxic(text)
        
        logger.info(f"Filter: '{text[:50]}...' -> {result['label']} ({result['confidence']:.2f})")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error in filter_message: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/filter/batch', methods=['POST'])
def filter_batch():
    """
    Kiểm tra nhiều tin nhắn cùng lúc
    
    Request body:
        {
            "texts": ["message1", "message2", ...]
        }
    
    Response:
        {
            "results": [
                {"text": "...", "is_toxic": ..., ...},
                ...
            ]
        }
    """
    try:
        data = request.get_json()
        
        if not data or 'texts' not in data:
            return jsonify({'error': 'Missing "texts" field'}), 400
        
        texts = data['texts']
        if not isinstance(texts, list):
            return jsonify({'error': '"texts" must be an array'}), 400
        
        results = [predict_toxic(text) for text in texts]
        
        return jsonify({'results': results})
        
    except Exception as e:
        logger.error(f"Error in filter_batch: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/filter/check', methods=['GET'])
def quick_check():
    """
    Quick check với query parameter
    
    Usage: GET /api/filter/check?text=hello
    """
    text = request.args.get('text', '')
    
    if not text:
        return jsonify({'error': 'Missing "text" parameter'}), 400
    
    result = predict_toxic(text)
    return jsonify(result)


# ============================================
# MAIN
# ============================================

if __name__ == '__main__':
    print("\n" + "="*60)
    print("🤖 TOXIC FILTER API SERVER")
    print("   Study P2P - DACS4 Project")
    print("="*60 + "\n")
    
    # Load model khi khởi động
    if not load_model():
        print("\n⚠️  WARNING: Model not loaded. Please run train_model.py first!")
        print("   The server will start but predictions will fail.\n")
    
    # Chạy server
    print("\n🚀 Starting server on http://localhost:5000")
    print("   Endpoints:")
    print("   - POST /api/filter       - Check single message")
    print("   - POST /api/filter/batch - Check multiple messages")
    print("   - GET  /api/filter/check - Quick check with query param")
    print("   - GET  /api/health       - Health check")
    print("\n" + "="*60 + "\n")
    
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,
        threaded=True
    )
