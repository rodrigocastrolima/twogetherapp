import 'dart:io';

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
import '../../../../core/theme/app_colors.dart';

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
    // On web, always pick from files. On mobile, PopupMenuButton handles the options
    notifier.pickInvoiceFile();
  }

  // --- Method to show mobile picker options (using PopupMenuButton style like chat) ---
  void _showMobilePickerOptions(BuildContext context, WidgetRef ref) {
    // This method is now replaced by the PopupMenuButton in the build method
    // We'll keep it for backwards compatibility but it won't be used
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final l10n = AppLocalizations.of(context)!; // Remove l10n init
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isLightMode = theme.brightness == Brightness.light;

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
              // Add PopupMenuButton here (like chat page)
              if (kIsWeb) ...[
                // On web, use simple IconButton
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
              ] else ...[
                // On mobile, use PopupMenuButton like chat page
                Theme(
                  data: Theme.of(context).copyWith(
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, -110), // Position above the button
                    elevation: 8,
                    color: isLightMode ? Colors.white : const Color(0xFF3A3A3A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      CupertinoIcons.add_circled,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'camera',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.camera, size: 18, color: AppColors.foreground(isLightMode ? Brightness.light : Brightness.dark)),
                              const SizedBox(width: 12),
                              Text('Câmera', style: TextStyle(color: AppColors.foreground(isLightMode ? Brightness.light : Brightness.dark))),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'gallery',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.photo, size: 18, color: AppColors.foreground(isLightMode ? Brightness.light : Brightness.dark)),
                              const SizedBox(width: 12),
                              Text('Galeria', style: TextStyle(color: AppColors.foreground(isLightMode ? Brightness.light : Brightness.dark))),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onSelected: (String value) {
                      final notifier = ref.read(serviceSubmissionProvider.notifier);
                      switch (value) {
                        case 'camera':
                          notifier.pickInvoiceFileFromCamera();
                          break;
                        case 'gallery':
                          notifier.pickInvoiceFile();
                          break;
                      }
                    },
                  ),
                ),
              ],
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
              border: Border.all(
                color: isLightMode 
                    ? colorScheme.outline.withAlpha((255 * 0.6).round())
                    : theme.dividerColor.withAlpha((255 * 0.5).round()),
                width: isLightMode ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isLightMode 
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest,
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withAlpha((255 * 0.3).round()),
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
                      color: colorScheme.errorContainer.withAlpha((255 * 0.9).round()),
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
