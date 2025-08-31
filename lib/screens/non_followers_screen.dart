import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/user_list_item.dart';
import '../widgets/file_upload_card.dart';
import '../widgets/empty_state.dart';
import '../database/db_helper.dart';
import '../model/user.dart';
import 'history_screen.dart';

class NonFollowersScreen extends StatefulWidget {
  const NonFollowersScreen({Key? key}) : super(key: key);

  @override
  State<NonFollowersScreen> createState() => _NonFollowersScreenState();
}

class _NonFollowersScreenState extends State<NonFollowersScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ScrollController _scrollController = ScrollController();
  List<User> users = [];
  List<User> followingUsers = [];
  List<User> followerUsers = [];
  bool isLoading = false;
  bool hasData = false;
  bool followingLoaded = false;
  List<String> followersFilesLoaded = [];

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeDatabase() async {
    await dbHelper.initializeDatabase();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => isLoading = true);
    try {
      final loadedUsers = await dbHelper.getNonFollowers();
      setState(() {
        users = loadedUsers;
        hasData = loadedUsers.isNotEmpty;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading users: $e');
    }
  }

  Future<void> _loadUsersWithScrollPreservation() async {
    final currentOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    
    try {
      final loadedUsers = await dbHelper.getNonFollowers();
      setState(() {
        users = loadedUsers;
        hasData = loadedUsers.isNotEmpty;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && currentOffset > 0) {
          _scrollController.animateTo(
            currentOffset,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      _showErrorSnackBar('Error loading users: $e');
    }
  }

  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        
        if (androidInfo.version.sdkInt >= 33) {
          var status = await Permission.photos.status;
          if (status.isDenied) {
            var result = await Permission.photos.request();
            return result.isGranted;
          }
        } else {
          var status = await Permission.storage.status;
          if (status.isDenied) {
            var result = await Permission.storage.request();
            return result.isGranted;
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _selectFollowingFile() async {
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      _showErrorSnackBar('Storage permission is required to select files');
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
        List<User> users = _processFollowingData(jsonString);
        
        setState(() {
          followingUsers = users;
          followingLoaded = true;
        });
        
        _showSuccessSnackBar('Following file loaded: ${users.length} users found');
        _checkAndProcessNonFollowers();
      }
    } catch (e) {
      _showErrorSnackBar('Error processing following file: $e');
    }
  }

  Future<void> _selectFollowersFiles() async {
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      _showErrorSnackBar('Storage permission is required to select files');
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        followerUsers.clear();
        followersFilesLoaded.clear();
        
        for (var platformFile in result.files) {
          File file = File(platformFile.path!);
          String fileName = platformFile.name;
          String jsonString = await file.readAsString();
          
          List<User> users = _processFollowersData(jsonString);
          followerUsers.addAll(users);
          followersFilesLoaded.add(fileName);
        }

        followerUsers = _removeDuplicateUsers(followerUsers);
        setState(() {});
        
        _showSuccessSnackBar(
          '${followersFilesLoaded.length} followers file(s) loaded: ${followerUsers.length} unique users found'
        );
        _checkAndProcessNonFollowers();
      }
    } catch (e) {
      _showErrorSnackBar('Error processing followers files: $e');
    }
  }

  void _checkAndProcessNonFollowers() {
    if (followingLoaded && followersFilesLoaded.isNotEmpty) {
      _processNonFollowers();
    }
  }

  Future<void> _processNonFollowers() async {
    setState(() => isLoading = true);
    
    try {
      List<User> nonFollowers = _filterNonFollowers(followingUsers, followerUsers);
      await dbHelper.insertNonFollowers(nonFollowers);
      await _loadUsers();
      _showSuccessSnackBar('${nonFollowers.length} non-followers found and loaded!');
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error processing non-followers: $e');
    }
  }

  List<User> _processFollowingData(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      List<User> users = [];

      if (data['relationships_following'] != null) {
        for (var request in data['relationships_following']) {
          if (request['string_list_data'] != null) {
            for (var user in request['string_list_data']) {
              DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
                user['timestamp'] * 1000
              );
              String formattedDate = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

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

  List<User> _processFollowersData(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      List<User> users = [];

      if (data is List) {
        for (var user in data) {
          if (user is Map && 
              user.containsKey('string_list_data') && 
              user['string_list_data'] is List && 
              user['string_list_data'].isNotEmpty) {
            DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
              user['string_list_data'][0]['timestamp'] * 1000
            );
            String formattedDate = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

            users.add(User(
              username: user['string_list_data'][0]['value'],
              link: user['string_list_data'][0]['href'],
              date: formattedDate,
            ));
          }
        }
      } else if (data is Map && data['relationships_followers'] != null) {
        for (var request in data['relationships_followers']) {
          if (request['string_list_data'] != null) {
            for (var user in request['string_list_data']) {
              DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
                user['timestamp'] * 1000
              );
              String formattedDate = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";

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

  List<User> _removeDuplicateUsers(List<User> users) {
    Map<String, User> userMap = {};
    for (var user in users) {
      userMap[user.username] = user;
    }
    return userMap.values.toList();
  }

  List<User> _filterNonFollowers(List<User> followingList, List<User> followersList) {
    List<User> nonFollowers = [];

    for (var followingUser in followingList) {
      bool isFollower = followersList.any(
        (followerUser) => followerUser.username == followingUser.username
      );

      if (!isFollower) {
        nonFollowers.add(followingUser);
      }
    }

    return nonFollowers;
  }

  Future<void> _deleteUser(User user) async {
    try {
      await dbHelper.deleteNonFollower(user.id!);
      await _loadUsersWithScrollPreservation();
      _showSuccessSnackBar('${user.username} removed from non-followers');
    } catch (e) {
      _showErrorSnackBar('Error removing user: $e');
    }
  }

  Future<void> _toggleFavorite(User user) async {
    try {
      user.isFavorite = !user.isFavorite;
      await dbHelper.updateNonFollowerFavoriteStatus(user.id, user.isFavorite);
      await _loadUsersWithScrollPreservation();
    } catch (e) {
      _showErrorSnackBar('Error updating favorite: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          CustomAppBar(
            title: 'Non-Followers',
            subtitle: hasData ? 'Total: ${users.length}' : 'No data loaded',
            showBackButton: true,
            actions: [
              if (hasData)
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(filterType: 'nonfollower'),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!hasData) ...[
                  FileUploadCard(
                    title: 'Upload Following File',
                    description: 'Select your following.json file',
                    icon: Icons.person_add,
                    buttonText: followingLoaded ? 'Change Following File' : 'Select Following File',
                    onPressed: _selectFollowingFile,
                    isLoading: isLoading && !followingLoaded,
                    loadedFiles: followingLoaded ? ['following.json'] : null,
                  ),
                  const SizedBox(height: 16),
                  FileUploadCard(
                    title: 'Upload Followers File(s)',
                    description: 'Select one or more followers.json files',
                    icon: Icons.people,
                    buttonText: followersFilesLoaded.isNotEmpty ? 'Change Followers Files' : 'Select Followers Files',
                    onPressed: _selectFollowersFiles,
                    isLoading: isLoading && followersFilesLoaded.isNotEmpty,
                    loadedFiles: followersFilesLoaded,
                  ),
                  if (followingLoaded && followersFilesLoaded.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _processNonFollowers,
                        icon: isLoading 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.analytics),
                        label: Text(isLoading ? 'Processing...' : 'Find Non-Followers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const EmptyState(
                    icon: Icons.people_alt_outlined,
                    title: 'No Non-Followers Data',
                    description: 'Upload your Instagram following and followers files to find people who don\'t follow you back.',
                  ),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.people_alt_outlined,
                                  color: AppTheme.secondary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Non-Followers Analysis Complete',
                                      style: AppTheme.headingSmall.copyWith(
                                        fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${users.length} non-followers found',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  hasData = false;
                                  followingLoaded = false;
                                  followersFilesLoaded.clear();
                                  followingUsers.clear();
                                  followerUsers.clear();
                                  users.clear();
                                });
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Analyze Again'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (hasData)
                  ...users.map((user) => UserListItem(
                    user: user,
                    onDelete: () => _deleteUser(user),
                    onToggleFavorite: () => _toggleFavorite(user),
                  )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}