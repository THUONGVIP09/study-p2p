import 'package:flutter/material.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  // TODO: thay bằng asset thật nếu bạn có
  static const String kLogoAsset = '';        // ví dụ: 'assets/images/logo.png'
  static const String kGoogleAsset = 'lib/images/logogg.png';      // ví dụ: 'assets/images/google.png'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // gradient pastel như ảnh
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
              child: Stack(
                children: [
                  // Nội dung chính – đặt gần đáy màn (giống screenshot)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hàng logo tròn bên trái + nút đóng bên phải
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white.withOpacity(.9),
                                child: _maybeAsset(
                                      kLogoAsset,
                                      const Icon(Icons.local_mall_outlined),
                                    ),
                              ),
                              InkWell(
                                onTap: () => Navigator.maybePop(context),
                                borderRadius: BorderRadius.circular(20),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white.withOpacity(.9),
                                  child: const Icon(Icons.close, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'MaroMart',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'MaroMart, the easy way for people to buy, sell, and connect with each other.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF7A7A7A),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Email
                          _RoundedField(
                            hint: 'Email...',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // Password
                          const _RoundedField(
                            hint: 'Password...',
                            obscure: true,
                          ),
                          const SizedBox(height: 20),

                          // Button Sign in
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {Navigator.pushNamed(context, '/signup'); /* TODO: handle sign in */},
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
                              child: const Text('Sign in'),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Sign in with Google
                          Center(
                            child: TextButton.icon(
                              onPressed: () {/* TODO: sign in with Google */},
                              icon: SizedBox(
                               
                                child: Image.asset(kGoogleAsset, fit: BoxFit.contain,errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported)),),
                              ),
                              label: const Text(
                                'Sign up with google',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hiển thị Image.asset nếu có path; nếu rỗng thì hiện widget thay thế.
  static Widget _maybeAsset(String assetPath, Widget fallback) {
    if (assetPath.isEmpty) return fallback;
    return Image.asset(assetPath, fit: BoxFit.contain);
  }
}

class _RoundedField extends StatefulWidget {
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  const _RoundedField({
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  State<_RoundedField> createState() => _RoundedFieldState();
}

class _RoundedFieldState extends State<_RoundedField> {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: Colors.white.withOpacity(.92),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: _border(),
        focusedBorder: _border(),
        prefixIcon: widget.obscure
            ? const Icon(Icons.lock_outline, size: 20)
            : const Icon(Icons.email_outlined, size: 20),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
              )
            : null,
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
