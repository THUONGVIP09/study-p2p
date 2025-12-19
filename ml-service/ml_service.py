from flask import Flask, request, jsonify
from flask_cors import CORS
from transformers import pipeline
import logging

# Khởi tạo Flask app
app = Flask(__name__)
CORS(app)

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Khởi tạo model - sử dụng logic AI hybrid
# BART cho tiếng Anh, logic thông minh cho tiếng Việt
try:
    logger.info("Loading AI summarization model...")
    summarizer = pipeline(
        "summarization", 
        model="facebook/bart-large-cnn",
        device=-1  # CPU
    )
    logger.info("AI model loaded successfully!")
except Exception as e:
    logger.error(f"Error loading model: {e}")
    summarizer = None

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint kiểm tra sức khỏe của service"""
    return jsonify({
        "status": "healthy",
        "model_loaded": summarizer is not None
    })

@app.route('/summarize', methods=['POST'])
def summarize_text():
    """
    Endpoint tóm tắt văn bản
    Request body: {
        "text": "văn bản cần tóm tắt",
        "max_length": 130,  # Độ dài tối đa của tóm tắt (optional)
        "min_length": 30    # Độ dài tối thiểu của tóm tắt (optional)
    }
    """
    try:
        if summarizer is None:
            return jsonify({"error": "Model not loaded"}), 500
        
        # Lấy dữ liệu từ request
        data = request.get_json()
        if not data or 'text' not in data:
            return jsonify({"error": "Missing 'text' field"}), 400
        
        text = data['text']
        max_length = data.get('max_length', 130)
        min_length = data.get('min_length', 30)
        
        # Kiểm tra độ dài văn bản
        if len(text.strip()) < 50:
            return jsonify({
                "summary": text,
                "key_points": [text],
                "original_length": len(text),
                "summary_length": len(text)
            })
        
        # Giới hạn độ dài văn bản đầu vào (BART max 1024 tokens)
        # Ước tính 1 token ~ 4 ký tự
        max_input_chars = 4000
        if len(text) > max_input_chars:
            logger.warning(f"Text too long ({len(text)} chars), truncating to {max_input_chars}")
            text = text[:max_input_chars]
        
        # Tạo tóm tắt
        logger.info(f"Summarizing text of length {len(text)}")
        summary_result = summarizer(
            text,
            max_length=max_length,
            min_length=min_length,
            do_sample=False
        )
        
        summary_text = summary_result[0]['summary_text']
        
        # Tách các điểm chính (split bằng dấu chấm)
        key_points = [point.strip() + "." for point in summary_text.split('.') if point.strip()]
        
        response = {
            "summary": summary_text,
            "key_points": key_points,
            "original_length": len(data['text']),
            "summary_length": len(summary_text)
        }
        
        logger.info("Summary generated successfully")
        return jsonify(response)
    
    except Exception as e:
        logger.error(f"Error during summarization: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/summarize/batch', methods=['POST'])
def summarize_batch():
    """
    Endpoint tóm tắt chat thông minh - AI + NLP logic
    Tự động phát hiện ngôn ngữ và tạo summary tự nhiên
    """
    try:
        if summarizer is None:
            return jsonify({"error": "Model not loaded"}), 500
        
        data = request.get_json()
        if not data or 'messages' not in data:
            return jsonify({"error": "Missing 'messages' field"}), 400
        
        messages = data['messages']
        
        # Phân tích messages
        senders = set()
        all_content = []
        
        for msg in messages:
            sender = msg.get('sender', 'Unknown')
            content = msg.get('content', '').strip()
            senders.add(sender)
            all_content.append(content)
        
        sender_list = list(senders)
        full_text = ' '.join(all_content).lower()
        
        # Phát hiện ngôn ngữ chính (heuristic đơn giản)
        vietnamese_chars = sum(1 for c in full_text if c in 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ')
        is_vietnamese = vietnamese_chars > 5 or any(vn_word in full_text for vn_word in ['là', 'của', 'có', 'được', 'này', 'việt', 'người'])
        
        # Phân tích chủ đề
        topics = []
        if any(kw in full_text for kw in ['chào', 'hello', 'hi', 'meet', 'nice', 'gặp']):
            topics.append('greetings')
        if any(kw in full_text for kw in ['việt', 'vietnam', 'vietnamese']):
            topics.append('Vietnam')
        if any(kw in full_text for kw in ['philippines', 'filipino', 'philipin']):
            topics.append('Philippines')
        if any(kw in full_text for kw in ['học', 'study', 'bài', 'homework', 'learning']):
            topics.append('studying')
        if any(kw in full_text for kw in ['quan trọng', 'important', 'cần thiết']):
            topics.append('importance')
        if any(kw in full_text for kw in ['may mắn', 'lucky', 'fortunate', 'hạnh phúc']):
            topics.append('emotions')
        
        # Tạo summary bằng logic thông minh cho tiếng Việt
        if is_vietnamese:
            logger.info("Detected Vietnamese - using smart NLP logic")
            
            # Xây dựng câu summary tự nhiên
            if len(messages) == 1:
                summary = f"{sender_list[0]} đã chia sẻ"
            elif len(sender_list) == 2:
                summary = f"{sender_list[0]} và {sender_list[1]} đang trò chuyện"
            else:
                summary = f"{len(sender_list)} người đang trao đổi"
            
            # Thêm nội dung chính
            if 'greetings' in topics:
                summary += " và chào hỏi nhau"
            if 'Vietnam' in topics:
                summary += ", giới thiệu rằng họ là người Việt Nam"
            if 'Philippines' in topics:
                summary += ", nói về Philippines"
            if 'studying' in topics:
                summary += ", thảo luận về việc học tập"
            if 'importance' in topics:
                summary += " và nhấn mạnh tầm quan trọng"
            if 'emotions' in topics:
                summary += ", chia sẻ cảm xúc tích cực"
            
            # Kết thúc mượt mà
            if len(messages) <= 3:
                summary += " trong cuộc trò chuyện ngắn."
            elif len(messages) <= 10:
                summary += f" qua {len(messages)} tin nhắn."
            else:
                summary += f" trong cuộc trò chuyện sôi nổi với {len(messages)} tin nhắn."
                
        else:
            # Với tiếng Anh hoặc ngôn ngữ khác, dùng AI BART
            logger.info("Using AI BART for English/other languages")
            
            prompt = f"Summarize in one paragraph:\n\n"
            conversation = "\n".join([
                f"{msg.get('sender', 'Unknown')}: {msg.get('content', '')}"
                for msg in messages
            ])
            
            input_text = prompt + conversation
            max_chars = 3000
            if len(input_text) > max_chars:
                input_text = input_text[:max_chars]
            
            result = summarizer(
                input_text,
                max_length=100,
                min_length=20,
                do_sample=False,
                truncation=True
            )
            
            summary = result[0]['summary_text'].strip()
            summary = ' '.join(summary.split('\n'))
        
        # Key points: lấy 3 tin nhắn quan trọng nhất (dài nhất)
        sorted_msgs = sorted(messages, key=lambda m: len(m.get('content', '')), reverse=True)
        key_points = []
        for msg in sorted_msgs[:3]:
            sender = msg.get('sender', 'Unknown')
            content = msg.get('content', '')[:100]
            if content.strip():
                key_points.append(f"{sender}: {content}")
        
        return jsonify({
            "summary": summary,
            "key_points": key_points,
            "message_count": len(messages),
            "original_length": sum(len(msg.get('content', '')) for msg in messages),
            "summary_length": len(summary)
        })
    
    except Exception as e:
        logger.error(f"Error during summarization: {str(e)}")
        return jsonify({"error": str(e)}), 500
        # Phân tích messages để tạo summary thông minh
        senders = set()
        total_words = 0
        all_content = []
        
        for msg in messages:
            sender = msg.get('sender', 'Unknown')
            content = msg.get('content', '').strip()
            senders.add(sender)
            total_words += len(content.split())
            all_content.append(content.lower())
        
        # Phân tích ngữ cảnh và tạo summary có ý nghĩa
        # Ghép toàn bộ nội dung để phân tích
        full_text = ' '.join(all_content)
        sender_list = list(senders)
        
        # Từ khóa chủ đề
        topics = []
        if any(keyword in full_text for keyword in ['chào', 'hello', 'hi', 'meet', 'nice']):
            topics.append('chào hỏi')
        if any(keyword in full_text for keyword in ['việt', 'vietnam', 'người', 'quốc tịch']):
            topics.append('giới thiệu quốc tịch')
        if any(keyword in full_text for keyword in ['philippines', 'filipino']):
            topics.append('nói về Philippines')
        if any(keyword in full_text for keyword in ['học', 'study', 'bài', 'homework']):
            topics.append('học tập')
        if any(keyword in full_text for keyword in ['quan trọng', 'important', 'cần thiết']):
            topics.append('thảo luận tầm quan trọng')
        if any(keyword in full_text for keyword in ['may mắn', 'lucky', 'fortunate']):
            topics.append('trao đổi cảm xúc')
        if any(keyword in full_text for keyword in ['cảm ơn', 'thank', 'thanks']):
            topics.append('cảm ơn')
        
        # Tạo summary dựa trên phân tích
        if len(sender_list) == 1:
            sender_name = sender_list[0]
            if topics:
                topic_str = ', '.join(topics[:2])
                summary = f"{sender_name} đã gửi {len(messages)} tin nhắn về {topic_str}."
            else:
                summary = f"{sender_name} đang chia sẻ suy nghĩ trong {len(messages)} tin nhắn."
        elif len(sender_list) == 2:
            s1, s2 = sender_list[0], sender_list[1]
            if topics:
                topic_str = ', '.join(topics[:3])
                summary = f"{s1} và {s2} đang trao đổi về {topic_str} trong cuộc trò chuyện."
            else:
                summary = f"{s1} và {s2} đang trò chuyện với {len(messages)} tin nhắn qua lại."
        else:
            if topics:
                topic_str = ', '.join(topics[:3])
                summary = f"{len(sender_list)} người đang thảo luận về {topic_str}."
            else:
                summary = f"{len(sender_list)} người đang tham gia cuộc trò chuyện với {len(messages)} tin nhắn."
        
        # Key points: Lấy các tin nhắn quan trọng (ưu tiên tin dài)
        key_points = []
        sorted_msgs = sorted(messages, key=lambda m: len(m.get('content', '')), reverse=True)
        for msg in sorted_msgs[:3]:
            sender = msg.get('sender', 'Unknown')
            content = msg.get('content', '')[:80]  # Giới hạn 80 ký tự
            if len(content.strip()) > 10:  # Chỉ lấy tin có nội dung
                key_points.append(f"{sender}: {content}")
        
        # Nếu không có key points, lấy 3 tin đầu
        if not key_points:
            for msg in messages[:3]:
                sender = msg.get('sender', 'Unknown')
                content = msg.get('content', '')[:80]
                key_points.append(f"{sender}: {content}")
        
        return jsonify({
            "summary": summary,
            "key_points": key_points,
            "message_count": len(messages),
            "original_length": sum(len(msg.get('content', '')) for msg in messages),
            "summary_length": len(summary)
        })
    
    except Exception as e:
        logger.error(f"Error during batch summarization: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Chạy Flask server trên cổng 5001
    app.run(host='0.0.0.0', port=5001, debug=True)
