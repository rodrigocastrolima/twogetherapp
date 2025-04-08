import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import '../../../../core/models/service_types.dart' as service_types;
import '../../data/repositories/service_submission_repository.dart';
import '../providers/service_submission_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../../core/models/service_submission.dart';

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

  service_types.ServiceCategory? _selectedCategory;
  service_types.EnergyType? _selectedEnergyType;
  service_types.ClientType? _selectedClientType;
  service_types.Provider? _selectedProvider;

  XFile? _invoicePhoto;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _responsibleNameController.dispose();
    _companyNameController.dispose();
    _nifController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Submit form after all validation is complete
  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final notifier = ref.read(serviceSubmissionProvider.notifier);

    // Update form data with text field values that might not be in the form state yet
    notifier.updateFormFields({
      'responsibleName': _responsibleNameController.text,
      'companyName': _companyNameController.text,
      'nif': _nifController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
    });

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

    // Submit the form
    final success = await notifier.submitServiceRequest(
      resellerId: user.uid,
      resellerName: user.displayName ?? user.email ?? 'Unknown',
    );

    if (success && mounted) {
      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service submission created successfully'),
        ),
      );

      // After successful submission, you may want to navigate back or to a confirmation page
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _invoicePhoto = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the state
    final state = ref.watch(serviceSubmissionProvider);
    final isFormValid = ref.watch(isFormValidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Service Submission')),
      body:
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Category Dropdown
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
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a service category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Energy Type Field (only show if category is Energy)
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
                            }
                          },
                          validator: (value) {
                            if (_selectedCategory ==
                                    service_types.ServiceCategory.energy
                                        .toString()
                                        .split('.')
                                        .last &&
                                value == null) {
                              return 'Please select an energy type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Client Type Dropdown
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
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a client type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Provider Dropdown (use our local enum, not the provider from riverpod)
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
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a provider';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Company Name TextField (conditional on client type)
                      if (_selectedClientType ==
                          service_types.ClientType.commercial
                              .toString()
                              .split('.')
                              .last) ...[
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
                          validator: (value) {
                            if (_selectedClientType ==
                                    service_types.ClientType.commercial
                                        .toString()
                                        .split('.')
                                        .last &&
                                (value == null || value.isEmpty)) {
                              return 'Please enter company name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Responsible Name TextField
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter responsible name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // NIF TextField
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter NIF';
                          }
                          // Optional: Add specific NIF format validation
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email TextField
                      const Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter email address',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          // Simple email validation
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone TextField
                      const Text(
                        'Phone',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter phone number',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter phone number';
                          }
                          // Optional: Add phone format validation
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Invoice Photo Upload Section
                      const Text(
                        'Invoice Photo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please upload a photo of the client invoice',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Invoice Photo Upload Button and Preview
                      Center(
                        child: Column(
                          children: [
                            if (_invoicePhoto != null) ...[
                              // Show image preview
                              Stack(
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
                                      child: Image.file(
                                        File(_invoicePhoto!.path),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  // Button to remove selected image
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Remove'),
                                      onPressed: () {
                                        setState(() {
                                          _invoicePhoto = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Show upload button
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade100,
                                ),
                                child: Center(
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tap to upload invoice photo',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Error Message (if any)
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.red.shade100,
                          width: double.infinity,
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],

                      // Submit Button
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
                          onPressed:
                              isFormValid && !state.isLoading
                                  ? _submitForm
                                  : null,
                          child: const Text('Submit Service Request'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
    );
  }
}
