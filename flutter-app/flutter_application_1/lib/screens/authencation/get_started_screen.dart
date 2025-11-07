import 'package:flutter/material.dart';

/// Copy file này vào lib/ và import nơi bạn muốn dùng:
/// Navigator.push(context, MaterialPageRoute(builder: (_) => const GetStartedScreen()));
///
/// Thay link ảnh ở hằng số [kIllustrationUrl] bên dưới.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  /// TODO: Thay bằng link ảnh minh hoạ của bạn.
  static const String kIllustrationUrl = 'lib/images/get1.png';


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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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

                    // Mô tả
                    Text(
                      'MaroMart, the easy way for people to buy, sell, and connect with each other.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF7A7A7A),
                        height: 1.5,
                      ),
                    ),





                    const SizedBox(height: 12),
                    // Ảnh minh hoạ
                    AspectRatio(
                      aspectRatio: 1, // vuông để cân bố cục; bạn có thể đổi nếu ảnh khác tỉ lệ
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          kIllustrationUrl,
                          fit: BoxFit.contain,
                          // Hiển thị placeholder đơn giản khi đang tải
                         
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported)),
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
