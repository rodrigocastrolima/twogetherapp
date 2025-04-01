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
  const ImageUploadWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(serviceFormProvider);
    final formNotifier = ref.read(serviceFormProvider.notifier);

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
            color: AppTheme.foreground.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),

        // Image grid with add button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Show images if there are any
              if (formState.selectedImages.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: formState.selectedImages.length,
                  itemBuilder: (context, index) {
                    return _buildImagePreview(
                      context,
                      formState.selectedImages[index],
                      onDelete: () => formNotifier.removeImage(index),
                    );
                  },
                ),

              // Show add button
              if (formState.selectedImages.isEmpty ||
                  formState.selectedImages.length < 5)
                Padding(
                  padding: EdgeInsets.only(
                    top: formState.selectedImages.isNotEmpty ? 16 : 0,
                  ),
                  child: _buildAddButton(context, formNotifier),
                ),
            ],
          ),
        ),

        // Error message
        if (formState.errorMessage != null &&
            formState.errorMessage!.contains('image')) ...[
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
    ServiceFormNotifier formNotifier,
  ) {
    return InkWell(
      onTap: () => _showImageSourceDialog(context, formNotifier),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
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
    ServiceFormNotifier formNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.background.withOpacity(0.95),
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
                  formNotifier.pickImage(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  formNotifier.pickImage(source: ImageSource.gallery);
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
                color: Colors.black.withOpacity(0.7),
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
