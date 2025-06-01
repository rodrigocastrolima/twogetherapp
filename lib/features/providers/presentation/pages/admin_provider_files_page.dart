import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:firebase_storage/firebase_storage.dart'; // Import storage
import 'package:cloud_firestore/cloud_firestore.dart'; // Import firestore
import 'dart:io'; // Import for File (mobile)
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode; // Added kDebugMode
import '../providers/provider_providers.dart';
import '../../domain/models/provider_file.dart';
import '../../../../core/widgets/message_display.dart'; // For error display // For loading overlay
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget
import '../../../../presentation/widgets/app_loading_indicator.dart'; // Import AppLoadingIndicator
import '../../../../presentation/widgets/success_dialog.dart'; // Import SuccessDialog
import 'package:url_launcher/url_launcher.dart';
import '../../../../presentation/widgets/full_screen_image_viewer.dart';
import '../../../../presentation/widgets/full_screen_pdf_viewer.dart';
import '../../../../presentation/widgets/simple_list_item.dart';
import '../../../../presentation/widgets/app_input_field.dart';
import '../../../../core/services/file_icon_service.dart';

// Convert to ConsumerStatefulWidget
class AdminProviderFilesPage extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName; // Added providerName

  const AdminProviderFilesPage({
    super.key,
    required this.providerId,
    required this.providerName, // Added providerName
  });

  @override
  ConsumerState<AdminProviderFilesPage> createState() =>
      _AdminProviderFilesPageState();
}

