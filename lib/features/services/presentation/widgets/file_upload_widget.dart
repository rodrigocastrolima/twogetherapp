import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Import Cupertino
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
  // Remove parameters as state is read via ref
  // final dynamic selectedFile;
  // final String? selectedFileName;

  // Make the constructor const and parameterless
  const FileUploadWidget({Key? key}) : super(key: key);

  // --- Method to trigger file picking logic (handles platform differences) ---
  void _triggerFilePick(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(serviceSubmissionProvider.notifier);
    if (kIsWeb) {
      notifier.pickInvoiceFile();
    } else {
      // Use platform-specific picker options for mobile
      if (Platform.isIOS || Platform.isAndroid) {
        // Be explicit about mobile
      _showMobilePickerOptions(context, ref);
      } else {
        // Fallback for other non-web platforms if needed
        notifier.pickInvoiceFile();
      }
    }
  }

  // --- Method to show mobile picker options (using CupertinoActionSheet) ---
  void _showMobilePickerOptions(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(serviceSubmissionProvider.notifier);

    // Use CupertinoActionSheet for iOS look and feel
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext modalContext) {
        final cupertinoTheme = CupertinoTheme.of(modalContext);
        return CupertinoActionSheet(
          // title: Text(l10n.fileUploadSelectSourceTitle), // Optional title
          // message: Text(l10n.fileUploadSelectSourceMessage), // Optional message
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.photo_on_rectangle,
                    size: 22,
                    color: cupertinoTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.fileUploadOptionGallery,
                    style: cupertinoTheme.textTheme.actionTextStyle,
                  ),
                ],
              ),
              onPressed: () {
                Navigator.pop(modalContext);
                notifier.pickInvoiceFile();
                },
              ),
            CupertinoActionSheetAction(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.camera,
                    size: 22,
                    color: cupertinoTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.fileUploadOptionCamera,
                    style: cupertinoTheme.textTheme.actionTextStyle,
                  ),
                ],
              ),
              onPressed: () {
                Navigator.pop(modalContext);
                notifier.pickInvoiceFileFromCamera();
                },
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(
              l10n.fileUploadOptionCancel,
              style: cupertinoTheme.textTheme.actionTextStyle.copyWith(
                color: CupertinoColors.systemRed,
              ),
            ),
            onPressed: () {
              Navigator.pop(modalContext);
            },
          ),
        );
      },
    );

    /* // Original showModalBottomSheet code - removed
    showModalBottomSheet(
      context: context,
      // ... (styling) ...
      builder: (BuildContext bc) {
        // ... (ListTiles) ...
      },
    );
    */
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Read the list of selected files from the provider
    final files = ref.watch(serviceSubmissionProvider).selectedFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Combined Add/Display Box ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16), // Consistent padding
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
            color:
                colorScheme.surfaceContainerHighest, // Use a subtle background
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              // --- Conditional Hint Text ---
              if (files.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                    l10n.fileUploadHint,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

              // --- List of Selected Files (if any) ---
              // Use ClipRect to prevent overflow if list gets long before scrolling is added
              if (files.isNotEmpty)
                ClipRect(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 150,
                    ), // Limit height inside box
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        // Use a simpler tile or row inside the box
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                _getFileIcon(file.name),
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: textTheme.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                                visualDensity:
                                    VisualDensity
                                        .compact, // Make IconButton smaller
                                padding: EdgeInsets.zero,
                                tooltip: l10n.fileUploadRemoveTooltip,
                                onPressed: () {
                                  ref
                                      .read(serviceSubmissionProvider.notifier)
                                      .removeFile(index);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Separator if files exist
              if (files.isNotEmpty) const SizedBox(height: 12),

              // --- Always visible Add Button ---
                  IconButton(
                icon: Icon(
                  CupertinoIcons.add_circled,
                  size: 36,
                  color: colorScheme.primary,
                ),
                tooltip: l10n.fileUploadButtonLabel,
                    onPressed: () => _triggerFilePick(context, ref),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  // Helper function to determine file icon
  IconData _getFileIcon(String fileName) {
    final lowerCaseFileName = fileName.toLowerCase();
    if (lowerCaseFileName.endsWith('.pdf')) {
      return CupertinoIcons.doc_text_fill;
    } else if (lowerCaseFileName.endsWith('.jpg') ||
        lowerCaseFileName.endsWith('.jpeg') ||
        lowerCaseFileName.endsWith('.png') ||
        lowerCaseFileName.endsWith('.heic')) {
      return CupertinoIcons.photo_fill;
      } else {
      return CupertinoIcons.doc_fill; // Default document icon
    }
  }

  // --- File Preview Widget Logic (REMOVED as previews are now in the list) ---
  // Widget _buildFilePreview(...) { ... }
  // Widget _buildImagePreview(...) { ... }
  // Widget _buildPdfPreview(...) { ... }
  // Widget _buildErrorPreview(...) { ... }
}
