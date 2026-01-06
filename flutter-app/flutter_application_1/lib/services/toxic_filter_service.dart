import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service để gọi AI Filter API kiểm tra tin nhắn thô tục
/// Sử dụng Machine Learning model đã train với TF-IDF + Classifier
class ToxicFilterService {
  static const String _aiServerKey = 'ai_filter_server_ip';
  static const int _defaultPort = 5000;
  
  /// Lấy AI Server IP từ SharedPreferences
  static Future<String> getAiServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiServerKey) ?? 'localhost';
  }
  
  /// Lưu AI Server IP
  static Future<void> setAiServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiServerKey, ip);
  }
  
  /// Tạo base URL cho API
  static Future<String> _getBaseUrl() async {
    final ip = await getAiServerIp();
    return 'http://$ip:$_defaultPort';
  }
  
  /// Kiểm tra một tin nhắn có toxic hay không
  /// 
  /// Returns [ToxicFilterResult] chứa kết quả phân loại
  static Future<ToxicFilterResult> checkMessage(String text) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/api/filter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ToxicFilterResult(
          text: data['text'] ?? text,
          isToxic: data['is_toxic'] ?? false,
          confidence: (data['confidence'] ?? 0.0).toDouble(),
          label: data['label'] ?? 'unknown',
          threshold: (data['threshold'] ?? 0.75).toDouble(),
          isWhitelisted: data['reason'] == 'whitelisted',
          error: null,
        );
      } else {
        return ToxicFilterResult.error(text, 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ToxicFilterService error: $e');
      // Nếu không kết nối được AI server, cho phép gửi (fail-open)
      return ToxicFilterResult.error(text, e.toString());
    }
  }
  
  /// Kiểm tra nhiều tin nhắn cùng lúc
  static Future<List<ToxicFilterResult>> checkBatch(List<String> texts) async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/api/filter/batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'texts': texts}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        return results.map((r) => ToxicFilterResult(
          text: r['text'] ?? '',
          isToxic: r['is_toxic'] ?? false,
          confidence: (r['confidence'] ?? 0.0).toDouble(),
          label: r['label'] ?? 'unknown',
          error: null,
        )).toList();
      } else {
        return texts.map((t) => ToxicFilterResult.error(t, 'Server error')).toList();
      }
    } catch (e) {
      print('❌ ToxicFilterService batch error: $e');
      return texts.map((t) => ToxicFilterResult.error(t, e.toString())).toList();
    }
  }
  
  /// Kiểm tra kết nối đến AI server
  static Future<bool> healthCheck() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['model_loaded'] == true;
      }
      return false;
    } catch (e) {
      print('❌ AI Server health check failed: $e');
      return false;
    }
  }
}

/// Kết quả phân loại từ AI Filter
class ToxicFilterResult {
  final String text;
  final bool isToxic;
  final double confidence;
  final String label;
  final double threshold;
  final bool isWhitelisted;
  final String? error;
  
  ToxicFilterResult({
    required this.text,
    required this.isToxic,
    required this.confidence,
    required this.label,
    this.threshold = 0.75,
    this.isWhitelisted = false,
    this.error,
  });
  
  /// Tạo result khi có lỗi (fail-open - cho phép gửi)
  factory ToxicFilterResult.error(String text, String error) {
    return ToxicFilterResult(
      text: text,
      isToxic: false, // Fail-open: nếu lỗi thì cho qua
      confidence: 0.0,
      label: 'error',
      threshold: 0.75,
      isWhitelisted: false,
      error: error,
    );
  }
  
  /// Kiểm tra có lỗi không
  bool get hasError => error != null;
  
  /// Confidence dạng phần trăm
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
  
  /// Threshold dạng phần trăm
  String get thresholdPercent => '${(threshold * 100).toStringAsFixed(0)}%';
  
  @override
  String toString() {
    if (hasError) {
      return 'ToxicFilterResult(error: $error)';
    }
    if (isWhitelisted) {
      return 'ToxicFilterResult(whitelisted - safe)';
    }
    return 'ToxicFilterResult(isToxic: $isToxic, confidence: $confidencePercent, threshold: $thresholdPercent)';
  }
}
