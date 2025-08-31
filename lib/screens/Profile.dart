import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:unfollowers/screens/PendingRequest.dart';
import 'dart:convert';
import 'dart:io';
import '../database/db_helper.dart';
import '../model/user.dart';
import 'DontFollow.dart';

class ProfilePage extends StatelessWidget {
  final dbHelper = DatabaseHelper();
  List<User> usersFollowing = [];
  List<User> usersFollowers = [];

  Future<bool> _requestStoragePermission(BuildContext context) async {
    try {
      // Check Android version and request appropriate permissions
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13+ (API 33+)
          var status = await Permission.photos.status;
          if (status.isDenied) {
            var result = await Permission.photos.request();
            if (result.isDenied) {
              _showPermissionDialog(context, 'Photos');
              return false;
            }
            if (result.isPermanentlyDenied) {
              _showSettingsDialog(context);
              return false;
            }
          }
        } else {
          // Android 12 and below
          var status = await Permission.storage.status;
          if (status.isDenied) {
            var result = await Permission.storage.request();
            if (result.isDenied) {
              _showPermissionDialog(context, 'Storage');
              return false;
            }
            if (result.isPermanentlyDenied) {
              _showSettingsDialog(context);
              return false;
            }
          }
        }
      }
      return true;
    } catch (e) {
      print('Permission error: $e');
      return false;
    }
  }

  void _showPermissionDialog(BuildContext context, String permissionType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text('This app needs $permissionType permission to select and read JSON files. Please grant the permission to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestStoragePermission(context);
              },
              child: Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text('Storage permission is permanently denied. Please enable it in app settings to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _selectFile(BuildContext context) async {
    bool hasPermission = await _requestStoragePermission(context);
    if (!hasPermission) {
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();

        List<User> users = processJsonData(jsonString);
        showSnackBarAndNavigatePendingRequest(context, users);
      }
    } catch (e) {
      print('File selection error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showSnackBarAndNavigatePendingRequest(BuildContext context, List<User> users) async {
    final snackBar = SnackBar(
      content: Row(
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text("Loading pending users..."),
        ],
      ),
      duration: Duration(seconds: 50),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      await dbHelper.initializeDatabase();
      await dbHelper.insertPendingUsers(users);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PendingRequestPage(usersFromFile: users)),
      );
    } catch (e) {
      print('Database error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  List<User> processJsonData(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      List<User> users = [];

      if (data['relationships_follow_requests_sent'] != null) {
        for (var request in data['relationships_follow_requests_sent']) {
          if (request['string_list_data'] != null) {
            for (var user in request['string_list_data']) {
              DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(user['timestamp'] * 1000);
              String formattedDate = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ";

              users.add(User(
                username: user['value'],
                link: user['href'],
                date: formattedDate,
              ));
            }
          }
        }
      }
      return users;
    } catch (e) {
      print('JSON processing error: $e');
      return [];
    }
  }

  /// non followers Back

  Future<void> _selectFileDontFollowBack(BuildContext context, String fileName) async {
    bool hasPermission = await _requestStoragePermission(context);
    if (!hasPermission) {
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();

        // Process the JSON data based on the file name (following or followers)
        List<User> users = processJsonDataDontFollowBack(jsonString, fileName);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fileName} loaded successfully! ${users.length} users found.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('File selection error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<User> processJsonDataDontFollowBack(String jsonString, String fileName) {
    try {
      final data = jsonDecode(jsonString);
      List<User> users = [];

      if (fileName == 'following.json') {
        if (data['relationships_following'] != null) {
          for (var request in data['relationships_following']) {
            if (request['string_list_data'] != null) {
              for (var user in request['string_list_data']) {
                DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(user['timestamp'] * 1000);
                String formattedDate =
                    "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ";

                usersFollowing.add(User(
                  username: user['value'],
                  link: user['href'],
                  date: formattedDate,
                ));
              }
            }
          }
        }
        users = usersFollowing;
      } else {
        // Process followers.json
        if (data is List) {
          for (var user in data) {
            if (user is Map && user.containsKey('string_list_data') && user['string_list_data'] is List && user['string_list_data'].isNotEmpty) {
              DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(user['string_list_data'][0]['timestamp'] * 1000);
              String formattedDate =
                  "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ";

              usersFollowers.add(User(
                username: user['string_list_data'][0]['value'],
                link: user['string_list_data'][0]['href'],
                date: formattedDate,
              ));
            }
          }
        }
        users = usersFollowers;
      }

      return users;
    } catch (e) {
      print('JSON processing error for $fileName: $e');
      return [];
    }
  }

  List<User> filterNonFollowers(List<User> followingList, List<User> followersList) {
    List<User> nonFollowers = [];

    for (var followingUser in followingList) {
      bool isFollower = followersList.any((followerUser) => followerUser.username == followingUser.username);

      if (!isFollower) {
        nonFollowers.add(followingUser);
      }
    }

    return nonFollowers;
  }

  void showSnackBarAndNavigateDontFollowBack(BuildContext context) async {
    if (usersFollowing.isEmpty || usersFollowers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select both following.json and followers.json files first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final snackBar = SnackBar(
      content: Row(
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text("Loading Non Followers users..."),
        ],
      ),
      duration: Duration(seconds: 50),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    try {
      List<User> nonFollowers = filterNonFollowers(usersFollowing, usersFollowers);
      for (var user in nonFollowers) {
        print('Non-follower: ${user.username}');
      }

      await dbHelper.initializeDatabase();
      //await dbHelper.insertPendingUsers(users);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DontFollowPage()),
      );
    } catch (e) {
      print('Error processing non-followers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    double cardWidth = MediaQuery.of(context).size.width - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Don\'t follow you',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.8,
                        ),
                      ),
                      subtitle: Column(
                        children: [
                          SizedBox(height: 5.0),
                          Text('Following.json'),
                          Container(
                            width: cardWidth,
                            child: ElevatedButton(
                              onPressed: () async {
                                await _selectFileDontFollowBack(context, 'following.json');
                              },
                              child: Text('Select Following JSON File'),
                            ),
                          ),
                          SizedBox(height: 2.5),
                          Divider(
                            color: Colors.grey,
                            thickness: 0.5,
                          ),
                          SizedBox(height: 2.5),
                          Text('Followers.json'),
                          Container(
                            width: cardWidth,
                            child: ElevatedButton(
                              onPressed: () async {
                                await _selectFileDontFollowBack(context, 'followers.json');
                              },
                              child: Text('Select Followers JSON File'),
                            ),
                          ),
                          SizedBox(height: 10.0),
                          ElevatedButton(
                            onPressed: () {
                              showSnackBarAndNavigateDontFollowBack(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                            ),
                            child: Text('Submit'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Pending Request',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.8,
                        ),
                      ),
                      subtitle: Column(
                        children: [
                          Text('Pending_follow_requests.json'),
                          Container(
                            width: cardWidth,
                            child: ElevatedButton(
                              onPressed: () => _selectFile(context),
                              child: Text('Select JSON File'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}