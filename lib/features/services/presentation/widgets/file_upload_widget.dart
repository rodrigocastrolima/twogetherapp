import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/ui_styles.dart';
import '../providers/service_submission_provider.dart';

/// Widget for uploading documents and photos
class FileUploadWidget extends ConsumerWidget {
  const FileUploadWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(serviceSubmissionProvider);
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and instructions
        Text(
          'Upload PDF Document',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please select a PDF file or take a photo for the service request',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.foreground.withAlpha(
              (0.7 * 255).round(),
            ), // Updated from withOpacity
          ),
        ),
        const SizedBox(height: 16),

        // File grid with add button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(
              (0.1 * 255).round(),
            ), // Updated from withOpacity
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha((0.2 * 255).round()),
            ), // Updated from withOpacity
          ),
          child: Column(
            children: [
              // Show selected invoice file if available
              if (formState.selectedInvoiceFile != null)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: 1,
                  itemBuilder: (context, index) {
                    return _buildImagePreview(
                      context,
                      formState.selectedInvoiceFile,
                      onDelete: () => formNotifier.clearInvoiceFile(),
                    );
                  },
                ),

              // Show options when no file is selected
              if (formState.selectedInvoiceFile == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Take Photo option
                    Expanded(
                      child: _buildOptionButton(
                        context: context,
                        icon: Icons.camera_alt_rounded,
                        label: 'Take Photo',
                        onTap: () => formNotifier.pickInvoiceFromCamera(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Upload File option
                    Expanded(
                      child: _buildOptionButton(
                        context: context,
                        icon: Icons.file_upload_outlined,
                        label: 'Upload File',
                        onTap:
                            () => _showFilePickerOptions(context, formNotifier),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Error message
        if (formState.errorMessage != null &&
            formState.errorMessage!.contains('file')) ...[
          const SizedBox(height: 8),
          Text(
            formState.errorMessage!,
            style: TextStyle(color: AppTheme.destructive, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(
            (0.05 * 255).round(),
          ), // Updated from withOpacity
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withAlpha((0.3 * 255).round()),
            width: 1,
          ), // Updated from withOpacity
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilePickerOptions(
    BuildContext context,
    ServiceSubmissionNotifier formNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.background.withAlpha(
              (0.95 * 255).round(),
            ), // Updated from withOpacity
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Select PDF File'),
                onTap: () {
                  Navigator.pop(context);
                  formNotifier.pickPdfFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Select Image'),
                onTap: () {
                  Navigator.pop(context);
                  formNotifier.pickInvoiceFile();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePreview(
    BuildContext context,
    dynamic image, {
    required VoidCallback onDelete,
  }) {
    return Stack(
      children: [
        // File preview
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey[200],
            width: double.infinity,
            height: double.infinity,
            child: _buildFilePreview(image),
          ),
        ),

        // Delete button
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(
                  (0.7 * 255).round(),
                ), // Updated from withOpacity
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePreview(dynamic file) {
    // Helper function to get file path or name
    String getFileName(dynamic file) {
      if (file is File) {
        return file.path.split('/').last;
      } else if (file is XFile) {
        return file.name;
      }
      return "Document";
    }

    // Determine if it's a PDF based on file extension
    bool isPdf = false;
    String fileName = getFileName(file);

    if (fileName.toLowerCase().endsWith('.pdf')) {
      isPdf = true;
    }

    // If it's a PDF, show a PDF icon with the filename
    if (isPdf) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 48, color: Colors.red[700]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                fileName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Handle image files based on platform
    if (kIsWeb) {
      if (file is XFile) {
        return FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Error loading file',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          },
        );
      }
    } else {
      if (file is File) {
        return Image.file(file, fit: BoxFit.cover);
      } else if (file is XFile) {
        return Image.file(File(file.path), fit: BoxFit.cover);
      }
    }

    // Fallback for any other file type
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file, size: 48, color: Colors.blue[700]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
