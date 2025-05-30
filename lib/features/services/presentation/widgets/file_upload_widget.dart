import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Import Cupertino
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Remove import
// import 'dart:ui'; // Unnecessary import
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/service_submission_provider.dart';
// import '../../../../core/theme/ui_styles.dart'; // Unused import
import 'package:file_picker/file_picker.dart'; // Ensure PlatformFile is available
import '../../../../core/services/file_icon_service.dart'; // Import FileIconService
import 'package:path/path.dart' as p; // For file extension handling

// Define callback types
typedef OnFilePickedCallback = void Function(dynamic fileData, String fileName);
typedef OnFileClearedCallback = void Function();

/// Widget for uploading documents and photos
class FileUploadWidget extends ConsumerWidget {
  // Remove parameters as state is read via ref
  // final dynamic selectedFile;
  // final String? selectedFileName;

  // Make the constructor const and parameterless
  const FileUploadWidget({super.key});

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
    // final l10n = AppLocalizations.of(context)!; // Remove l10n init
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
                    'Galeria', // Replaced l10n.fileUploadOptionGallery
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
                    'Câmera', // Replaced l10n.fileUploadOptionCamera
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
              'Cancelar', // Replaced l10n.fileUploadOptionCancel
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
    // final l10n = AppLocalizations.of(context)!; // Remove l10n init
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Read the list of selected files from the provider
    final files = ref.watch(serviceSubmissionProvider).selectedFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label for the upload section - Now includes the add button
        Padding(
          padding: const EdgeInsets.only(
            left: 4.0, // Align with text field labels
            right: 0, // No right padding needed here
            bottom: 8.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                // l10n.fileUploadSectionTitle, // Add a key for this in .arb files
                'Anexar Documentos', // Replaced Placeholder title with Portuguese
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              // Add IconButton here
              IconButton(
                icon: Icon(
                  CupertinoIcons.add_circled,
                  color: colorScheme.primary,
                ),
                padding: EdgeInsets.zero, // Remove default padding
                constraints:
                    const BoxConstraints(), // Remove default constraints
                visualDensity: VisualDensity.compact, // Make it smaller
                tooltip:
                    'Carregar Fatura', // Replaced l10n.fileUploadButtonLabel
                onPressed: () => _triggerFilePick(context, ref),
              ),
            ],
          ),
        ),
        // --- Combined Add/Display Box ---
        GestureDetector(
          onTap: () => _triggerFilePick(context, ref),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12), // Slightly reduced padding
            constraints: const BoxConstraints(
              minHeight: 150,
            ), // Ensure minimum height
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
              color:
                  colorScheme
                      .surfaceContainerHighest, // Use a subtle background
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Allow column to shrink
              mainAxisAlignment: MainAxisAlignment.center, // Center hint text
              children: [
                // --- Grid/Wrap for Previews --- (No Add Button here anymore)
                if (files.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 0,
                    ), // No bottom padding needed if files exist
                    child: Wrap(
                      spacing: 8.0, // Horizontal spacing between items
                      runSpacing: 8.0, // Vertical spacing between lines
                      children: List.generate(files.length, (index) {
                        return _buildFilePreview(
                          context,
                          ref,
                          files[index],
                          index,
                        );
                      }),
                      // _buildAddButton removed from here
                    ),
                  ),

                // --- Hint Text (Show only when no files) ---
                if (files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Carregue uma foto ou PDF da fatura', // Replaced l10n.fileUploadHint
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Widget Builder for individual file preview ---
  Widget _buildFilePreview(
    BuildContext context,
    WidgetRef ref,
    PlatformFile file,
    int index,
  ) {
    // final l10n = AppLocalizations.of(context)!; // Remove l10n init
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isImage = _isImageFile(file.name);
    final filePath =
        kIsWeb ? null : file.path; // path is only available on mobile

    // Use a fixed size for the preview container
    const double previewSize = 70.0;

    return SizedBox(
      width: previewSize,
      height: previewSize, // Only height for content, remove button space
      child: Stack(
        clipBehavior: Clip.none, // Allow overflow for the button
        children: [
          // --- Content: Image or Icon/Text ---
          Positioned.fill(
            child: Container(
              width: previewSize,
              height: previewSize,
              clipBehavior: Clip.antiAlias, // Clip the image/icon
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child:
                  isImage && (filePath != null || (kIsWeb && file.bytes != null))
                      ? (kIsWeb && file.bytes != null
                          ? Image.memory(
                              file.bytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 30,
                                ),
                              ),
                            )
                          : Image.file(
                              File(filePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 30,
                                ),
                              ),
                            ))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // Prevent stretching
                          children: [
                            Image.asset(
                              FileIconService.getIconAssetPath(
                                (p.extension(file.name).isEmpty) 
                                    ? '' 
                                    : p.extension(file.name).substring(1).toLowerCase(),
                              ),
                              width: 30,
                              height: 30,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                CupertinoIcons.doc_text_fill,
                                color: colorScheme.onSurfaceVariant,
                                size: 30,
                              ),
                            ),
                            // Removed filename display from here for cleaner preview
                          ],
                        ),
            ),
          ),

          // --- Remove Button ---
          Positioned(
            top: -8, // Adjust position to overlap slightly
            right: -8,
            child: Tooltip(
              // Wrap with Tooltip
              message: 'Remover ficheiro', // Use message parameter for Tooltip
              child: Material(
                // Use Material for InkWell effect
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ref
                        .read(serviceSubmissionProvider.notifier)
                        .removeFile(index);
                  },
                  // tooltip: 'Remover ficheiro', // Removed from InkWell
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 14, // Smaller icon
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to determine file icon - Updated to use FileIconService
  Widget _getFileIcon(String fileName, {double size = 30}) {
    final extension = p.extension(fileName);
    final fileExtension = extension.isEmpty ? '' : extension.substring(1).toLowerCase();
    
    return Image.asset(
      FileIconService.getIconAssetPath(fileExtension),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        CupertinoIcons.doc_text_fill,
        size: size,
      ),
    );
  }

  // Helper function to check if a file is an image based on extension
  bool _isImageFile(String fileName) {
    final lowerCaseFileName = fileName.toLowerCase();
    return lowerCaseFileName.endsWith('.jpg') ||
        lowerCaseFileName.endsWith('.jpeg') ||
        lowerCaseFileName.endsWith('.png') ||
        lowerCaseFileName.endsWith('.gif') || // Added gif
        lowerCaseFileName.endsWith('.heic') || // Added heic
        lowerCaseFileName.endsWith('.webp'); // Added webp
  }
}

// TODO: Add l10n key 'fileUploadSectionTitle' to app_en.arb, app_es.arb, app_pt.arb
// Example for app_en.arb:
// "fileUploadSectionTitle": "Attach Documents",
// "@fileUploadSectionTitle": {
//   "description": "Label for the file upload section in the service form"
// }
