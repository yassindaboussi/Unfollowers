import 'package:sqflite/sqflite.dart';
import '../model/historique.dart';
import '../model/user.dart';

class DatabaseHelper {
  late Database _database;

  DatabaseHelper._();

  factory DatabaseHelper() {
    return _instance;
  }

  static final DatabaseHelper _instance = DatabaseHelper._();

  bool get isDatabaseInitialized => _database != null;

  Future<void> initializeDatabase() async {
    _database = await openDatabase('InstaCheck_database.db', version: 1,
        onCreate: (db, version) {
          db.execute(
              'CREATE TABLE pendingusers (id INTEGER PRIMARY KEY, username TEXT, link TEXT, date TEXT, isFavorite INTEGER)');
          db.execute(
              'CREATE TABLE historique (id INTEGER PRIMARY KEY, username TEXT, link TEXT, date TEXT, isFavorite INTEGER)');
        });
  }


  Future<void> insertPendingUsers(List<User> users) async {
    for (var user in users) {
      List<Map<String, dynamic>> existingUsers = await _database.query(
        'pendingusers',
        where: 'username = ? AND link = ?',
        whereArgs: [user.username, user.link],
      );

      if (existingUsers.isEmpty) {
        await _database.insert('pendingusers', user.toMap());
      } else {
        print(
            'User ${user.username} with link ${user.link} already exists. Skipping insertion.');
      }
    }
  }

  Future<List<User>> getPendingUsers() async {
    final List<Map<String, dynamic>> maps = await _database.query('pendingusers');
    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
      );
    });
  }

  Future<void> deletePendingUser(int? userId) async {
    if (userId != null) {
      await _database.delete(
        'pendingusers',
        where: 'id = ?',
        whereArgs: [userId],
      );
    } else {
      print('User ID is null.');
    }
  }

  Future<void> updatePendingUserFavoriteStatus(int? userId, bool isFavorite) async {
    await _database.update(
      'pendingusers',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<User>> getPendingFavoriteUsers() async {
    final List<Map<String, dynamic>> maps = await _database.query('pendingusers',
        where: 'isFavorite = ?',
        whereArgs: [1]);

    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
      );
    });
  }

  /////////////////////// Historique

  Future<void> insertHistoriqueItem(List<HistoriqueItem> items) async {
    for (var item in items) {
      await _database.insert('historique', item.toMap());
    }
  }

  Future<List<HistoriqueItem>> getHistoriqueItems() async {
    final List<Map<String, dynamic>> maps = await _database.query('historique');
    return List.generate(maps.length, (i) {
      return HistoriqueItem(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
      );
    });
  }

  Future<void> deleteHistoriqueItem(int? itemId) async {
    if (itemId != null) {
      await _database.delete(
        'historique',
        where: 'id = ?',
        whereArgs: [itemId],
      );
    } else {
      print('Item ID is null.');
    }
  }

}

