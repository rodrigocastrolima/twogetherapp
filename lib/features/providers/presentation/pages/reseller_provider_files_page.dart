import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/provider_providers.dart';
import '../../domain/models/provider_file.dart';
import '../../../../core/theme/theme.dart';
// Import the viewers
import '../../../../presentation/widgets/full_screen_image_viewer.dart';
import '../../../../presentation/widgets/full_screen_pdf_viewer.dart';

class ResellerProviderFilesPage extends ConsumerWidget {
  final String providerId;
  // TODO: Pass provider name for AppBar title

  const ResellerProviderFilesPage({super.key, required this.providerId});

  // --- File Tap Handler ---
  Future<void> _handleFileTap(BuildContext context, ProviderFile file) async {
    final fileType = file.fileType.toLowerCase();
    final url = Uri.parse(file.downloadUrl);

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileType)) {
      // Navigate to FullScreenImageViewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => FullScreenImageViewer(
                imageUrl: file.downloadUrl,
                imageName: file.fileName,
              ),
          fullscreenDialog: true, // Present as a modal
        ),
      );
    } else if (fileType == 'pdf') {
      // Navigate to FullScreenPdfViewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => FullScreenPdfViewer(
                pdfUrl: file.downloadUrl,
                pdfName: file.fileName,
              ),
          fullscreenDialog: true,
        ),
      );
    } else {
      // Attempt to launch URL for other types
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        print('Error launching file URL: $e');
        // Use ScaffoldMessenger directly for error feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file link: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsyncValue = ref.watch(providerFilesStreamProvider(providerId));
    final theme = Theme.of(context);
    final String appBarTitle = 'Resources'; // Placeholder title

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: false,
        elevation: 1,
        shadowColor: theme.shadowColor.withOpacity(0.1),
      ),
      body: filesAsyncValue.when(
        data: (files) {
          if (files.isEmpty) {
            return const Center(
              child: Text(
                'No files available for this provider yet.',
              ), // TODO: l10n
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: files.length,
            separatorBuilder:
                (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: theme.dividerColor.withOpacity(0.5),
                  indent: 16,
                  endIndent: 16,
                ),
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildFileListItem(context, file, theme);
            },
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading files: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      ),
      // No FAB for resellers
    );
  }

  // Build list item - no delete button
  Widget _buildFileListItem(
    BuildContext context,
    ProviderFile file,
    ThemeData theme,
  ) {
    final dateFormatter = DateFormat.yMd().add_jm();
    final fileIcon = _getFileIcon(file.fileType);

    return ListTile(
      leading: Icon(fileIcon, color: theme.colorScheme.primary, size: 28),
      title: Text(
        file.fileName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.description,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Uploaded: ${dateFormatter.format(file.uploadedAt.toDate())}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        size: 20,
      ),
      onTap: () => _handleFileTap(context, file), // Call handler on tap
    );
  }

  // Icon helper (same as admin version)
  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return CupertinoIcons.doc_text_fill;
      case 'doc':
      case 'docx':
        return CupertinoIcons.doc_richtext;
      case 'xls':
      case 'xlsx':
        return CupertinoIcons.table_fill;
      case 'ppt':
      case 'pptx':
        return CupertinoIcons.tv_music_note_fill;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return CupertinoIcons.photo_fill;
      case 'zip':
      case 'rar':
        return CupertinoIcons.archivebox_fill;
      default:
        return CupertinoIcons.doc_fill;
    }
  }
}
