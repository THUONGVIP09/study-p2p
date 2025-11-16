import 'package:flutter/material.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text(
          'Chats Page Test 16/11/2025',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
