import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../providers/chat_provider.dart';

class ChatFilePreviewSheet extends ConsumerStatefulWidget {
  final dynamic file; // Can be XFile or File
  final String conversationId;
  final String fileName;
  final String fileType;
  final int fileSize;

  const ChatFilePreviewSheet({
    super.key,
    required this.file,
    required this.conversationId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
  });

  @override
  ConsumerState<ChatFilePreviewSheet> createState() => _ChatFilePreviewSheetState();
}

class _ChatFilePreviewSheetState extends ConsumerState<ChatFilePreviewSheet> {
  bool _isLoading = false;

  Future<void> _handleSendFile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('Starting file sending process from bottom sheet');
        print('File type: ${widget.file.runtimeType}');
      }

      final timeout = kIsWeb ? const Duration(minutes: 2) : const Duration(seconds: 45);

      await Future.any([
        ref.read(chatNotifierProvider.notifier).sendFileMessage(
          widget.conversationId,
          widget.file,
          widget.fileName,
          widget.fileType,
          widget.fileSize,
        ),
        Future.delayed(timeout, () {
          throw TimeoutException(
            "Upload timed out after ${timeout.inSeconds} seconds.",
          );
        }),
      ]);

      if (kDebugMode) {
        print('Successfully sent file message from bottom sheet');
      }

      // Close the bottom sheet on success
      if (!mounted) return;
      Navigator.pop(context, true); // Indicate success
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error sending file: $e');
        print(stackTrace);
      }
      if (!mounted) return;
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending file: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      // Close the bottom sheet on error
      Navigator.pop(context, false);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(widget.fileType),
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fileName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(widget.fileSize),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(192),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // File preview area
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileIcon(widget.fileType),
                        size: 64,
                        color: theme.colorScheme.primary.withAlpha(128),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.fileName,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatFileSize(widget.fileSize),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(192),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Send button
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            right: 20,
            child: FloatingActionButton(
              tooltip: 'Send file',
              backgroundColor: theme.colorScheme.primary,
              onPressed: _isLoading ? null : _handleSendFile,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
} 