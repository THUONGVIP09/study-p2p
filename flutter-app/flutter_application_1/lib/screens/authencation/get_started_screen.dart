import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import 'server_config_screen.dart';

/// Copy file này vào lib/ và import nơi bạn muốn dùng:
/// Navigator.push(context, MaterialPageRoute(builder: (_) => const GetStartedScreen()));
///
/// Thay link ảnh ở hằng số [kIllustrationUrl] bên dưới.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  /// TODO: Thay bằng link ảnh minh hoạ của bạn.
  static const String kIllustrationUrl = 'assets/images/get1.png';

  Future<String> _getCurrentServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_ip') ?? AppConfig.currentServerIp;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Gradient pastel nhẹ giống screenshot
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 212, 187, 249), // tím cực nhạt
              Color.fromARGB(255, 242, 204, 196), // cam/hồng rất nhạt
              Color.fromARGB(255, 195, 219, 245), // xanh lam nhạt
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Server IP Info Card - Ở TRÊN CÙNG
                    FutureBuilder<String>(
                      future: _getCurrentServerIp(),
                      builder: (context, snapshot) {
                        final serverIp = snapshot.data ?? 'Loading...';
                        return Card(
                          color: Colors.white.withOpacity(0.9),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.dns,
                                        color: Colors.blue.shade700),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Server IP',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            serverIp,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ServerConfigScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Change'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Get started',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.2,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 12),

                    

                    const SizedBox(height: 12),
                    // Ảnh minh hoạ
                    AspectRatio(
                      aspectRatio:
                          1, // vuông để cân bố cục; bạn có thể đổi nếu ảnh khác tỉ lệ
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          kIllustrationUrl,
                          fit: BoxFit.contain,
                          // Hiển thị placeholder đơn giản khi đang tải

                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported)),
                        ),
                      ),
                    ),

                    // const SizedBox(height: 28),

                    // Tiêu đề

                    const SizedBox(height: 36),

                    // Nút "Create account" – màu đen, bo tròn lớn
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                          // TODO: điều hướng sang trang đăng ký
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(double.infinity, 56),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text('Create account'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // "Sign in" dạng text phía dưới
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signin');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      child: const Text('Sign in'),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
