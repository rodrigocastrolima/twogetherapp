import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart'; // Unnecessary import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'dart:ui'; // Unnecessary import
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/service_submission_provider.dart';
// import '../../../../core/theme/ui_styles.dart'; // Unused import

// Define callback types
typedef OnFilePickedCallback = void Function(dynamic fileData, String fileName);
typedef OnFileClearedCallback = void Function();

/// Widget for uploading documents and photos
class FileUploadWidget extends ConsumerWidget {
  final dynamic selectedFile; // Can be File (mobile) or Uint8List (web)
  final String? selectedFileName;
  // Remove callbacks as we now use provider methods directly
  // final OnFilePickedCallback onFilePicked;
  // final OnFileClearedCallback onFileCleared;

  const FileUploadWidget({
    Key? key,
    required this.selectedFile,
    required this.selectedFileName,
    // required this.onFilePicked,
    // required this.onFileCleared,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(serviceSubmissionProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // l10n.serviceSubmissionInvoicePhotoLabel, // Replaced with default
          'Invoice Photo / PDF',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          // l10n.serviceSubmissionInvoicePhotoHint, // Replaced with default
          'Upload a photo or PDF of the invoice',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              if (selectedFile != null && selectedFileName != null) ...[
                // Ensure selectedFileName is not null before passing
                _buildFilePreview(context, selectedFile, selectedFileName!, () {
                  // Call notifier directly to clear the file
                  notifier.clearInvoiceFile();
                }),
                const SizedBox(height: 8),
                // Optionally display file name below preview
                // Text(selectedFileName!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ] else ...[
                // Upload Placeholder
                Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        // Combined Upload Button
                        ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          // label: Text(l10n.serviceSubmissionSelectFileButton), // Replaced with default
                          label: const Text('Select File'),
                          style: ElevatedButton.styleFrom(
                            // backgroundColor: theme.colorScheme.secondaryContainer,
                            // foregroundColor: theme.colorScheme.onSecondaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            textStyle: theme.textTheme.labelMedium,
                          ),
                          onPressed: () {
                            // Call the unified picker method
                            notifier.pickInvoiceFile();
                          },
                        ),
                        // Removed Camera Button - Use gallery picker for now
                        // const SizedBox(height: 8),
                        // TextButton.icon(
                        //   icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        //   label: const Text('Use Camera'),
                        //   onPressed: () {
                        //      // TODO: Implement or remove camera functionality
                        //      // For now, calls gallery picker
                        //      notifier.pickInvoiceFile(); // Replaced pickInvoiceFromCamera
                        //   },
                        // ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  // l10n.serviceSubmissionSelectFileHint, // Replaced with default
                  'Tap button to upload photo or PDF',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- File Preview Widget Logic (copied & adapted from ServiceSubmissionPage) ---
  Widget _buildFilePreview(
    BuildContext context,
    dynamic selectedFile,
    String fileName, // Made non-nullable based on call site check
    VoidCallback onRemovePressed,
  ) {
    final theme = Theme.of(context);
    final lowerCaseFileName = fileName.toLowerCase();
    final isImage =
        lowerCaseFileName.endsWith('.jpg') ||
        lowerCaseFileName.endsWith('.jpeg') ||
        lowerCaseFileName.endsWith('.png') ||
        lowerCaseFileName.endsWith('.heic');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 250), // Limit preview height
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11), // Inner radius
            child:
                isImage
                    ? _buildImagePreview(selectedFile)
                    : _buildPdfPreview(context, fileName),
          ),
          // Remove Button Overlay
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onRemovePressed,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(dynamic selectedFile) {
    try {
      if (kIsWeb && selectedFile is Uint8List) {
        return Image.memory(selectedFile, fit: BoxFit.contain);
      } else if (!kIsWeb && selectedFile is File) {
        return Image.file(selectedFile, fit: BoxFit.contain);
      } else {
        return _buildErrorPreview('Invalid image data type');
      }
    } catch (e) {
      debugPrint("Error building image preview: $e");
      return _buildErrorPreview('Cannot display preview');
    }
  }

  Widget _buildPdfPreview(BuildContext context, String fileName) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                fileName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Removed redundant button - use overlay X button
            // TextButton.icon(
            //   icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
            //   label: const Text("Choose PDF"),
            //   onPressed: () {
            //     // Call unified picker method
            //     ref.read(serviceSubmissionProvider.notifier).pickInvoiceFile(); // Replaced pickPdfFile
            //   },
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPreview(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          message,
          style: TextStyle(color: Colors.red[700]),
        ), // Darker red for visibility
      ),
    );
  }
}
