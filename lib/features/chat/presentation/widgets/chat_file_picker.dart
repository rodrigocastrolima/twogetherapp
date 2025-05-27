import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'chat_file_preview_sheet.dart';

class ChatFilePicker extends ConsumerWidget {
  final String conversationId;

  const ChatFilePicker({
    super.key,
    required this.conversationId,
  });

  Future<void> _pickAndPreviewFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (kDebugMode) {
          print('No file selected');
        }
        return;
      }

      final file = result.files.first;
      if (kDebugMode) {
        print('Selected file: ${file.name}');
        print('File size: ${file.size}');
        print('File type: ${file.extension}');
      }

      // Show preview sheet
      if (!context.mounted) return;
      final success = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ChatFilePreviewSheet(
          file: kIsWeb ? file : File(file.path!),
          conversationId: conversationId,
          fileName: file.name,
          fileType: file.extension ?? 'application/octet-stream',
          fileSize: file.size,
        ),
      );

      if (success == true && kDebugMode) {
        print('File sent successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error picking file: $e');
        print(stackTrace);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.attach_file),
      tooltip: 'Attach file',
      onPressed: () => _pickAndPreviewFile(context),
    );
  }
} 