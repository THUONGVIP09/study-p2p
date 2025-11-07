import 'dart:ui';
import 'package:flutter/material.dart';

class SignUpInfoScreen extends StatelessWidget {
  const SignUpInfoScreen({super.key});

  // TODO: Thay đường dẫn ảnh nền theo project của bạn
  static const String kBackgroundAsset = 'lib/images/signup1.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh nền full màn hình
          Image.asset(
            kBackgroundAsset,
            fit: BoxFit.cover,
          ),

          // Lớp làm mờ nhẹ cho dễ đọc chữ
          Container(
            color: Colors.black.withOpacity(0.35),
          ),

          // Nội dung chính
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: size.width > 480 ? 420 : size.width * 0.9,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo + Close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white.withOpacity(0.9),
                              child: const Icon(Icons.rocket_launch_outlined,
                                  color: Colors.black),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(20),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white.withOpacity(0.9),
                                child:
                                    const Icon(Icons.close, color: Colors.black, size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'MaroMart',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MaroMart, the easy way for people to buy, sell, and connect with each other.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Các ô nhập thông tin
                        const _RoundedField(hint: 'Fullname...'),
                        const SizedBox(height: 14),
                        const _RoundedField(hint: 'Email...', keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        const _RoundedField(hint: 'Phone...', keyboardType: TextInputType.phone),
                        const SizedBox(height: 14),
                        const _RoundedField(hint: 'Gender...'),
                        const SizedBox(height: 24),

                        // Nút Next
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup/password');
                              /* TODO: next step */
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
                            child: const Text('Next →'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//---------------------------------------------
// Widget TextField bo tròn, màu trắng mờ
//---------------------------------------------
class _RoundedField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  const _RoundedField({
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.25),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: _border(),
        focusedBorder: _border(),
      ),
    );
  }

  OutlineInputBorder _border() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    );
  }
}
