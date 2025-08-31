import 'package:sqflite/sqflite.dart';
import '../model/historique.dart';
import '../model/user.dart';

class DatabaseHelper {
  late Database _database;
  bool _isInitialized = false;

  DatabaseHelper._();

  factory DatabaseHelper() {
    return _instance;
  }

  static final DatabaseHelper _instance = DatabaseHelper._();

  bool get isDatabaseInitialized => _isInitialized;

  Future<void> initializeDatabase() async {
    if (!_isInitialized) {
      _database = await openDatabase(
        'InstaCheck_database.db',
        version: 2,
        onCreate: (db, version) {
          db.execute(
              'CREATE TABLE pendingusers (id INTEGER PRIMARY KEY, username TEXT, link TEXT, date TEXT, isFavorite INTEGER, source TEXT)');
          db.execute(
              'CREATE TABLE nonfollowers (id INTEGER PRIMARY KEY, username TEXT, link TEXT, date TEXT, isFavorite INTEGER, source TEXT)');
          db.execute(
              'CREATE TABLE historique (id INTEGER PRIMARY KEY, username TEXT, link TEXT, date TEXT, isFavorite INTEGER, type TEXT)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE pendingusers ADD COLUMN source TEXT');
            await db.execute('ALTER TABLE nonfollowers ADD COLUMN source TEXT');
            
            await db.execute('UPDATE pendingusers SET source = "pending" WHERE source IS NULL');
            await db.execute('UPDATE nonfollowers SET source = "nonfollower" WHERE source IS NULL');
          }
        },
      );
      _isInitialized = true;
    }
  }

  Future<void> insertPendingUsers(List<User> users) async {
    for (var user in users) {
      user.source = 'pending';
      
      List<Map<String, dynamic>> existingUsers = await _database.query(
        'pendingusers',
        where: 'username = ? AND link = ?',
        whereArgs: [user.username, user.link],
      );

      if (existingUsers.isEmpty) {
        await _database.insert('pendingusers', user.toMap());
      } else {
        print('User ${user.username} with link ${user.link} already exists in pendingusers. Skipping insertion.');
      }
    }
  }

  Future<void> insertNonFollowers(List<User> users) async {
    for (var user in users) {
      user.source = 'nonfollower';
      
      List<Map<String, dynamic>> existingUsers = await _database.query(
        'nonfollowers',
        where: 'username = ? AND link = ?',
        whereArgs: [user.username, user.link],
      );

      if (existingUsers.isEmpty) {
        await _database.insert('nonfollowers', user.toMap());
      } else {
        print('User ${user.username} with link ${user.link} already exists in nonfollowers. Skipping insertion.');
      }
    }
  }

  Future<List<User>> getPendingUsers() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'pendingusers',
      orderBy: 'date DESC, username ASC',
    );
    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
        source: maps[i]['source'] ?? 'pending',
      );
    });
  }

  Future<List<User>> getNonFollowers() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'nonfollowers',
      orderBy: 'date DESC, username ASC',
    );
    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
        source: maps[i]['source'] ?? 'nonfollower',
      );
    });
  }

  Future<List<User>> getPendingFavoriteUsers() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'pendingusers',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'date DESC, username ASC',
    );

    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
        source: maps[i]['source'] ?? 'pending',
      );
    });
  }

  Future<List<User>> getNonFollowerFavoriteUsers() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'nonfollowers',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'date DESC, username ASC',
    );

    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
        source: maps[i]['source'] ?? 'nonfollower',
      );
    });
  }

  Future<void> deletePendingUser(int? userId) async {
    if (userId != null) {
      List<Map<String, dynamic>> userData = await _database.query(
        'pendingusers',
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (userData.isNotEmpty) {
        HistoriqueItem historyItem = HistoriqueItem(
          username: userData[0]['username'],
          link: userData[0]['link'],
          date: userData[0]['date'],
          isFavorite: userData[0]['isFavorite'] == 1,
          type: 'pending',
        );
        
        await _database.insert('historique', historyItem.toMap());
      }
      
      await _database.delete(
        'pendingusers',
        where: 'id = ?',
        whereArgs: [userId],
      );
    } else {
      print('User ID is null.');
    }
  }

  Future<void> deleteNonFollower(int? userId) async {
    if (userId != null) {
      List<Map<String, dynamic>> userData = await _database.query(
        'nonfollowers',
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      if (userData.isNotEmpty) {
        HistoriqueItem historyItem = HistoriqueItem(
          username: userData[0]['username'],
          link: userData[0]['link'],
          date: userData[0]['date'],
          isFavorite: userData[0]['isFavorite'] == 1,
          type: 'nonfollower',
        );
        
        await _database.insert('historique', historyItem.toMap());
      }
      
      await _database.delete(
        'nonfollowers',
        where: 'id = ?',
        whereArgs: [userId],
      );
    } else {
      print('User ID is null.');
    }
  }

  Future<void> updatePendingUserFavoriteStatus(int? userId, bool isFavorite) async {
    if (userId != null) {
      await _database.update(
        'pendingusers',
        {'isFavorite': isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [userId],
      );
    }
  }

  Future<void> updateNonFollowerFavoriteStatus(int? userId, bool isFavorite) async {
    if (userId != null) {
      await _database.update(
        'nonfollowers',
        {'isFavorite': isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [userId],
      );
    }
  }

  Future<void> insertHistoriqueItem(List<HistoriqueItem> items) async {
    for (var item in items) {
      await _database.insert('historique', item.toMap());
    }
  }

  Future<List<HistoriqueItem>> getHistoriqueItems() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'historique',
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) {
      return HistoriqueItem(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
        type: maps[i]['type'],
      );
    });
  }

  Future<List<HistoriqueItem>> getHistoriqueItemsByType(String type) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'historique',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) {
      return HistoriqueItem(
        id: maps[i]['id'],
        username: maps[i]['username'],
        link: maps[i]['link'],
        date: maps[i]['date'],
        isFavorite: maps[i]['isFavorite'] == 1,
        type: maps[i]['type'],
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

  Future<void> clearHistoriqueByType(String type) async {
    await _database.delete(
      'historique',
      where: 'type = ?',
      whereArgs: [type],
    );
  }

  Future<void> restoreFromHistory(HistoriqueItem item) async {
    try {
      User user = User(
        username: item.username,
        link: item.link,
        date: item.date,
        isFavorite: item.isFavorite,
        source: item.type,
      );

      if (item.type == 'pending') {
        await _database.insert('pendingusers', user.toMap());
      } else if (item.type == 'nonfollower') {
        await _database.insert('nonfollowers', user.toMap());
      }

      await deleteHistoriqueItem(item.id);
    } catch (e) {
      print('Error restoring item from history: $e');
      throw e;
    }
  }
}