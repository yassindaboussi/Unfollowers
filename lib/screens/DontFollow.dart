import 'package:flutter/material.dart';

class DontFollowPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: Text(
          "Total : 0",
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.history,
              size: 30.0,
            ),
            onPressed: () {
              // Add functionality for this action
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          "Don't follow you back",
          style: TextStyle(fontSize: 24.0),
        ),
      ),
    );
  }
}
