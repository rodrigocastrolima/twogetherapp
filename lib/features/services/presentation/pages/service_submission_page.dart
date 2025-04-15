import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import '../../../../core/models/service_types.dart' as service_types;
import '../../data/repositories/service_submission_repository.dart';
import '../providers/service_submission_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../../core/models/service_submission.dart';
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter/foundation.dart' show kIsWeb;

class ServiceSubmissionPage extends riverpod.ConsumerStatefulWidget {
  const ServiceSubmissionPage({Key? key}) : super(key: key);

  @override
  riverpod.ConsumerState<ServiceSubmissionPage> createState() =>
      _ServiceSubmissionPageState();
}

class _ServiceSubmissionPageState
    extends riverpod.ConsumerState<ServiceSubmissionPage> {
  // TextEditingControllers for form fields
  final TextEditingController _responsibleNameController =
      TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _nifController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // Local state for dropdowns - provider handles validation based on formData map
  service_types.ServiceCategory? _selectedCategory;
  service_types.EnergyType? _selectedEnergyType;
  service_types.ClientType? _selectedClientType;
  service_types.Provider? _selectedProvider;

  @override
  void initState() {
    super.initState();
    // Add listeners to text controllers to update provider state
    _responsibleNameController.addListener(_updateProviderFormData);
    _companyNameController.addListener(_updateProviderFormData);
    _nifController.addListener(_updateProviderFormData);
    _emailController.addListener(_updateProviderFormData);
    _phoneController.addListener(_updateProviderFormData);
  }

  void _updateProviderFormData() {
    ref.read(serviceSubmissionProvider.notifier).updateFormFields({
      'responsibleName': _responsibleNameController.text,
      'companyName': _companyNameController.text,
      'nif': _nifController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
    });
  }

  @override
  void dispose() {
    // Remove listeners before disposing controllers
    _responsibleNameController.removeListener(_updateProviderFormData);
    _companyNameController.removeListener(_updateProviderFormData);
    _nifController.removeListener(_updateProviderFormData);
    _emailController.removeListener(_updateProviderFormData);
    _phoneController.removeListener(_updateProviderFormData);

    _responsibleNameController.dispose();
    _companyNameController.dispose();
    _nifController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Submit form after all validation is complete
  Future<void> _submitForm() async {
    // Form validation is now primarily handled by isFormValidProvider
    // which checks both file and formData in the provider state.
    // We still keep the _formKey validation for immediate UI feedback on text fields.
    if (_formKey.currentState?.validate() != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct errors in the form')),
      );
      return;
    }

    final notifier = ref.read(serviceSubmissionProvider.notifier);

    // Get current user information
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to submit a service request'),
        ),
      );
      return;
    }

    // Submit the form using the notifier
    final success = await notifier.submitServiceRequest(
      resellerId: user.uid,
      resellerName: user.displayName ?? user.email ?? 'Unknown',
    );

    if (success && mounted) {
      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service submission created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Optionally reset form state if staying on page
      // notifier.resetForm();
      Navigator.of(context).pop();
    } else if (!success && mounted) {
      // Error message is already handled by watching the provider state
      // We might show a generic snackbar if needed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(serviceSubmissionProvider).errorMessage ??
                'Submission failed',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the state and validation status from providers
    final state = ref.watch(serviceSubmissionProvider);
    final isFormValid = ref.watch(isFormValidProvider);
    final notifier = ref.read(serviceSubmissionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('New Service Submission')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Dropdown fields --- Update provider state on change
                  const Text(
                    'Service Category',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<service_types.ServiceCategory>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedCategory,
                    hint: const Text('Select Category'),
                    isExpanded: true,
                    items:
                        service_types.ServiceCategory.values
                            .where((category) => category.isAvailable)
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.displayName),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                        notifier.updateFormFields({
                          'serviceCategory':
                              value.name, // Use enum name (string)
                          'energyType':
                              null, // Reset energy type when category changes
                        });
                        // Reset local energy type state too
                        _selectedEnergyType = null;
                      }
                    },
                    validator:
                        (value) =>
                            value == null ? 'Please select a category' : null,
                  ),
                  const SizedBox(height: 16),

                  if (_selectedCategory ==
                      service_types.ServiceCategory.energy) ...[
                    const Text(
                      'Energy Type',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<service_types.EnergyType>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _selectedEnergyType,
                      hint: const Text('Select Energy Type'),
                      isExpanded: true,
                      items:
                          service_types.EnergyType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.displayName),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedEnergyType = value;
                          });
                          notifier.updateFormFields({'energyType': value.name});
                        }
                      },
                      validator:
                          (value) =>
                              value == null
                                  ? 'Please select energy type'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'Client Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<service_types.ClientType>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedClientType,
                    hint: const Text('Select Client Type'),
                    isExpanded: true,
                    items:
                        service_types.ClientType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.displayName),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedClientType = value;
                        });
                        notifier.updateFormFields({'clientType': value.name});
                      }
                    },
                    validator:
                        (value) =>
                            value == null ? 'Please select client type' : null,
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Provider',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<service_types.Provider>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _selectedProvider,
                    hint: const Text('Select Provider'),
                    isExpanded: true,
                    items:
                        service_types.Provider.values.map((
                          service_types.Provider provider,
                        ) {
                          return DropdownMenuItem<service_types.Provider>(
                            value: provider,
                            child: Text(provider.name),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedProvider = value;
                        });
                        notifier.updateFormFields({'provider': value.name});
                      }
                    },
                    validator:
                        (value) =>
                            value == null ? 'Please select provider' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- Text Fields --- Controller listeners update provider state
                  if (_selectedClientType ==
                      service_types.ClientType.commercial) ...[
                    const Text(
                      'Company Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter company name',
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Please enter company name'
                                  : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'Responsible Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _responsibleNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter responsible name',
                    ),
                    validator:
                        (value) =>
                            (value == null || value.isEmpty)
                                ? 'Please enter name'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'NIF',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nifController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter NIF',
                    ),
                    validator:
                        (value) =>
                            (value == null || value.isEmpty)
                                ? 'Please enter NIF'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter email';
                      if (!value.contains('@') || !value.contains('.'))
                        return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Phone',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter phone',
                    ),
                    keyboardType: TextInputType.phone,
                    validator:
                        (value) =>
                            (value == null || value.isEmpty)
                                ? 'Please enter phone'
                                : null,
                  ),
                  const SizedBox(height: 24),

                  // --- REVISED: Invoice Photo Upload Section ---
                  const Text(
                    'Invoice Photo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please upload a photo or PDF of the client invoice',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Column(
                      children: [
                        if (state.selectedInvoiceFile != null) ...[
                          // --- REVISED: Display file preview based on state and type ---
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  // Call the buildFilePreview function
                                  child: buildFilePreview(
                                    state.selectedInvoiceFile,
                                    state.selectedInvoiceFileName,
                                  ),
                                ),
                              ),
                              // Button to remove selected image - Calls notifier
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Remove File',
                                  onPressed: notifier.clearInvoiceFile,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(
                                      0.7,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Optionally display file name
                          if (state.selectedInvoiceFileName != null)
                            Text(
                              state.selectedInvoiceFileName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ] else ...[
                          // Show upload button - Calls notifier
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade100,
                            ),
                            child: Center(
                              child: IconButton(
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                tooltip: 'Select Invoice File',
                                onPressed:
                                    notifier
                                        .pickInvoiceFile, // Call notifier method
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap to upload invoice photo or PDF',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- End of Revised Upload Section ---

                  // Display Error Message from Provider State
                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 16, bottom: 16),
                      color: Colors.red.withOpacity(0.1),
                      width: double.infinity,
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  // Submit Button - Enabled based on isFormValidProvider
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: isFormValid ? _submitForm : null,
                      child: const Text('Submit Service Request'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Loading Overlay
          if (state.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // --- REVISED: File Preview Widget based on Guide ---
  Widget buildFilePreview(dynamic selectedFile, String? fileName) {
    if (selectedFile == null || fileName == null) {
      return const Center(child: Text('No file selected'));
    }

    final lowerCaseFileName = fileName.toLowerCase();
    final isImage =
        lowerCaseFileName.endsWith('.jpg') ||
        lowerCaseFileName.endsWith('.jpeg') ||
        lowerCaseFileName.endsWith('.png') ||
        lowerCaseFileName.endsWith('.heic'); // Added HEIC check

    if (isImage) {
      // Display image preview
      try {
        if (kIsWeb && selectedFile is Uint8List) {
          return Image.memory(
            selectedFile,
            fit: BoxFit.contain,
          ); // Use contain to avoid distortion
        } else if (!kIsWeb && selectedFile is File) {
          return Image.file(selectedFile, fit: BoxFit.contain);
        } else {
          return const Center(child: Text('Invalid image format'));
        }
      } catch (e) {
        print("Error displaying image preview: $e");
        return const Center(child: Text('Error displaying preview'));
      }
    } else if (lowerCaseFileName.endsWith('.pdf')) {
      // For PDFs, show an icon and file name
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.picture_as_pdf,
                size: 50,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Fallback for other file types
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                size: 50,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 12),
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
  }
}
