import 'package:flutter/material.dart';

class TabControllerPage extends StatefulWidget {
  @override
  _TabControllerPageState createState() => _TabControllerPageState();
}

class _TabControllerPageState extends State<TabControllerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
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
        title: Text("Tab Controller Page"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'First Page'),
            Tab(text: 'Second Page'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Center(child: Text('Content of First Page')),
          Center(child: Text('Content of Second Page')),
        ],
      ),
    );
  }
}
