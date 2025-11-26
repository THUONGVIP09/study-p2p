import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import 'server_config_screen.dart';
import 'get_started_screen.dart';

/// Screen kiểm tra config lần đầu tiên
/// - Nếu chưa config IP → hiện ServerConfigScreen
/// - Nếu đã config → auto load và vào GetStartedScreen
class InitialConfigScreen extends StatefulWidget {
  const InitialConfigScreen({Key? key}) : super(key: key);

  @override
  State<InitialConfigScreen> createState() => _InitialConfigScreenState();
}

class _InitialConfigScreenState extends State<InitialConfigScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndLoadConfig();
  }

  Future<void> _checkAndLoadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('server_ip');

      if (savedIp != null && savedIp.isNotEmpty) {
        // Đã có config → load và vào GetStartedScreen
        print('📱 [InitialConfig] Found saved IP: $savedIp');
        AppConfig.setServerIp(savedIp);

        if (!mounted) return;

        // Delay nhỏ để user thấy splash
        await Future.delayed(const Duration(milliseconds: 500));

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GetStartedScreen()),
        );
      } else {
        // Chưa config → bắt buộc config
        print('📱 [InitialConfig] No saved IP → showing ServerConfigScreen');

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ServerConfigScreen(isFirstTime: true),
          ),
        );
      }
    } catch (e) {
      print('❌ [InitialConfig] Error: $e');
      // Nếu lỗi → vào ServerConfigScreen để config
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ServerConfigScreen(isFirstTime: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 212, 187, 249),
              Color.fromARGB(255, 242, 204, 196),
              Color.fromARGB(255, 195, 219, 245),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 50,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 32),

              // App Name
              const Text(
                'Study P2P',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Loading indicator
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
              const SizedBox(height: 16),

              // Status text
              Text(
                'Checking configuration...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
