import 'package:flutter/material.dart';
import 'package:unfollowers/screens/DontFollow.dart';
import 'package:unfollowers/screens/PendingRequest.dart';
import 'package:unfollowers/screens/ProfilePage.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 50,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(10),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Pending Request'),
              Tab(text: 'Don\'t Follow Back'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ProfilePage(),
          PendingRequestPage(usersFromFile: null),
          DontFollowPage(),
        ],
      ),
    );
  }
}