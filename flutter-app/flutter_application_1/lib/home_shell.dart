import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/rooms/rooms_page.dart';
import 'package:flutter_application_1/screens/friends/friends_screen.dart';
import 'call_page.dart';
import 'package:flutter_application_1/screens/tasks/tasks_list.dart';
import 'package:flutter_application_1/screens/chat/conversations_screen.dart';
import 'package:flutter_application_1/widgets/server_ip_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  // Danh sách tab (icon gần giống ảnh)
  final tabs = <_TabItem>[
    _TabItem(icon: Icons.videocam_off_rounded, label: 'Call'),
    _TabItem(icon: Icons.description_rounded, label: 'Notes'),
    _TabItem(icon: Icons.group_rounded, label: 'Members'),
    _TabItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
  ];

  // Ba nút mờ phía dưới (chưa active)
  final trailing = const [
    _UserAvatarMenu(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => index = i),
                labelType: NavigationRailLabelType.none,
                minWidth: 72,
                backgroundColor: const Color(0xFF1E1B1D), // nền tối giống ảnh
                selectedIconTheme:
                    const IconThemeData(color: Color(0xFFE68AF7)),
                unselectedIconTheme: const IconThemeData(color: Colors.white),

                leading: const SizedBox(height: 8),
                destinations: [
                  for (final t in tabs)
                    NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.icon),
                      label: Text(t.label),
                    ),
                ],

                // nhóm các icon mờ ở đáy
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 16),
                    for (final w in trailing)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: w,
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Khu vực nội dung trắng (placeholder)
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: [
                    const RoomsPage(),
                    const TasksListScreen(), // Notes -> Tasks
                    const FriendsScreen(), // Members
                    const ConversationsScreen(), // Conversations (Messages)
                  ],
                ),
              ),
            ],
          ),

          // Server IP indicator at bottom right
          const ServerIpIndicator(),
        ],
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

class _DisabledIcon extends StatelessWidget {
  final IconData icon;
  const _DisabledIcon({super.key, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Colors.white38, size: 26);
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _UserAvatarMenu extends StatefulWidget {
  const _UserAvatarMenu({super.key});

  @override
  State<_UserAvatarMenu> createState() => _UserAvatarMenuState();
}

class _UserAvatarMenuState extends State<_UserAvatarMenu> {
  String? _userName;
  String? _userEmail;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('userId');
      _userEmail = prefs.getString('userEmail');
      _userName = prefs.getString('userName');
    });
  }

  Future<void> _saveProfile(String? name, String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('userName', name);
    if (email != null) await prefs.setString('userEmail', email);
    await _loadUser();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thông tin người dùng')),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nameToDisplay = _userName ?? 'User';
    final initials = nameToDisplay.isNotEmpty
        ? nameToDisplay
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return InkWell(
      onTap: () => _openMenu(context),
      borderRadius: BorderRadius.circular(20),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white24,
        child: Text(initials, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _openMenu(BuildContext context) {
    final nameCtrl = TextEditingController(text: _userName ?? '');
    final emailCtrl = TextEditingController(text: _userEmail ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle, size: 28),
                  const SizedBox(width: 8),
                  const Text('Tài khoản',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_userId != null)
                    Text('#${_userId}',
                        style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên hiển thị'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _saveProfile(
                        nameCtrl.text.trim().isEmpty
                            ? null
                            : nameCtrl.text.trim(),
                        emailCtrl.text.trim().isEmpty
                            ? null
                            : emailCtrl.text.trim(),
                      );
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _logout();
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