// Create the State class
class _AdminProviderFilesPageState
    extends ConsumerState<AdminProviderFilesPage> {
  bool _isDeleteModeEnabled = false; // Added for delete mode
  String? _pageError; // Added for page-level errors

  @override
  Widget build(BuildContext context) {
    final filesAsyncValue = ref.watch(
      providerFilesStreamProvider(widget.providerId),
    ); // Use widget.providerId
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDark),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0.0,
      ),
      body: Center( // Center content horizontally
        child: ConstrainedBox( // Constrain content width
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.providerName, // Use providerName for title
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isDeleteModeEnabled ? CupertinoIcons.xmark : CupertinoIcons.pencil,
                        color: _isDeleteModeEnabled ? theme.colorScheme.error : theme.colorScheme.onSurface,
                        size: 28,
                      ),
                      tooltip: _isDeleteModeEnabled ? 'Cancelar Edição' : 'Editar Ficheiros',
                      onPressed: () {
                        setState(() {
                          _isDeleteModeEnabled = !_isDeleteModeEnabled;
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (_pageError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: ErrorMessageWidget(message: _pageError!),
                ),
              Expanded(
                child: filesAsyncValue.when(
                  data: (files) {
                    if (files.isEmpty) {
                      return const Center(
                        child: Text('Nenhuns ficheiros para esta pasta.'),
                      );
                    }
                    return ListView.builder( // Changed from ListView.separated
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      itemCount: files.length,
                      // separatorBuilder removed
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return _buildFileListItem(context, file, theme, ref);
                      },
                    );
                  },
                  loading: () => const Center(child: CupertinoActivityIndicator()),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Erro ao carregar ficheiros: $error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton( // Changed to simple FAB
        onPressed: () {
          _showAddFileDialog(
            context,
            ref,
            widget.providerId,
          );
        },
        tooltip: 'Adicionar Ficheiro', // Changed tooltip
        backgroundColor: theme.colorScheme.primary,
        elevation: 2.0,
        shape: const CircleBorder(),
        child: Icon(
          CupertinoIcons.add,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  // Add file tap handler
  Future<void> _handleFileTap(BuildContext context, ProviderFile file) async {
    final fileType = file.fileType.toLowerCase();
    final url = Uri.parse(file.downloadUrl);

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileType)) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImageViewer(imageUrl: file.downloadUrl, imageName: file.fileName), fullscreenDialog: true));
    } else if (fileType == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenPdfViewer(pdfUrl: file.downloadUrl, pdfName: file.fileName), fullscreenDialog: true));
    } else {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o link do ficheiro: $e')));
        }
      }
    }
  }

  // Update _buildFileListItem to use SimpleListItem
  Widget _buildFileListItem(
    BuildContext context,
    ProviderFile file,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final iconAsset = FileIconService.getIconAssetPath(file.fileType);
    return SimpleListItem(
      leading: Image.asset(
        iconAsset,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
      ),
      title: file.fileName,
      subtitle: file.description.isNotEmpty ? file.description : null,
      trailing: _isDeleteModeEnabled
          ? IconButton(
                icon: Icon(CupertinoIcons.xmark_circle_fill, color: theme.colorScheme.error, size: 24),
                onPressed: () {
                  _confirmAndDeleteFile(context, ref, file);
                },
                tooltip: 'Apagar Ficheiro',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
          : Icon(
                CupertinoIcons.chevron_forward,
                color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.6).round()),
                size: 20,
              ),
      onTap: () => _handleFileTap(context, file),
    );
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
    setState(() {
      _pageError = null; // Clear previous page error
    });

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) { // Use dialogContext for Navigator.pop
        final theme = Theme.of(dialogContext); // Use theme from dialogContext
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.all(0),
          title: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 60, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Apagar Ficheiro?',
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(CupertinoIcons.xmark, color: colorScheme.onSurface.withAlpha(150)),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  tooltip: 'Cancelar',
                  splashRadius: 20,
                ),
              ),
            ],
          ),
          content: Text(
            'Tem a certeza que quer apagar o ficheiro "${file.fileName}"? Esta ação não pode ser desfeita.',
            style: textTheme.bodyMedium,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Apagar', style: textTheme.labelLarge?.copyWith(color: colorScheme.onError, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      }
    );

    if (confirmed == true) {
      if (!context.mounted) return; // Check mount status after await

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AppLoadingIndicator(); // Use AppLoadingIndicator
        },
      );

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
        
        if (!context.mounted) return; 
        Navigator.of(context).pop(); // Dismiss loading indicator

        showSuccessDialog(
          context: context,
          message: 'O ficheiro "${file.fileName}" foi apagado com sucesso.',
          onDismissed: () {},
        );

      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Dismiss loading indicator
        if (kDebugMode) {
          print('Error deleting file: $e');
        }
        final errorMessage = 'Erro ao apagar o ficheiro: ${e.toString()}';
        setState(() {
          _pageError = errorMessage; // Show error at page level
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _selectedPlatformFile = result.files.first;
        });
      }
    } catch (e) {
      setState(() {
        _dialogErrorMessage = "Erro ao selecionar ficheiro: $e";
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
        _dialogErrorMessage = 'Por favor, selecione um ficheiro para upload.';
      });
      return;
    }
    setState(() {
      _isUploading = true;
      _dialogErrorMessage = null;
    });
    try {
      final file = _selectedPlatformFile!;
      final String description = _descriptionController.text.trim();
      final String fileName = file.name;
      final String fileExtension = _getFileExtension(fileName);
      final int fileSize = file.size;
      final String fileDocId = FirebaseFirestore.instance.collection('providers').doc(widget.providerId).collection('files').doc().id;
      final String storagePath = 'provider_files/${widget.providerId}/$fileDocId/$fileName';
      final Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask;
      if (kIsWeb) {
        final fileBytes = file.bytes;
        if (fileBytes == null) throw Exception('File bytes are null for web upload');
        uploadTask = storageRef.putData(fileBytes);
      } else {
        final filePath = file.path;
        if (filePath == null) throw Exception('File path is null for mobile upload');
        uploadTask = storageRef.putFile(File(filePath));
      }
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      final fileData = {
        'fileName': fileName,
        'description': description,
        'downloadUrl': downloadUrl,
        'fileType': fileExtension.toLowerCase(),
        'size': fileSize,
        'uploadedAt': FieldValue.serverTimestamp(),
        'storagePath': storagePath,
      };
      await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).collection('files').doc(fileDocId).set(fileData);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _dialogErrorMessage = 'Erro ao fazer upload: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildFilePicker(ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ficheiro',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            if (_selectedPlatformFile == null)
              IconButton(
                icon: Icon(CupertinoIcons.add, color: colorScheme.primary, size: 28),
                tooltip: 'Adicionar ficheiro',
                onPressed: _isUploading ? null : _pickFile,
                splashRadius: 22,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedPlatformFile != null)
          Center(
            child: _buildFilePreview(_selectedPlatformFile!, theme, colorScheme, textTheme),
          ),
      ],
    );
  }

  Widget _buildFilePreview(PlatformFile file, ThemeData theme, ColorScheme colorScheme, TextTheme textTheme) {
    final iconAsset = FileIconService.getIconAssetPath(file.extension);
    return Container(
      width: 80,
      height: 80,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.7).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withAlpha((255 * 0.1).round()),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    iconAsset,
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file.name,
                    style: textTheme.bodySmall?.copyWith(fontSize: 9),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (!_isUploading)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.08).round()),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: colorScheme.error,
                  tooltip: 'Remover ficheiro',
                  onPressed: () {
                    setState(() {
                      _selectedPlatformFile = null;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.all(0),
      title: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 60, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Adicionar Novo Ficheiro',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!_isUploading)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(CupertinoIcons.xmark, size: 22),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
                splashRadius: 20,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_dialogErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ErrorMessageWidget(message: _dialogErrorMessage!),
                  ),
                _buildFilePicker(theme, colorScheme, textTheme),
                const SizedBox(height: 20),
                AppInputField(
                  controller: _descriptionController,
                  label: 'Descrição',
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira uma descrição';
                    }
                    return null;
                  },
                  readOnly: _isUploading,
                ),
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _isUploading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(CupertinoIcons.cloud_upload_fill, size: 18),
            label: Text(_isUploading ? 'A fazer upload...' : 'Guardar Ficheiro'),
            onPressed: _isUploading ? null : _uploadAndSaveFile,
          ),
        ),
      ],
    );
  }
}
