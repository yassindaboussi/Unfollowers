import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../model/historique.dart';
import '../model/user.dart';

typedef RefreshCallback = void Function();

class HistoriquePage extends StatefulWidget {
  final RefreshCallback refreshCallback;

  HistoriquePage({required this.refreshCallback});

  @override
  _HistoriquePageState createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  DatabaseHelper dbHelper = DatabaseHelper();
  List<HistoriqueItem> historiqueItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistoriqueItems();
  }

  Future<void> _loadHistoriqueItems() async {
    await dbHelper.initializeDatabase();
    List<HistoriqueItem> items = await dbHelper.getHistoriqueItems();
    setState(() {
      historiqueItems = items;
    });
  }

  Future<void> _restoreItem(HistoriqueItem item) async {
    User user = User(
      username: item.username,
      link: item.link,
      date: item.date,
      isFavorite: item.isFavorite,
    );

    if (item.type == 'pending') {
      await dbHelper.insertPendingUsers([user]);
    } else if (item.type == 'nonfollower') {
      await dbHelper.insertNonFollowers([user]);
    }

    await dbHelper.deleteHistoriqueItem(item.id);
    widget.refreshCallback();
    await _loadHistoriqueItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: ListView.builder(
        itemCount: historiqueItems.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(historiqueItems[index].username),
            subtitle: Text('${historiqueItems[index].type == 'pending' ? 'Pending' : 'Non-Follower'} - ${historiqueItems[index].date}'),
            trailing: ElevatedButton(
              onPressed: () {
                _restoreItem(historiqueItems[index]);
              },
              child: Text('Restore'),
            ),
          );
        },
      ),
    );
  }
}