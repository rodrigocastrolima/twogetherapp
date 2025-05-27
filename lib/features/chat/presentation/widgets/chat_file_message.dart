import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../domain/models/chat_message.dart';

class ChatFileMessage extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatFileMessage({
    super.key,
    required this.message,
    required this.isMe,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.startsWith('image/')) return Icons.image;
    if (fileType.startsWith('video/')) return Icons.video_file;
    if (fileType.startsWith('audio/')) return Icons.audio_file;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('word') || fileType.contains('document')) return Icons.description;
    if (fileType.contains('excel') || fileType.contains('sheet')) return Icons.table_chart;
    if (fileType.contains('powerpoint') || fileType.contains('presentation')) return Icons.slideshow;
    if (fileType.contains('zip') || fileType.contains('archive')) return Icons.archive;
    return Icons.insert_drive_file;
  }

  Future<void> _openFile(BuildContext context) async {
    try {
      final url = Uri.parse(message.content);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (kDebugMode) {
          print('Could not launch $url');
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open file'),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error opening file: $e');
        print(stackTrace);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _openFile(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(message.fileType ?? 'application/octet-stream'),
              color: isMe ? Colors.white : colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'Unknown file',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMe ? Colors.white : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.fileSize != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(message.fileSize!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isMe ? Colors.white70 : colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              color: isMe ? Colors.white70 : colorScheme.onSurface.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
} 