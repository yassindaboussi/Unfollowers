import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database/db_helper.dart';
import 'model/user.dart';
import 'screens/DontFollow.dart';
import 'screens/PendingRequest.dart';

class HomePage extends StatefulWidget {

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    print("initState");
    _tabController = TabController(length: 2, vsync: this);
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
          toolbarHeight: 50,  // Reduced toolbar height
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(10),  // Adjust the preferred size
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Pending Request'),
                Tab(text: 'Dont follow you back'),
              ],
            ),
          ),
        ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PendingRequestPage(usersFromFile: null),
          DontFollowPage(),
        ],
      ),
    );
  }


}
