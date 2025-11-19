import 'package:flutter/material.dart';
import 'call_page.dart';


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
    _TabItem(icon: Icons.brush_rounded,        label: 'Whiteboard'),
    _TabItem(icon: Icons.event_rounded,        label: 'Calendar'),
    _TabItem(icon: Icons.description_rounded,  label: 'Notes'),
    _TabItem(icon: Icons.group_rounded,        label: 'Members'),
    _TabItem(icon: Icons.chat_bubble_rounded,  label: 'Chat'),
    _TabItem(icon: Icons.format_color_fill,    label: 'Tools'),
    _TabItem(icon: Icons.flag_rounded,         label: 'Flags'),
  ];

  // Ba nút mờ phía dưới (chưa active)
  final trailing = const [
    _DisabledIcon(icon: Icons.music_note_rounded),
    _DisabledIcon(icon: Icons.notifications_rounded),
    _DisabledIcon(icon: Icons.account_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            labelType: NavigationRailLabelType.none,
            minWidth: 72,
            backgroundColor: const Color(0xFF1E1B1D), // nền tối giống ảnh
            selectedIconTheme: const IconThemeData(color: Color(0xFFE68AF7)),
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
                for (final w in trailing) Padding(
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
      const CallPage(),        
      const _PlaceholderPage('Whiteboard'),      // Tab 1
      const _PlaceholderPage('Calendar'),        // Tab 2
      const _PlaceholderPage('Notes'),           // Tab 3
      const _PlaceholderPage('Members'),         // Tab 4
      const _PlaceholderPage('Chat'),            // Tab 5
      const _PlaceholderPage('Tools'),           // Tab 6
      const _PlaceholderPage('Flags'),                    // <-- Tab 0: Call = RoomsPage
                // Tab 7
    ],
  ),
),

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
        child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
