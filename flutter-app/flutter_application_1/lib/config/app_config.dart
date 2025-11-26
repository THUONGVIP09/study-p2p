/// Cấu hình server và network cho app
class AppConfig {
  // ==================== SERVER CONFIGURATION ====================

  /// Server IP - CÓ THỂ THAY ĐỔI RUNTIME QUA UI
  ///
  /// Default: '127.0.0.1' (localhost)
  /// Có thể thay đổi qua ChatConnectionSetupScreen
  static String _serverIp = '127.0.0.1'; // ← Default value

  /// Get current server IP
  static String get currentServerIp => _serverIp;

  /// Set server IP dynamically (called from UI)
  static void setServerIp(String ip) {
    _serverIp = ip;
    print('✅ AppConfig: Server IP updated to $_serverIp');
  }

  /// Reset to localhost
  static void resetToLocalhost() {
    _serverIp = '127.0.0.1';
  }

  /// HTTP API port
  static const int httpPort = 8080;

  /// WebSocket port
  static const int websocketPort = 8082;

  // ==================== DERIVED URLs ====================

  /// Base URL cho HTTP API
  static String get httpBaseUrl => 'http://$_serverIp:$httpPort';

  /// Base URL cho WebSocket
  static String get websocketBaseUrl => 'ws://$_serverIp:$websocketPort';

  /// WebSocket URL cho chat relay
  static String chatRelayUrl(int userId) =>
      '$websocketBaseUrl/chat-relay/$userId';

  /// WebSocket URL cho online list
  static String get onlineListUrl => '$websocketBaseUrl/chat-online-list';

  // ==================== P2P CONFIGURATION ====================

  /// Timeout cho P2P connection
  static const Duration p2pConnectTimeout = Duration(seconds: 3);

  /// Heartbeat interval
  static const Duration heartbeatInterval = Duration(seconds: 30);

  // ==================== HELPER METHODS ====================

  /// Kiểm tra xem có đang chạy localhost mode không
  static bool get isLocalhostMode =>
      _serverIp == '127.0.0.1' || _serverIp == 'localhost';

  /// In ra config hiện tại
  static void printConfig() {
    print('');
    print('📡 ========== APP CONFIGURATION ==========');
    print('   Server IP: $_serverIp');
    print('   HTTP URL:  $httpBaseUrl');
    print('   WS URL:    $websocketBaseUrl');
    print(
        '   Mode:      ${isLocalhostMode ? "LOCALHOST (same machine)" : "LAN (multi-machine)"}');
    print('==========================================');
    print('');
  }
}
