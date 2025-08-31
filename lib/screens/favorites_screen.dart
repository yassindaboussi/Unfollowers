import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/user_list_item.dart';
import '../widgets/empty_state.dart';
import '../database/db_helper.dart';
import '../model/user.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<User> favoriteUsers = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    await dbHelper.initializeDatabase();
    _loadFavoriteUsers();
  }

  Future<void> _loadFavoriteUsers() async {
    setState(() => isLoading = true);
    try {
      final pendingFavorites = await dbHelper.getPendingFavoriteUsers();
      final nonFollowerFavorites = await dbHelper.getNonFollowerFavoriteUsers();
      
      setState(() {
        favoriteUsers = [...pendingFavorites, ...nonFollowerFavorites];
        favoriteUsers.sort((a, b) {
          int sourceComparison = (a.source ?? 'unknown').compareTo(b.source ?? 'unknown');
          if (sourceComparison != 0) return sourceComparison;
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        });
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading favorite users: $e');
    }
  }

  Future<void> _removeFavorite(User user) async {
    try {
      user.isFavorite = false;
      
      await dbHelper.updatePendingUserFavoriteStatus(user.id, false);
      await dbHelper.updateNonFollowerFavoriteStatus(user.id, false);
      
      await _loadFavoriteUsers();
      _showSuccessSnackBar('${user.username} removed from favorites');
    } catch (e) {
      _showErrorSnackBar('Error removing from favorites: $e');
    }
  }

  Future<void> _toggleFavorite(User user) async {
    await _removeFavorite(user);
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
    int pendingCount = favoriteUsers.where((u) => u.source == 'pending').length;
    int nonFollowerCount = favoriteUsers.where((u) => u.source == 'nonfollower').length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CustomAppBar(
            title: 'Favorites',
            subtitle: favoriteUsers.isNotEmpty 
                ? 'Total: ${favoriteUsers.length}' 
                : 'No favorites yet',
            showBackButton: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (favoriteUsers.isEmpty)
                  const EmptyState(
                    icon: Icons.favorite_border,
                    title: 'No Favorites Yet',
                    description: 'Users you mark as favorites from the Pending Requests or Non-Followers screens will appear here.',
                  )
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: AppTheme.error,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Favorite Users',
                                      style: AppTheme.headingSmall,
                                    ),
                                    Text(
                                      '${favoriteUsers.length} users marked as favorites',
                                      style: AppTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${favoriteUsers.length}',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (pendingCount > 0 || nonFollowerCount > 0) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (pendingCount > 0) ...[
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.pending_actions,
                                            color: AppTheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$pendingCount',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          Text(
                                            'Pending',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (pendingCount > 0 && nonFollowerCount > 0)
                                  const SizedBox(width: 12),
                                if (nonFollowerCount > 0) ...[
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.people_alt_outlined,
                                            color: AppTheme.secondary,
                                            size: 20,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$nonFollowerCount',
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.secondary,
                                            ),
                                          ),
                                          Text(
                                            'Non-Followers',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...favoriteUsers.map((user) => UserListItem(
                    user: user,
                    onDelete: () => _removeFavorite(user),
                    onToggleFavorite: () => _toggleFavorite(user),
                  )),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}