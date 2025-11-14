import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

class SignUpPasswordScreen extends StatefulWidget {
  final String email;
  final String displayName;
  const SignUpPasswordScreen(
      {super.key, required this.email, required this.displayName});

  static const String kBackgroundAsset = 'lib/images/signup1.png';

  @override
  State<SignUpPasswordScreen> createState() => _SignUpPasswordScreenState();
}

class _SignUpPasswordScreenState extends State<SignUpPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _isLoading = false;
  bool _ob1 = true;
  bool _ob2 = true;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ApiService.register(
          email: widget.email,
          password: _pw.text.trim(),
          displayName: widget.displayName,
        );
        Navigator.pushReplacementNamed(context, '/signin');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đăng ký OK!')));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(SignUpPasswordScreen.kBackgroundAsset, fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
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
                          color: Colors.white.withOpacity(0.25), width: 1.5),
                    ),
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
                                backgroundColor: Colors.white.withOpacity(0.9),
                                child: const Icon(Icons.rocket_launch_outlined,
                                    color: Colors.black),
                              ),
                              InkWell(
                                onTap: () => Navigator.maybePop(context),
                                borderRadius: BorderRadius.circular(20),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.9),
                                  child: const Icon(Icons.close,
                                      color: Colors.black, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'MaroMart',
                            style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'MaroMart, the easy way for people to buy, sell, and connect with each other.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.85),
                                height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          _GlassField(
                            controller: _pw,
                            hint: 'Password...',
                            obscure: _ob1,
                            prefix: const Icon(Icons.lock_outline,
                                size: 20, color: Colors.white),
                            suffix: IconButton(
                              onPressed: () => setState(() => _ob1 = !_ob1),
                              icon: Icon(
                                  _ob1
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18,
                                  color: Colors.white),
                            ),
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty) return 'Không để trống password';
                              if (val.length < 6) return 'Ít nhất 6 ký tự';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _GlassField(
                            controller: _pw2,
                            hint: 'Re-type password...',
                            obscure: _ob2,
                            prefix: const Icon(Icons.lock_reset,
                                size: 20, color: Colors.white),
                            suffix: IconButton(
                              onPressed: () => setState(() => _ob2 = !_ob2),
                              icon: Icon(
                                  _ob2
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18,
                                  color: Colors.white),
                            ),
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty) return 'Không để trống re-type';
                              if (val != _pw.text.trim())
                                return 'Password không khớp';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: const StadiumBorder(),
                                minimumSize: const Size(double.infinity, 56),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Create'),
                            ),
                          ),
                        ],
                      ),
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

class _GlassField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final Widget? prefix;
  final Widget? suffix;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.hint,
    this.obscure = false,
    this.prefix,
    this.suffix,
    this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.25),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: _border(),
        focusedBorder: _border(),
        errorBorder:
            _border().copyWith(borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder:
            _border().copyWith(borderSide: const BorderSide(color: Colors.red)),
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
                child: prefix),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
      ),
    );
  }

  OutlineInputBorder _border() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none);
}
