import 'dart:io';

/// Helper để lấy IP address thật của máy trong LAN
class NetworkHelper {
  /// Lấy IP address thật của máy (không phải 127.0.0.1)
  /// Ưu tiên: WiFi > Ethernet > Localhost
  static Future<String> getLocalIpAddress() async {
    try {
      // Lấy tất cả network interfaces
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false, // Bỏ qua 127.0.0.1
      );

      print('🔍 Available network interfaces:');
      for (var interface in interfaces) {
        print(
            '   ${interface.name}: ${interface.addresses.map((a) => a.address).join(", ")}');
      }

      // Ưu tiên WiFi
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('wlan')) {
          if (interface.addresses.isNotEmpty) {
            final ip = interface.addresses.first.address;
            print('✅ Using WiFi IP: $ip');
            return ip;
          }
        }
      }

      // Fallback: Ethernet
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('ethernet') || name.contains('eth')) {
          if (interface.addresses.isNotEmpty) {
            final ip = interface.addresses.first.address;
            print('✅ Using Ethernet IP: $ip');
            return ip;
          }
        }
      }

      // Fallback: Bất kỳ interface nào có IP không phải localhost
      for (var interface in interfaces) {
        if (interface.addresses.isNotEmpty) {
          final ip = interface.addresses.first.address;
          if (ip != '127.0.0.1' && !ip.startsWith('169.254.')) {
            // Bỏ qua APIPA addresses
            print('✅ Using first available IP: $ip');
            return ip;
          }
        }
      }

      // Cuối cùng: Dùng localhost nếu không tìm được gì
      print('⚠️ No network interface found, using localhost');
      return '127.0.0.1';
    } catch (e) {
      print('❌ Error getting local IP: $e');
      return '127.0.0.1';
    }
  }

  /// Kiểm tra xem có đang chạy trên cùng máy không
  static bool isSameMachine(String ip) {
    return ip == '127.0.0.1' || ip == 'localhost';
  }

  /// Kiểm tra xem có trong cùng subnet không (LAN)
  static bool isInSameSubnet(String ip1, String ip2) {
    if (isSameMachine(ip1) || isSameMachine(ip2)) return true;

    try {
      final parts1 = ip1.split('.');
      final parts2 = ip2.split('.');

      if (parts1.length != 4 || parts2.length != 4) return false;

      // So sánh 3 octet đầu (subnet /24)
      return parts1[0] == parts2[0] &&
          parts1[1] == parts2[1] &&
          parts1[2] == parts2[2];
    } catch (e) {
      return false;
    }
  }

  /// Format IP address cho display
  static String formatIp(String ip, int port) {
    return '$ip:$port';
  }
}
