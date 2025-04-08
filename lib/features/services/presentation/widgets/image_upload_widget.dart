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

class ImageUploadWidget extends ConsumerWidget {
  const ImageUploadWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(serviceSubmissionProvider);
    final formNotifier = ref.read(serviceSubmissionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and instructions
        Text(
          'Upload Documents',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload photos of the invoice or any other relevant documents',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.foreground.withAlpha(
              (0.7 * 255).round(),
            ), // Updated from withOpacity
          ),
        ),
        const SizedBox(height: 16),

        // Image grid with add button
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

              // Show add button
              if (formState.selectedInvoiceFile == null)
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: _buildAddButton(context, formNotifier),
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

  Widget _buildAddButton(
    BuildContext context,
    ServiceSubmissionNotifier formNotifier,
  ) {
    return InkWell(
      onTap: () => _showImageSourceDialog(context, formNotifier),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 80,
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
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 28,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Add Document',
              style: TextStyle(fontSize: 14, color: AppTheme.foreground),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(
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
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  formNotifier.pickInvoiceFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
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
        // Image preview
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey[200],
            width: double.infinity,
            height: double.infinity,
            child: _buildImageWidget(image),
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

  Widget _buildImageWidget(dynamic image) {
    if (kIsWeb) {
      if (image is XFile) {
        return FutureBuilder<Uint8List>(
          future: image.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Icon(Icons.error, color: Colors.red));
            }

            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          },
        );
      }
    } else {
      if (image is File) {
        return Image.file(image, fit: BoxFit.cover);
      } else if (image is XFile) {
        return Image.file(File(image.path), fit: BoxFit.cover);
      }
    }

    // Fallback for unsupported image types
    return const Center(
      child: Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}
