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
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget for AppBar

class ResellerProviderFilesPage extends ConsumerWidget {
  final String providerId;
  final String providerName;

  const ResellerProviderFilesPage({
    super.key, 
    required this.providerId,
    required this.providerName,
  });

  // --- File Tap Handler ---
  Future<void> _handleFileTap(BuildContext context, ProviderFile file) async {
    final fileType = file.fileType.toLowerCase();
    final url = Uri.parse(file.downloadUrl);

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileType)) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImageViewer(imageUrl: file.downloadUrl, imageName: file.fileName), fullscreenDialog: true));
    } else if (fileType == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenPdfViewer(pdfUrl: file.downloadUrl, pdfName: file.fileName), fullscreenDialog: true));
    } else {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o link do ficheiro: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsyncValue = ref.watch(providerFilesStreamProvider(providerId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark; // For LogoWidget in AppBar

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDark),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.0,
      ),
      body: Column( // Wrap body in Column to add title
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0), // Add padding for the title
            child: Text(
              providerName, // Display the provider name
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
      ),
          ),
          Expanded( // Make the ListView take remaining space
            child: filesAsyncValue.when(
        data: (files) {
          if (files.isEmpty) {
            return const Center(
                    child: Text('Nenhuns ficheiros disponíveis para este fornecedor.'), // Portuguese
            );
          }
          return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Added vertical padding too
            itemCount: files.length,
            separatorBuilder:
                      (context, index) => const SizedBox(height: 12), // Use SizedBox for spacing
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
                      child: Text('Erro ao carregar ficheiros: $error', textAlign: TextAlign.center), // Portuguese
                ),
              ),
            ),
      ),
        ],
      ),
    );
  }

  // Build list item - no delete button
  Widget _buildFileListItem(
    BuildContext context,
    ProviderFile file,
    ThemeData theme,
  ) {
    final fileIcon = _getFileIcon(file.fileType);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _handleFileTap(context, file),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : theme.canvasColor, // Subtle background
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.1),
            width: 1.0,
          )
        ),
        child: Row(
          children: [
            Icon(fileIcon, color: theme.colorScheme.primary, size: 36), // Larger icon
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
        file.fileName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
                    maxLines: 2, // Allow more lines for longer names
        overflow: TextOverflow.ellipsis,
      ),
                  if (file.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
            file.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_forward, // Changed from chevron_right
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              size: 22,
          ),
        ],
      ),
      ),
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




