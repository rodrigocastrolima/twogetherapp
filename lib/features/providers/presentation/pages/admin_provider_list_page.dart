import 'dart:io'; // For File
import 'dart:typed_data'; // For Uint8List

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode; // For kIsWeb and kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/loading_service.dart';
import '../../../../core/widgets/message_display.dart';
import '../../../../presentation/widgets/logo.dart';
import '../../../../presentation/widgets/app_loading_indicator.dart'; // Import AppLoadingIndicator
import '../../../../presentation/widgets/success_dialog.dart'; // Import SuccessDialog
import '../../domain/models/provider_file.dart'; // Used in delete logic
import '../../domain/models/provider_info.dart';
import '../providers/provider_providers.dart';

class AdminProviderListPage extends ConsumerStatefulWidget {
  const AdminProviderListPage({super.key});

  @override
  ConsumerState<AdminProviderListPage> createState() =>
      _AdminProviderListPageState();
}

class _AdminProviderListPageState extends ConsumerState<AdminProviderListPage> {
  String? _pageError;
  bool _isDeleteModeEnabled = false;

  void _showAddProviderDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) {
        return const AddProviderDialog();
      },
    );
    // print('Add provider dialog temporarily disabled for debugging.'); // Placeholder action removed
  }

  @override
  Widget build(BuildContext context) {
    final providersAsyncValue = ref.watch(providersStreamProvider);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDarkMode),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0.0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
                    Text(
                      'Dropbox',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    IconButton(
                      icon: Icon(
                        _isDeleteModeEnabled ? CupertinoIcons.xmark : CupertinoIcons.pencil,
                        color: _isDeleteModeEnabled ? theme.colorScheme.error : theme.colorScheme.onSurface,
                        size: 28,
                      ),
                      tooltip: _isDeleteModeEnabled ? 'Cancelar Edição' : 'Editar Pastas',
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
            child: providersAsyncValue.when(
              data: (providers) {
                if (providers.isEmpty) {
                  return const Center(
                        child: Text('Sem pastas. Adicione uma!'),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 1,
                      ),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final provider = providers[index];
                        return _buildProviderSquareCard(context, provider, theme, ref);
                  },
                );
              },
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error:
                  (error, stack) => Center(
                    child: Padding(
                          padding: const EdgeInsets.all(24.0),
                      child: Text(
                            'Erro a carregar pastas $error',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddProviderDialog(context);
        },
        tooltip: 'Nova Pasta',
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

  Widget _buildProviderSquareCard(
    BuildContext context,
    ProviderInfo provider,
    ThemeData theme,
    WidgetRef ref,
  ) {
    // final isDark = theme.brightness == Brightness.dark; // isDark not used
    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          context.push('/admin/providers/${provider.id}', extra: provider);
        },
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                  CachedNetworkImage(
                  imageUrl: provider.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const CupertinoActivityIndicator(),
                    errorWidget: (context, url, error) => Icon(
                      CupertinoIcons.photo,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()), // Lint fix
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                  provider.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (_isDeleteModeEnabled)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: theme.colorScheme.error.withAlpha((255 * 0.7).round()), // Lint fix
                    size: 24,
                ),
                onPressed: () {
                  _confirmAndDeleteProvider(context, ref, provider);
                },
                  tooltip: 'Apagar Pasta',
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteProvider(
    BuildContext context,
    WidgetRef ref,
    ProviderInfo provider,
  ) async {
    setState(() {
      _pageError = null;
    });

    final bool? confirmed = await _showDeleteConfirmationDialog(context, provider.name);

    if (confirmed == true) {
      if (!context.mounted) return;
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AppLoadingIndicator(); 
        },
      );

      try {
        // Delete all files within the provider's folder in Storage
        final storageRef = FirebaseStorage.instance.ref().child('provider_files/${provider.id}');
        final ListResult result = await storageRef.listAll();
        for (final Reference refItem in result.items) { 
          await refItem.delete();
        }
        // If the folder is now empty (or if it was already empty), it might not be explicitly deleted
        // by Firebase Storage automatically if it's just a prefix.
        // However, if there are 'folder placeholder' objects, they would need to be deleted too.
        // For this app, we assume direct file deletions under the prefix are sufficient.

        // Delete the provider document from Firestore
        await FirebaseFirestore.instance.collection('providers').doc(provider.id).delete();

        if (!context.mounted) return;
        Navigator.of(context).pop(); // Dismiss loading indicator

        // Corrected: showSuccessDialog parameters
        showSuccessDialog(
          context: context,
          message: 'A pasta "${provider.name}" e todos os seus ficheiros foram apagados com sucesso.',
          onDismissed: () { 
            // Optional: Any action after the success dialog is dismissed
          },
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Dismiss loading indicator
        if (kDebugMode) {
          print('Error deleting provider or its files: $e');
        }
        setState(() {
          _pageError = 'Erro ao apagar a pasta "${provider.name}": ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao apagar: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Helper method to show the delete confirmation dialog
  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, String providerName) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.all(0), // Remove default title padding
          title: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 60, 0), // Title padding, leave space for close button
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Apagar Pasta?',
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
            'Tem a certeza que quer apagar a pasta "$providerName"? Esta ação não pode ser desfeita.',
            style: textTheme.bodyMedium,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          actionsAlignment: MainAxisAlignment.end,
          actions: <Widget>[
            // Cancelar button removed
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
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }
}

// --- NEW: Stateful Widget for the Add Provider Dialog Content --- //
// --- Removing temporary comments --- Start
class AddProviderDialog extends ConsumerStatefulWidget {
  const AddProviderDialog({super.key});

  @override
  ConsumerState<AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends ConsumerState<AddProviderDialog> {
  final _dialogFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  XFile? _selectedImageFile;
  Uint8List? _webImageBytes;
  bool _isUploading = false;
  String? _dialogErrorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
      setState(() {
      _dialogErrorMessage = null;
    });
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = pickedFile;
          _webImageBytes = null;
        });
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
          });
        }
      }
          } catch (e) {
      if (mounted) {
        setState(() {
          _dialogErrorMessage = 'Error picking image: $e';
        });
      }
    }
  }

  Future<void> _saveProvider() async {
    setState(() {
      _dialogErrorMessage = null;
    });

    if (_dialogFormKey.currentState?.validate() != true) return;

    if (_selectedImageFile == null) {
      setState(() {
        _dialogErrorMessage = 'Por favor, selecione uma imagem para o logótipo.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final providerName = _nameController.text.trim();
      final imageFile = _selectedImageFile!;

      final String fileName =
          'logo_${DateTime.now().millisecondsSinceEpoch}.${imageFile.name.split('.').last}';
      final String providerDocId =
          FirebaseFirestore.instance.collection('providers').doc().id;
      final String storagePath = 'provider_images/$providerDocId/$fileName';
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        storagePath,
      );

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(await imageFile.readAsBytes());
      } else {
        uploadTask = storageRef.putFile(File(imageFile.path));
      }
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      final providerData = {
        'name': providerName,
        'imageUrl': downloadUrl,
        'storagePath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerDocId)
          .set(providerData);

      if (mounted) Navigator.of(context).pop(); // Use current build context
      } catch (e) {
        if (mounted) {
          setState(() {
          _dialogErrorMessage = 'Erro ao guardar pasta: $e';
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

  Widget _buildImagePreview(ThemeData theme) {
    Widget content;
    if (kIsWeb && _webImageBytes != null) {
      content = Image.memory(
        _webImageBytes!,
        fit: BoxFit.cover,
        height: 150,
        width: 150,
      );
    } else if (!kIsWeb && _selectedImageFile != null) {
      content = Image.file(
        File(_selectedImageFile!.path),
        fit: BoxFit.cover,
        height: 150,
        width: 150,
      );
    } else {
      content = Icon(
        CupertinoIcons.photo_fill,
        size: 50,
        color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.all(0), // Remove default title padding
      title: Stack(
        children: [ // Removed alignment: Alignment.topRight for more control
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 60, 0), // Title padding, leave space for close button
            child: Align(
              alignment: Alignment.centerLeft, // Align title text to the left
              child: Text(
                'Adicionar Nova Pasta',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!_isUploading) // Only show close button if not uploading
            Positioned(
              top: 8, // Adjust position for better alignment
              right: 8,
              child: IconButton(
                icon: const Icon(CupertinoIcons.xmark, size: 22),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
                splashRadius: 20,
                padding: const EdgeInsets.all(8), // Standard padding
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: SizedBox( // Constrain dialog width
        width: MediaQuery.of(context).size.width * 0.8, // Example: 80% of screen width
        child: SingleChildScrollView(
          child: Form(
            key: _dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_dialogErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ErrorMessageWidget(message: _dialogErrorMessage!),
                  ),
                
                // Custom styled Text Field
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.folder_badge_plus,
                      color: colorScheme.onSurfaceVariant,
                      size: 20, // Adjust size to match text
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nome da Pasta',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Applying new minimalistic style
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12), // Matches ServicesPage
                    border: Border.all(color: theme.dividerColor.withOpacity(0.4), width: 1), // Matches ServicesPage
                    color: Colors.transparent, // Matches ServicesPage
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    enabled: !_isUploading,
                    style: textTheme.bodyLarge?.copyWith( // Style for the input text itself
                      color: colorScheme.onSurface,
                      // fontWeight: FontWeight.w500, // fontWeight can be inherited or set if needed
                    ),
                    decoration: InputDecoration(
                      hintText: 'Insira o nome da pasta',
                      filled: false, // Explicitly set to false
                      // fillColor: Colors.transparent, // Can also be explicit if needed, but filled: false should suffice
                      border: InputBorder.none, // Key for minimalistic style
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Adjusted to match ServicesPage more closely
                      hintStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.6)), // Matches ServicesPage
                      // prefixIcon removed as the icon is now part of the external label Row
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira o nome da pasta.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Logótipo da Pasta',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                Center(
                  child: SizedBox( // Give SizedBox to parent of Stack to avoid external clipping
                    width: 150 + 16, // Image size + padding for button overflow
                    height: 150 + 16,
                    child: Stack(
                      clipBehavior: Clip.none, // Allow button to overflow slightly if needed
                      alignment: Alignment.center, // Center the main image container
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline.withAlpha((255 * 0.4).round()),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surfaceContainerLowest,
                          ),
                          height: 150,
                          width: 150,
                          child: _buildImagePreview(theme),
                        ),
                        if (!_isUploading)
                          Positioned(
                            right: 0, // Adjusted to be fully visible
                            bottom: 0, // Adjusted to be fully visible
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.secondary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              ),
                              child: IconButton(
                                icon: Icon(CupertinoIcons.add, color: colorScheme.onSecondary, size: 20),
                                onPressed: _pickImage,
                                tooltip: 'Selecionar Imagem',
                                iconSize: 20,
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24), // Spacing before actions
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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                    ),
                  )
                : const Icon(CupertinoIcons.cloud_upload_fill, size: 20),
            label: Text(
              _isUploading ? 'A Guardar...' : 'Guardar Pasta',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: colorScheme.onPrimary, // Explicitly set text color
              ),
            ),
            onPressed: _isUploading ? null : _saveProvider,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary, // This should ideally handle icon color
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// --- Removing temporary comments --- End