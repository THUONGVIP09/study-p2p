import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart'; // Giữ import

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  static const String kLogoAsset = ''; // ví dụ: 'assets/images/logo.png'

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.white.withOpacity(.9),
                                  child: _maybeAsset(
                                    SignInScreen.kLogoAsset,
                                    const Icon(Icons.local_mall_outlined),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => Navigator.maybePop(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        Colors.white.withOpacity(.9),
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
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'MaroMart, the easy way for people to buy, sell, and connect with each other.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF7A7A7A), height: 1.5),
                            ),
                            const SizedBox(height: 18),
                            _RoundedField(
                              hint: 'Email...',
                              keyboardType: TextInputType.emailAddress,
                              controller: _emailController,
                              validator: (v) {
                                final val = v?.trim() ?? '';
                                if (val.isEmpty) return 'Không để trống email';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(val))
                                  return 'Email sai định dạng';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _RoundedField(
                              hint: 'Password...',
                              obscure: true,
                              controller: _passwordController,
                              validator: (v) {
                                final val = v?.trim() ?? '';
                                if (val.isEmpty)
                                  return 'Không để trống password';
                                if (val.length < 6) return 'Ít nhất 6 ký tự';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        if (_formKey.currentState!.validate()) {
                                          setState(() => _isLoading = true);
                                          try {
                                            final result =
                                                await ApiService.login(
                                              email:
                                                  _emailController.text.trim(),
                                              password: _passwordController.text
                                                  .trim(),
                                            );
                                            Navigator.pushReplacementNamed(
                                                context, '/home');
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Đăng nhập OK: ${result['user']['name']}'),
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text('Lỗi: $e')),
                                            );
                                          } finally {
                                            setState(() => _isLoading = false);
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                  minimumSize: const Size(double.infinity, 56),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Sign in'),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Phần Google Sign up đã bị loại bỏ
                          ],
                        ),
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

  static Widget _maybeAsset(String assetPath, Widget fallback) {
    if (assetPath.isEmpty) return fallback;
    return Image.asset(assetPath, fit: BoxFit.contain);
  }
}

class _RoundedField extends StatefulWidget {
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const _RoundedField({
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.controller,
    this.validator,
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
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: Colors.white.withOpacity(.92),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: _border(),
        focusedBorder: _border(),
        errorBorder:
            _border().copyWith(borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder:
            _border().copyWith(borderSide: const BorderSide(color: Colors.red)),
        prefixIcon: widget.obscure
            ? const Icon(Icons.lock_outline, size: 20)
            : const Icon(Icons.email_outlined, size: 20),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    size: 18),
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
