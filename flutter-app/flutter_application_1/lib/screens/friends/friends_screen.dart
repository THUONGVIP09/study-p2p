import 'package:flutter/material.dart';
import 'friends_tab.dart';
import 'friend_requests_tab.dart';
import 'blocked_users_tab.dart';
import 'find_friends_tab.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> _tabs = const [
    Tab(text: 'Friends'),
    Tab(text: 'Friend Requests'),
    Tab(text: 'Blocked Users'),
    Tab(text: 'Find Friends'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Friends',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // TAB BAR
            TabBar(
              controller: _tabController,
              tabs: _tabs,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              isScrollable: false,
            ),

            // CONTENT
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  FriendsTab(),
                  FriendRequestsTab(),
                  BlockedUsersTab(),
                  FindFriendsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
