import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/empty_state.dart';
import '../database/db_helper.dart';
import '../model/historique.dart';
import '../model/user.dart';

class HistoryScreen extends StatefulWidget {
  final String? filterType;
  
  const HistoryScreen({Key? key, this.filterType}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<HistoriqueItem> historyItems = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    await dbHelper.initializeDatabase();
    _loadHistoryItems();
  }

  Future<void> _loadHistoryItems() async {
    setState(() => isLoading = true);
    try {
      final items = widget.filterType != null 
          ? await dbHelper.getHistoriqueItemsByType(widget.filterType!)
          : await dbHelper.getHistoriqueItems();
      setState(() {
        historyItems = items;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading history: $e');
    }
  }

  Future<void> _restoreItem(HistoriqueItem item) async {
    try {
      final user = User(
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
      await _loadHistoryItems();
      
      _showSuccessSnackBar(
        '${item.username} restored to ${item.type == 'pending' ? 'Pending Requests' : 'Non-Followers'}'
      );
    } catch (e) {
      _showErrorSnackBar('Error restoring item: $e');
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await _showClearConfirmationDialog();
    if (!confirmed) return;

    try {
      if (widget.filterType != null) {
        await dbHelper.clearHistoriqueByType(widget.filterType!);
      } else {
        for (var item in historyItems) {
          await dbHelper.deleteHistoriqueItem(item.id);
        }
      }
      await _loadHistoryItems();
      _showSuccessSnackBar('History cleared successfully');
    } catch (e) {
      _showErrorSnackBar('Error clearing history: $e');
    }
  }

  Future<bool> _showClearConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(_getClearDialogTitle()),
          content: Text(_getClearDialogContent()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  String _getClearDialogTitle() {
    switch (widget.filterType) {
      case 'pending':
        return 'Clear Pending Requests History';
      case 'nonfollower':
        return 'Clear Non-Followers History';
      default:
        return 'Clear All History';
    }
  }

  String _getClearDialogContent() {
    switch (widget.filterType) {
      case 'pending':
        return 'Are you sure you want to clear all pending requests history? This action cannot be undone.';
      case 'nonfollower':
        return 'Are you sure you want to clear all non-followers history? This action cannot be undone.';
      default:
        return 'Are you sure you want to clear all history? This action cannot be undone.';
    }
  }

  String _getScreenTitle() {
    return 'History';
  }

  String _getScreenSubtitle() {
    if (historyItems.isEmpty) {
      return 'No history yet';
    }
    
    switch (widget.filterType) {
      case 'pending':
        return 'Pending Requests • ${historyItems.length} items';
      case 'nonfollower':
        return 'Non-Followers • ${historyItems.length} items';
      default:
        return 'Total: ${historyItems.length}';
    }
  }

  String _getEmptyStateTitle() {
    switch (widget.filterType) {
      case 'pending':
        return 'No Pending Requests History';
      case 'nonfollower':
        return 'No Non-Followers History';
      default:
        return 'No History Yet';
    }
  }

  String _getEmptyStateDescription() {
    switch (widget.filterType) {
      case 'pending':
        return 'Deleted pending requests will appear here, and you can restore them if needed.';
      case 'nonfollower':
        return 'Deleted non-followers will appear here, and you can restore them if needed.';
      default:
        return 'Deleted users from Pending Requests and Non-Followers will appear here, and you can restore them if needed.';
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
        slivers: [
          CustomAppBar(
            title: _getScreenTitle(),
            subtitle: _getScreenSubtitle(),
            showBackButton: true,
            actions: [
              if (historyItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _clearAllHistory,
                  tooltip: 'Clear All History',
                ),
            ],
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
                else if (historyItems.isEmpty)
                  EmptyState(
                    icon: Icons.history,
                    title: _getEmptyStateTitle(),
                    description: _getEmptyStateDescription(),
                  )
                else ...[
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
                                  color: AppTheme.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.history,
                                  color: AppTheme.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Deleted Users History',
                                      style: AppTheme.headingSmall.copyWith(
                                        fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${historyItems.length} deleted users',
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
                              onPressed: _clearAllHistory,
                              icon: const Icon(Icons.delete_sweep, size: 16),
                              label: Text(widget.filterType != null ? 'Clear This History' : 'Clear All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.error,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...historyItems.map((item) => _buildHistoryItem(item)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(HistoriqueItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.type == 'pending' 
                        ? AppTheme.primary.withOpacity(0.1)
                        : AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      item.type == 'pending' 
                          ? Icons.pending_actions 
                          : Icons.people_alt_outlined,
                      color: item.type == 'pending' 
                          ? AppTheme.primary
                          : AppTheme.secondary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.username,
                              style: AppTheme.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isFavorite)
                            const Icon(
                              Icons.favorite,
                              color: AppTheme.error,
                              size: 16,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.type == 'pending' 
                                  ? AppTheme.primary.withOpacity(0.1)
                                  : AppTheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.type == 'pending' 
                                  ? 'Pending Request' 
                                  : 'Non-Follower',
                              style: AppTheme.bodySmall.copyWith(
                                color: item.type == 'pending' 
                                    ? AppTheme.primary
                                    : AppTheme.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: MediaQuery.of(context).size.width > 600 ? 14 : 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${item.date}',
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: MediaQuery.of(context).size.width > 600 ? 14 : 12,
                            ),
                          ),
                        ],
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
                onPressed: () => _restoreItem(item),
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Restore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}