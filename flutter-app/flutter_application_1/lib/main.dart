import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/authencation/get_started_screen.dart';
import 'package:flutter_application_1/screens/authencation/Login/signin_screen.dart';
import 'package:flutter_application_1/screens/authencation/Sign_up/signup_info_screen.dart';
import 'package:flutter_application_1/screens/authencation/Sign_up/signup_password_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaroMart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GetStartedScreen(),

      // Các route bình thường (không cần hiệu ứng custom)
      routes: {
        
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
          return _smoothRoute(const SignUpPasswordScreen(), settings);
        }
        return null; // dùng fallback của routes hoặc onUnknownRoute nếu có
      },
    );
  }
}

/// Hiệu ứng Fade + Slide mượt
Route _smoothRoute(Widget page, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
