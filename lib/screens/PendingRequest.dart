import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/historique.dart';
import '../theme/App_theme.dart';
import '../database/db_helper.dart';
import '../model/user.dart';
import 'Historique.dart';

class PendingRequestPage extends StatefulWidget {
  final List<User>? usersFromFile;

  PendingRequestPage({this.usersFromFile});

  @override
  _PendingRequestPageState createState() => _PendingRequestPageState();
}

class _PendingRequestPageState extends State<PendingRequestPage> with SingleTickerProviderStateMixin {
  int totalPendingUsers = 0;
  DatabaseHelper dbHelper = DatabaseHelper();
  List<User> users = [];

  @override
  void initState() {
    super.initState();
    _initializeDatabaseAndLoadData();
  }

  Future<void> _initializeDatabaseAndLoadData() async {
    await dbHelper.initializeDatabase();

    if (widget.usersFromFile != null) {
      CountPendingUsers();
      loadUsers();
    } else {
      if (dbHelper.isDatabaseInitialized) {
        CountPendingUsers();
        loadUsers();
      }
    }
  }

  Future<void> loadUsers() async {
    List<User> loadedUsers = await dbHelper.getPendingUsers();
    if (mounted) {
      setState(() {
        users = loadedUsers;
      });
    }
  }

  Future<void> CountPendingUsers() async {
    List<User> loadedUsers = await dbHelper.getPendingUsers();
    if (mounted) {
      setState(() {
        users = loadedUsers;
        totalPendingUsers = users.length;
      });
    }
  }

  Future<void> _launchInstagram(String url) async {
    if (url.isEmpty) {
      print('Instagram link is null or empty.');
      return;
    }

    try {
      final bool nativeLaunch = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!nativeLaunch) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error launching Instagram URL: $e');
    }
  }

  Future<void> _deleteUser(int? userId) async {
    if (userId != null) {
      User deletedUser = users.firstWhere((user) => user.id == userId);
      HistoriqueItem historiqueItem = HistoriqueItem(
        username: deletedUser.username,
        link: deletedUser.link,
        date: deletedUser.date,
        isFavorite: deletedUser.isFavorite,
        type: 'pending',
      );
      await dbHelper.insertHistoriqueItem([historiqueItem]);
      await dbHelper.deletePendingUser(userId);
      CountPendingUsers();
      await loadUsers();
    } else {
      print('User ID is null.');
    }
  }

  void _toggleFavorite(int index) {
    setState(() {
      users[index].isFavorite = !users[index].isFavorite;
      dbHelper.updatePendingUserFavoriteStatus(users[index].id, users[index].isFavorite);
    });
  }

  void _refreshPendingUsers() {
    CountPendingUsers();
    loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.buildLightTheme().primaryColor,
        title: Text(
          "Total: $totalPendingUsers",
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoriquePage(
                    refreshCallback: () {
                      _refreshPendingUsers();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              if (users[index].link.isNotEmpty) {
                _launchInstagram(users[index].link);
              } else {
                print("Instagram link is null for this user.");
              }
            },
            child: Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                title: Text(
                  '${users[index].username}',
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18.8,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${users[index].date}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        users[index].isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: users[index].isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: () {
                        _toggleFavorite(index);
                      },
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _deleteUser(users[index].id);
                    });
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}