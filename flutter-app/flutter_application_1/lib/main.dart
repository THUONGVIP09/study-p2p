import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_application_1/screens/authencation/initial_config_screen.dart';
import 'package:flutter_application_1/screens/authencation/get_started_screen.dart';
import 'package:flutter_application_1/screens/authencation/Login/signin_screen.dart';
import 'package:flutter_application_1/screens/authencation/Sign_up/signup_info_screen.dart';
import 'package:flutter_application_1/screens/authencation/Sign_up/signup_password_screen.dart';
import 'package:flutter_application_1/services/network_helper.dart';
import 'package:flutter_application_1/services/p2p_websocket_server.dart';
import 'home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Khởi tạo P2P WebSocket server NGAY từ đầu (chỉ trên mobile/desktop)
  // Web không hỗ trợ ServerSocket.bind nên bỏ qua
  // Server này chạy ở background, sẵn sàng nhận tin từ peers
  try {
    // Check nếu không phải web platform
    if (!_isWebPlatform()) {
      final localIp = await NetworkHelper.getLocalIpAddress();
      print('🚀 [MAIN] Starting P2P WebSocket server...');
      await P2PWebSocketServer.getInstance().initialize(localIp: localIp);
      print('✅ [MAIN] P2P WebSocket server ready');
    } else {
      print('ℹ️ [MAIN] Skipping P2P server on web platform');
    }
  } catch (e) {
    print('⚠️ [MAIN] Failed to start P2P server: $e');
  }

  runApp(const MyApp());
}

/// Check nếu đang chạy web
bool _isWebPlatform() {
  try {
    return !Platform.isAndroid && !Platform.isIOS && !Platform.isWindows && !Platform.isLinux && !Platform.isMacOS;
  } catch (e) {
    // Nếu không thể kiểm tra (web platform) -> return true
    return true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study P2P',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const InitialConfigScreen(), // Check config lần đầu

      // Các route bình thường (không cần hiệu ứng custom)
      routes: {
        '/home': (context) =>
            const HomeShell(), // THÊM tạm - sau thay room_list
      },

      // Route có hiệu ứng chuyển mượt
      onGenerateRoute: (settings) {
        if (settings.name == '/signin') {
          return _smoothRoute(const SignInScreen(), settings);
        }
        if (settings.name == '/signup') {
          return _smoothRoute(const SignUpInfoScreen(), settings);
        }
        if (settings.name == '/signup/password') {
          final args = settings.arguments
              as Map<String, String>?; // Để pass data nếu cần
          return _smoothRoute(
            SignUpPasswordScreen(
              email: args?['email'] ?? '',
              displayName: args?['displayName'] ?? '',
            ),
            settings,
          );
        }
        return null; // dùng fallback của routes hoặc onUnknownRoute nếu có
      },
    );
  }
}

// Hiệu ứng Fade + Slide mượt
Route _smoothRoute(Widget page, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

// Tạm cho /home - sau thay bằng room_list_screen.dart
