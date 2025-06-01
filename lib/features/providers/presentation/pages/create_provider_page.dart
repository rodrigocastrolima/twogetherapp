import 'dart:io';
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart'; // Use image_picker for simplicity first
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
// Removed snackbar import
// import 'package:twogether/core/utils/show_snackbar.dart';
// Import the new message widgets
import '../../../../core/widgets/message_display.dart';

// REMOVE State provider for loading status
// final _createProviderLoadingProvider = StateProvider<bool>((ref) => false);

class CreateProviderPage extends ConsumerStatefulWidget {
  const CreateProviderPage({super.key});

  @override
  ConsumerState<CreateProviderPage> createState() => _CreateProviderPageState();
}

class _CreateProviderPageState extends ConsumerState<CreateProviderPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  XFile? _selectedImageFile;
  // For web image display if using image_picker
  Uint8List? _webImageBytes;

  // Local state for loading and messages
  bool _isLoading = false;
  String? _errorMessage;
  // Success message state is optional as we pop on success
  // String? _successMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _errorMessage = null; // Clear error when picking
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
          _errorMessage = 'Error picking image: $e';
        });
      }
    }
  }

  Future<void> _saveProvider() async {
    // Clear previous error message
    setState(() {
      _errorMessage = null;
    });

    if (_formKey.currentState?.validate() != true) return;

    if (_selectedImageFile == null) {
      setState(() {
        _errorMessage = 'Please select a provider image.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });
    // Optional: Use loading service overlay
    // final loadingService = ref.read(loadingServiceProvider);
    // if (mounted) loadingService.show(context, message: 'Saving Provider...');

    try {
      final providerName = _nameController.text.trim();
      final imageFile = _selectedImageFile!;

      // 1. Upload Image to Firebase Storage
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

      // 2. Create Firestore Document
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

      // Successfully saved, pop back
      if (mounted && context.canPop()) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error saving provider: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // if (mounted) loadingService.hide(); // Hide overlay if shown
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Provider'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isLoading ? null : _saveProvider, // Use local state
              child:
                  _isLoading
                      ? const SizedBox(
                        // Show smaller indicator in button
                        width: 20,
                        height: 20,
                        child: CupertinoActivityIndicator(),
                      )
                      : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Error Message Widget if error exists
              if (_errorMessage != null)
                ErrorMessageWidget(message: _errorMessage!),

              // Name Field
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading, // Disable form fields when loading
                decoration: const InputDecoration(
                  labelText: 'Provider Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(CupertinoIcons.building_2_fill),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a provider name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Image Picker Section
              Text('Provider Logo/Image', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    // Image Preview
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withAlpha((255 * 0.5).round()),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: theme.colorScheme.secondaryContainer.withAlpha(
                          (255 * 0.1).round(),
                        ),
                      ),
                      height: 150,
                      width: 150,
                      child: _buildImagePreview(theme),
                    ),
                    const SizedBox(height: 12),
                    // Pick Image Button
                    ElevatedButton.icon(
                      // Disable button when loading
                      onPressed: _isLoading ? null : _pickImage,
                      icon: const Icon(CupertinoIcons.photo_on_rectangle),
                      label: const Text('Select Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _webImageBytes!,
          fit: BoxFit.cover,
          height: 150,
          width: 150,
        ),
      );
    } else if (!kIsWeb && _selectedImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_selectedImageFile!.path),
          fit: BoxFit.cover,
          height: 150,
          width: 150,
        ),
      );
    } else {
      return Center(
        child: Icon(
          CupertinoIcons.photo_fill,
          size: 50,
          color: theme.colorScheme.secondaryContainer,
        ),
      );
    }
  }
}
