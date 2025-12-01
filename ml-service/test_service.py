"""
Test script cho Chat Summary ML Service
Kiểm tra các endpoint và chức năng của Python ML service
"""

import requests
import json
import time

# URL của ML service
BASE_URL = "http://localhost:5001"

def print_test(name):
    print("\n" + "="*60)
    print(f"TEST: {name}")
    print("="*60)

def test_health():
    """Test health check endpoint"""
    print_test("Health Check")
    
    try:
        response = requests.get(f"{BASE_URL}/health")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200 and response.json().get('model_loaded'):
            print("✅ Health check PASSED")
            return True
        else:
            print("❌ Health check FAILED")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_summarize_short_text():
    """Test tóm tắt văn bản ngắn"""
    print_test("Summarize Short Text")
    
    data = {
        "text": "Hello world",
        "max_length": 130,
        "min_length": 30
    }
    
    try:
        response = requests.post(f"{BASE_URL}/summarize", json=data)
        print(f"Status Code: {response.status_code}")
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2, ensure_ascii=False)}")
        
        if response.status_code == 200:
            print("✅ Short text test PASSED")
            return True
        else:
            print("❌ Short text test FAILED")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_summarize_long_text():
    """Test tóm tắt văn bản dài"""
    print_test("Summarize Long Text")
    
    # Văn bản mẫu dài
    long_text = """
    The transformer architecture has revolutionized natural language processing.
    It was introduced in the paper "Attention is All You Need" by Vaswani et al. in 2017.
    The key innovation is the self-attention mechanism, which allows the model to weigh
    the importance of different words in a sentence. This architecture has become the
    foundation for many modern language models like BERT, GPT, and T5. These models
    have achieved state-of-the-art results on various NLP tasks including text classification,
    question answering, and text generation. The transformer's ability to process sequences
    in parallel makes it much faster than recurrent neural networks. Many companies now
    use transformer-based models in their products for tasks like translation, summarization,
    and chatbots. The success of transformers has also led to research in applying them
    to other domains like computer vision and speech recognition.
    """
    
    data = {
        "text": long_text,
        "max_length": 100,
        "min_length": 30
    }
    
    try:
        start_time = time.time()
        response = requests.post(f"{BASE_URL}/summarize", json=data)
        elapsed = time.time() - start_time
        
        print(f"Status Code: {response.status_code}")
        print(f"Time elapsed: {elapsed:.2f}s")
        
        result = response.json()
        print(f"Original length: {result.get('original_length')}")
        print(f"Summary length: {result.get('summary_length')}")
        print(f"Summary: {result.get('summary')}")
        print(f"Key points: {result.get('key_points')}")
        
        if response.status_code == 200 and result.get('summary'):
            print("✅ Long text test PASSED")
            return True
        else:
            print("❌ Long text test FAILED")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_summarize_batch():
    """Test tóm tắt batch messages"""
    print_test("Summarize Batch Messages")
    
    messages = [
        {"sender": "Alice", "content": "Hey, how are you doing today?"},
        {"sender": "Bob", "content": "I'm doing great! Just finished my project."},
        {"sender": "Alice", "content": "That's awesome! What was it about?"},
        {"sender": "Bob", "content": "It was a web application using React and Node.js."},
        {"sender": "Alice", "content": "Cool! Did you deploy it yet?"},
        {"sender": "Bob", "content": "Yes, I deployed it on Heroku. Works perfectly!"},
        {"sender": "Alice", "content": "Congrats! I'd love to see it sometime."},
        {"sender": "Bob", "content": "Sure, I'll send you the link later."},
    ]
    
    data = {
        "messages": messages,
        "max_length": 100,
        "min_length": 30
    }
    
    try:
        start_time = time.time()
        response = requests.post(f"{BASE_URL}/summarize/batch", json=data)
        elapsed = time.time() - start_time
        
        print(f"Status Code: {response.status_code}")
        print(f"Time elapsed: {elapsed:.2f}s")
        
        result = response.json()
        print(f"Message count: {result.get('message_count')}")
        print(f"Original length: {result.get('original_length')}")
        print(f"Summary length: {result.get('summary_length')}")
        print(f"Summary: {result.get('summary')}")
        print(f"Key points: {result.get('key_points')}")
        
        if response.status_code == 200 and result.get('summary'):
            print("✅ Batch test PASSED")
            return True
        else:
            print("❌ Batch test FAILED")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_vietnamese_text():
    """Test với văn bản tiếng Việt"""
    print_test("Summarize Vietnamese Text")
    
    vn_text = """
    Trí tuệ nhân tạo đang thay đổi cách chúng ta sống và làm việc.
    Các mô hình ngôn ngữ lớn như GPT và BERT đã đạt được nhiều thành tựu
    trong xử lý ngôn ngữ tự nhiên. Chúng có thể hiểu và tạo ra văn bản
    một cách tự nhiên. Nhiều công ty đang ứng dụng AI vào sản phẩm của họ
    để cải thiện trải nghiệm người dùng. Chatbot, dịch máy, tóm tắt văn bản
    là những ứng dụng phổ biến. Tuy nhiên, vẫn còn nhiều thách thức cần giải quyết
    như bias trong dữ liệu, tính minh bạch và đạo đức AI.
    """
    
    data = {
        "text": vn_text,
        "max_length": 100,
        "min_length": 30
    }
    
    try:
        response = requests.post(f"{BASE_URL}/summarize", json=data)
        print(f"Status Code: {response.status_code}")
        
        result = response.json()
        print(f"Summary: {result.get('summary')}")
        print(f"Key points: {result.get('key_points')}")
        
        print("⚠️ Note: Model tiếng Anh có thể không tóm tắt tiếng Việt tốt")
        print("   Cân nhắc chuyển sang VietAI/vit5-base-vietnews-summarization")
        
        if response.status_code == 200:
            print("✅ Vietnamese text test PASSED (but may not be accurate)")
            return True
        else:
            print("❌ Vietnamese text test FAILED")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def run_all_tests():
    """Chạy tất cả tests"""
    print("\n" + "🚀 STARTING ML SERVICE TESTS" + "\n")
    
    results = []
    
    # 1. Health check
    results.append(("Health Check", test_health()))
    
    # Chỉ tiếp tục nếu service healthy
    if not results[0][1]:
        print("\n❌ ML Service không healthy. Dừng tests.")
        print("Hãy chắc chắn service đang chạy: python ml_service.py")
        return
    
    # 2. Short text
    results.append(("Short Text", test_summarize_short_text()))
    
    # 3. Long text
    results.append(("Long Text", test_summarize_long_text()))
    
    # 4. Batch messages
    results.append(("Batch Messages", test_summarize_batch()))
    
    # 5. Vietnamese text
    results.append(("Vietnamese Text", test_vietnamese_text()))
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{name:30s} {status}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED!")
    else:
        print(f"⚠️ {total - passed} test(s) failed")

if __name__ == "__main__":
    run_all_tests()
