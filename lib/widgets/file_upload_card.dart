import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FileUploadCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String buttonText;
  final VoidCallback onPressed;
  final bool isLoading;
  final List<String>? loadedFiles;

  const FileUploadCard({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.onPressed,
    this.isLoading = false,
    this.loadedFiles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration.copyWith(
        border: Border.all(
          color: AppTheme.borderLight,
          width: 2,
        ),
      ),
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
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.headingSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (loadedFiles != null && loadedFiles!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.success.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Files loaded (${loadedFiles!.length})',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...loadedFiles!.map(
                    (fileName) => Padding(
                      padding: const EdgeInsets.only(left: 24, top: 2),
                      child: Text(
                        '• $fileName',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.success,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      loadedFiles != null && loadedFiles!.isNotEmpty
                          ? Icons.refresh
                          : Icons.upload_file,
                      size: 18,
                    ),
              label: Text(
                isLoading 
                    ? 'Processing...' 
                    : loadedFiles != null && loadedFiles!.isNotEmpty
                        ? 'Upload New File'
                        : buttonText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}