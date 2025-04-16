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

  // --- Method to trigger file picking logic (handles platform differences) ---
  void _triggerFilePick(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(serviceSubmissionProvider.notifier);
    if (kIsWeb) {
      notifier.pickInvoiceFile();
    } else {
      _showMobilePickerOptions(context, ref);
    }
  }

  // --- Method to show mobile picker options ---
  void _showMobilePickerOptions(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(serviceSubmissionProvider.notifier);

    showModalBottomSheet(
      context: context,
      // Optional: Customize bottom sheet appearance
      // backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.fileUploadOptionGallery),
                onTap: () {
                  Navigator.of(context).pop(); // Close bottom sheet
                  notifier.pickInvoiceFile(); // Call gallery/file picker
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(l10n.fileUploadOptionCamera),
                onTap: () {
                  Navigator.of(context).pop(); // Close bottom sheet
                  notifier.pickInvoiceFileFromCamera(); // Call camera picker
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: Text(l10n.fileUploadOptionCancel),
                onTap: () => Navigator.of(context).pop(), // Just close
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // REMOVED Title Text and SizedBox

        // --- Upload Placeholder OR File Preview ---
        if (selectedFile == null) ...[
          // --- Centered Box Placeholder ---
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _triggerFilePick(context, ref),
                    child: Text(
                      l10n.fileUploadHint, // Use l10n key
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // --- Replaced Button with IconButton ---
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    iconSize: 40, // Make icon larger
                    color: theme.colorScheme.primary, // Use primary color
                    tooltip:
                        l10n.fileUploadButtonLabel, // Reuse button label for tooltip
                    onPressed: () => _triggerFilePick(context, ref),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16), // Spacing after placeholder box
        ] else ...[
          // --- File Preview ---
          _buildFilePreview(context, ref, selectedFile!, selectedFileName!, () {
            ref.read(serviceSubmissionProvider.notifier).clearInvoiceFile();
          }),
          const SizedBox(height: 16), // Spacing after preview
        ],
      ],
    );
  }

  // --- File Preview Widget Logic (minor changes for l10n) ---
  Widget _buildFilePreview(
    BuildContext context,
    WidgetRef ref,
    dynamic selectedFile,
    String fileName,
    VoidCallback onRemovePressed,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final lowerCaseFileName = fileName.toLowerCase();
    final isImage =
        lowerCaseFileName.endsWith('.jpg') ||
        lowerCaseFileName.endsWith('.jpeg') ||
        lowerCaseFileName.endsWith('.png') ||
        lowerCaseFileName.endsWith('.heic');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child:
                isImage
                    ? _buildImagePreview(selectedFile)
                    : _buildPdfPreview(context, fileName),
          ),
          // Remove Button Overlay
          Positioned(
            top: 4,
            right: 4,
            child: Tooltip(
              message: l10n.fileUploadRemoveTooltip, // Use l10n key
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
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPreview(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message, style: TextStyle(color: Colors.red[700])),
      ),
    );
  }
}
