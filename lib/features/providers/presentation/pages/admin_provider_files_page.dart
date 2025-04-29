import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:firebase_storage/firebase_storage.dart'; // Import storage
import 'package:cloud_firestore/cloud_firestore.dart'; // Import firestore
import 'dart:typed_data'; // Import for Uint8List (web)
import 'dart:io'; // Import for File (mobile)
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/provider_providers.dart';
import '../../domain/models/provider_file.dart';
import '../../../../core/theme/theme.dart'; // For AppTheme colors if needed
import '../../../../core/widgets/message_display.dart'; // For error display
import '../../../../core/services/loading_service.dart'; // For loading overlay

// Convert to ConsumerStatefulWidget
class AdminProviderFilesPage extends ConsumerStatefulWidget {
  final String providerId;
  // final String providerName; // TODO: Pass provider name

  const AdminProviderFilesPage({
    super.key,
    required this.providerId,
    // required this.providerName,
  });

  @override
  ConsumerState<AdminProviderFilesPage> createState() =>
      _AdminProviderFilesPageState();
}

// Create the State class
class _AdminProviderFilesPageState
    extends ConsumerState<AdminProviderFilesPage> {
  @override
  Widget build(BuildContext context) {
    final filesAsyncValue = ref.watch(
      providerFilesStreamProvider(widget.providerId),
    ); // Use widget.providerId
    final theme = Theme.of(context);
    final String appBarTitle = 'Provider Files'; // Placeholder

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: false,
        elevation: 1,
        shadowColor: theme.shadowColor.withOpacity(0.1),
      ),
      body: filesAsyncValue.when(
        data: (files) {
          if (files.isEmpty) {
            return const Center(
              child: Text('No files uploaded for this provider yet.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: files.length,
            separatorBuilder:
                (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: theme.dividerColor.withOpacity(0.5),
                  indent: 16,
                  endIndent: 16,
                ),
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildFileListItem(context, file, theme, ref);
            },
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading files: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddFileDialog(
            context,
            ref,
            widget.providerId,
          ); // Use widget.providerId
        },
        icon: const Icon(CupertinoIcons.add),
        label: const Text('Add File'),
      ),
    );
  }

  // Move _buildFileListItem here (no changes needed inside)
  Widget _buildFileListItem(
    BuildContext context,
    ProviderFile file,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final dateFormatter = DateFormat.yMd().add_jm();
    final fileIcon = _getFileIcon(file.fileType);

    return ListTile(
      leading: Icon(fileIcon, color: theme.colorScheme.primary, size: 28),
      title: Text(
        file.fileName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.description,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Uploaded: ${dateFormatter.format(file.uploadedAt.toDate())}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(CupertinoIcons.delete, color: theme.colorScheme.error),
        onPressed: () {
          _confirmAndDeleteFile(context, ref, file);
        }, // Pass ref
        tooltip: 'Delete File',
      ),
      onTap: () {
        /* Optional tap action */
      },
    );
  }

  // Move _getFileIcon here (no changes needed)
  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return CupertinoIcons.doc_text_fill;
      case 'doc':
      case 'docx':
        return CupertinoIcons.doc_richtext;
      case 'xls':
      case 'xlsx':
        return CupertinoIcons.table_fill;
      case 'ppt':
      case 'pptx':
        return CupertinoIcons.tv_music_note_fill; // Placeholder icon
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return CupertinoIcons.photo_fill;
      case 'zip':
      case 'rar':
        return CupertinoIcons.archivebox_fill;
      default:
        return CupertinoIcons.doc_fill;
    }
  }

  // Move _showAddFileDialog here (will be modified in next step)
  void _showAddFileDialog(
    BuildContext context,
    WidgetRef ref,
    String providerId,
  ) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevent closing by tapping outside while loading
      builder: (context) {
        // Use StatefulWidget for the dialog content to manage its own state
        return AddFileDialog(providerId: providerId);
      },
    );
  }

  // --- MODIFIED: Deletion Logic --- //
  Future<void> _confirmAndDeleteFile(
    BuildContext context,
    WidgetRef ref,
    ProviderFile file,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete File?'),
            content: Text(
              'Are you sure you want to delete "${file.fileName}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final loadingService = ref.read(loadingServiceProvider);
      loadingService.show(context, message: 'Deleting File...');
      bool deletedSuccessfully = false; // Flag for success
      String errorMessage = ''; // Store error message

      try {
        // 1. Delete from Firebase Storage
        await FirebaseStorage.instance.ref(file.storagePath).delete();

        // 2. Delete Firestore document
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(widget.providerId)
            .collection('files')
            .doc(file.id)
            .delete();

        deletedSuccessfully = true; // Mark as success
      } catch (e) {
        errorMessage = 'Error deleting file: $e';
      } finally {
        // Hide loading overlay *before* showing snackbar
        if (mounted) loadingService.hide();
        // Show feedback using ScaffoldMessenger
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deletedSuccessfully
                    ? '\"${file.fileName}\" deleted successfully.'
                    : errorMessage,
              ),
              backgroundColor:
                  deletedSuccessfully
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

// --- NEW: Stateful Widget for the Dialog Content --- //
class AddFileDialog extends ConsumerStatefulWidget {
  final String providerId;
  const AddFileDialog({super.key, required this.providerId});

  @override
  ConsumerState<AddFileDialog> createState() => _AddFileDialogState();
}

class _AddFileDialogState extends ConsumerState<AddFileDialog> {
  final _dialogFormKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  PlatformFile? _selectedPlatformFile;
  bool _isUploading = false;
  String? _dialogErrorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _dialogErrorMessage = null;
    }); // Clear previous error
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _selectedPlatformFile = result.files.first;
        });
      } else {
        // User canceled the picker
      }
    } catch (e) {
      setState(() {
        _dialogErrorMessage = "Error picking file: $e";
      });
    }
  }

  String _getFileExtension(String fileName) {
    try {
      return fileName.split('.').last;
    } catch (e) {
      return '';
    }
  }

  Future<void> _uploadAndSaveFile() async {
    if (_dialogFormKey.currentState?.validate() != true) return;
    if (_selectedPlatformFile == null) {
      setState(() {
        _dialogErrorMessage = 'Please select a file to upload.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _dialogErrorMessage = null;
    });
    final loadingService = ref.read(loadingServiceProvider);
    // Optional: Show overlay for whole app
    // loadingService.show(context, message: 'Uploading File...');

    try {
      final file = _selectedPlatformFile!;
      final String description = _descriptionController.text.trim();
      final String fileName = file.name;
      final String fileExtension = _getFileExtension(fileName);
      final int? fileSize = file.size; // Size might be null

      // Generate Firestore ID first
      final String fileDocId =
          FirebaseFirestore.instance
              .collection('providers')
              .doc(widget.providerId)
              .collection('files')
              .doc()
              .id;

      final String storagePath =
          'provider_files/${widget.providerId}/$fileDocId/$fileName';
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        storagePath,
      );

      UploadTask uploadTask;
      if (kIsWeb) {
        final fileBytes = file.bytes;
        if (fileBytes == null)
          throw Exception('File bytes are null for web upload');
        uploadTask = storageRef.putData(fileBytes);
      } else {
        final filePath = file.path;
        if (filePath == null)
          throw Exception('File path is null for mobile upload');
        uploadTask = storageRef.putFile(File(filePath));
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Create Firestore Document
      final fileData = {
        'fileName': fileName,
        'description': description,
        'downloadUrl': downloadUrl,
        'fileType': fileExtension.toLowerCase(),
        'size': fileSize,
        'uploadedAt': FieldValue.serverTimestamp(),
        'storagePath': storagePath,
      };

      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .collection('files')
          .doc(fileDocId)
          .set(fileData);

      if (mounted) Navigator.pop(context); // Close dialog on success
    } catch (e) {
      if (mounted) {
        setState(() {
          _dialogErrorMessage = 'Error uploading file: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        // loadingService.hide(); // Hide overlay if shown
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add New File'),
      content: SingleChildScrollView(
        child: Form(
          key: _dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_dialogErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ErrorMessageWidget(message: _dialogErrorMessage!),
                ),

              // File Picker Button & Display
              Text('File', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(CupertinoIcons.folder_open),
                    label: Text(
                      _selectedPlatformFile == null
                          ? 'Select File'
                          : 'Change File',
                    ),
                    onPressed: _isUploading ? null : _pickFile,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedPlatformFile?.name ?? 'No file selected',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                enabled: !_isUploading,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon:
              _isUploading
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                  : const Icon(CupertinoIcons.cloud_upload_fill, size: 18),
          label: Text(_isUploading ? 'Uploading...' : 'Upload & Save'),
          onPressed: _isUploading ? null : _uploadAndSaveFile,
        ),
      ],
    );
  }
}
