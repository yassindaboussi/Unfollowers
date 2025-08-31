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

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({Key? key}) : super(key: key);

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final ScrollController _scrollController = ScrollController();
  List<User> users = [];
  bool isLoading = false;
  bool hasData = false;

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
      final loadedUsers = await dbHelper.getPendingUsers();
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
      final loadedUsers = await dbHelper.getPendingUsers();
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

  Future<void> _selectFile() async {
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
        setState(() => isLoading = true);
        
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        List<User> newUsers = _processJsonData(jsonString);
        
        if (newUsers.isNotEmpty) {
          await dbHelper.insertPendingUsers(newUsers);
          await _loadUsers();
          _showSuccessSnackBar('${newUsers.length} pending requests loaded successfully!');
        } else {
          setState(() => isLoading = false);
          _showErrorSnackBar('No pending requests found in the file');
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error processing file: $e');
    }
  }

  List<User> _processJsonData(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      List<User> users = [];

      if (data['relationships_follow_requests_sent'] != null) {
        for (var request in data['relationships_follow_requests_sent']) {
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

  Future<void> _deleteUser(User user) async {
    try {
      await dbHelper.deletePendingUser(user.id!);
      await _loadUsersWithScrollPreservation();
      _showSuccessSnackBar('${user.username} removed from pending requests');
    } catch (e) {
      _showErrorSnackBar('Error removing user: $e');
    }
  }

  Future<void> _toggleFavorite(User user) async {
    try {
      user.isFavorite = !user.isFavorite;
      await dbHelper.updatePendingUserFavoriteStatus(user.id, user.isFavorite);
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
            title: 'Pending Requests',
            subtitle: hasData ? 'Total: ${users.length}' : 'No data loaded',
            showBackButton: true,
            actions: [
              if (hasData)
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(filterType: 'pending'),
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
                    title: 'Upload Pending Requests File',
                    description: 'Select your pending_follow_requests.json file to analyze your Instagram follow requests',
                    icon: Icons.pending_actions,
                    buttonText: 'Select JSON File',
                    onPressed: _selectFile,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 32),
                  const EmptyState(
                    icon: Icons.pending_actions,
                    title: 'No Pending Requests',
                    description: 'Upload your Instagram data to see your pending follow requests here.',
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
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.pending_actions,
                                  color: AppTheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pending Requests Loaded',
                                      style: AppTheme.headingSmall.copyWith(
                                        fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${users.length} requests found',
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
                              onPressed: _selectFile,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reload'),
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