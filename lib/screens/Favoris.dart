import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/App_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/db_helper.dart';
import '../model/user.dart';

class FavorisPage extends StatefulWidget {
  @override
  _FavorisPageState createState() => _FavorisPageState();
}

class _FavorisPageState extends State<FavorisPage> {
  DatabaseHelper dbHelper = DatabaseHelper();
  List<User> favoriteUsers = [];

  @override
  void initState() {
    super.initState();
    _initializeDatabaseAndLoadData();
  }

  Future<void> _initializeDatabaseAndLoadData() async {
    await dbHelper.initializeDatabase();
    _loadFavoriteUsers();
  }

  Future<void> _loadFavoriteUsers() async {
    List<User> pendingFavorites = await dbHelper.getPendingFavoriteUsers();
    List<User> nonFollowerFavorites = await dbHelper.getNonFollowerFavoriteUsers();
    setState(() {
      favoriteUsers = [...pendingFavorites, ...nonFollowerFavorites];
    });
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

  void toggleFavoriteStatus(int index) {
    setState(() {
      favoriteUsers[index].isFavorite = !favoriteUsers[index].isFavorite;
      dbHelper.updatePendingUserFavoriteStatus(favoriteUsers[index].id, favoriteUsers[index].isFavorite);
      dbHelper.updateNonFollowerFavoriteStatus(favoriteUsers[index].id, favoriteUsers[index].isFavorite);
      _loadFavoriteUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Users'),
      ),
      body: FutureBuilder<List<User>>(
        future: Future.wait([
          dbHelper.getPendingFavoriteUsers(),
          dbHelper.getNonFollowerFavoriteUsers(),
        ]).then((results) => [...results[0], ...results[1]]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No favorite users.'));
          } else {
            List<User> favoriteUsers = snapshot.data!;
            return ListView.builder(
              itemCount: favoriteUsers.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  elevation: 4,
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(
                          favoriteUsers[index].username,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        InkWell(
                          onTap: () {
                            if (favoriteUsers[index].link.isNotEmpty) {
                              _launchInstagram(favoriteUsers[index].link);
                            } else {
                              print("Instagram link is null for this user.");
                            }
                          },
                          child: Icon(
                            Icons.open_in_new,
                            color: AppTheme.buildLightTheme().primaryColor,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(favoriteUsers[index].link),
                    leading: InkWell(
                      onTap: () {
                        toggleFavoriteStatus(index);
                      },
                      child: Icon(
                        favoriteUsers[index].isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: favoriteUsers[index].isFavorite
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}