import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart' as service_types;
import '../../data/repositories/service_submission_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

// Provider for the repository
final serviceSubmissionRepositoryProvider =
    Provider<ServiceSubmissionRepository>((ref) {
      return ServiceSubmissionRepository(
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
        imagePicker: ImagePicker(),
      );
    });

// Provider to check if current user is admin
final isAdminUserProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(serviceSubmissionRepositoryProvider);
  return repository.isCurrentUserAdmin();
});

// Stream provider for user's submissions
final userSubmissionsProvider = StreamProvider<List<ServiceSubmission>>((ref) {
  final repository = ref.watch(serviceSubmissionRepositoryProvider);
  return repository.getSubmissionsForCurrentUser();
});

// Stream provider for all submissions (admin only)
final allSubmissionsProvider = StreamProvider<List<ServiceSubmission>>((ref) {
  final repository = ref.watch(serviceSubmissionRepositoryProvider);
  return repository.getAllSubmissions();
});

// State class to manage the form state
class ServiceSubmissionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final Map<String, dynamic> formData;
  final dynamic
  selectedInvoiceFile; // Changed from File? to dynamic to support both platforms
  final String? submissionId; // ID of the created submission (if successful)

  ServiceSubmissionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    Map<String, dynamic>? formData,
    this.selectedInvoiceFile,
    this.submissionId,
  }) : formData = formData ?? {};

  // Create a copy with updated fields
  ServiceSubmissionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    Map<String, dynamic>? formData,
    dynamic selectedInvoiceFile, // Changed from File? to dynamic
    String? submissionId,
    bool clearError = false,
    bool clearSuccessMessage = false,
    bool clearInvoiceFile = false,
  }) {
    return ServiceSubmissionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      formData: formData ?? Map.from(this.formData),
      selectedInvoiceFile:
          clearInvoiceFile
              ? null
              : (selectedInvoiceFile ?? this.selectedInvoiceFile),
      submissionId: submissionId ?? this.submissionId,
    );
  }
}

// Notifier to manage the state and business logic
class ServiceSubmissionNotifier extends StateNotifier<ServiceSubmissionState> {
  final ServiceSubmissionRepository _repository;

  ServiceSubmissionNotifier(this._repository) : super(ServiceSubmissionState());

  // Update a single form field
  void updateFormField(String fieldName, dynamic value) {
    final updatedFormData = Map<String, dynamic>.from(state.formData);
    updatedFormData[fieldName] = value;
    state = state.copyWith(formData: updatedFormData, clearError: true);
  }

  // Update multiple form fields at once
  void updateFormFields(Map<String, dynamic> fields) {
    final updatedFormData = Map<String, dynamic>.from(state.formData);
    updatedFormData.addAll(fields);
    state = state.copyWith(formData: updatedFormData, clearError: true);
  }

  // Select an invoice file from gallery (image or PDF)
  Future<void> pickInvoiceFile() async {
    try {
      if (kDebugMode) {
        print('Selecting file from device');
      }

      // Allow both images and PDFs using our universal file picker
      final file = await _repository.pickFileFromGallery(
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'heic'],
      );

      if (file != null) {
        if (kDebugMode) {
          String fileInfo = '';
          String fileType = 'unknown';

          if (file is File) {
            fileInfo = file.path;
            final ext = fileInfo.split('.').last.toLowerCase();
            fileType = ext;
          } else if (file is XFile) {
            fileInfo = file.path;
            final ext = fileInfo.split('.').last.toLowerCase();
            fileType = ext;
          }

          print('Successfully selected file: $fileInfo (type: $fileType)');

          // Validate file type here to provide better user feedback
          final validTypes = ['jpg', 'jpeg', 'png', 'pdf', 'heic'];
          if (!validTypes.contains(fileType)) {
            throw Exception(
              'Selected file is not a supported type. Please select a PDF or image file.',
            );
          }
        }

        state = state.copyWith(selectedInvoiceFile: file, clearError: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error selecting file: $e');
      }

      // Provide a user-friendly error message
      String errorMessage = e.toString().replaceAll('Exception: ', '');

      // Special handling for common error cases
      if (e.toString().contains('supported type')) {
        errorMessage = 'Please select a PDF, JPG, PNG or HEIC file.';
      } else if (e.toString().contains('cancelled') ||
          e.toString().contains('canceled')) {
        // Don't show errors for user cancellations
        return;
      }

      state = state.copyWith(
        errorMessage: 'Failed to select file: $errorMessage',
      );
    }
  }

  // Specifically select a PDF file
  Future<dynamic> pickPdfFile() async {
    try {
      if (kDebugMode) {
        print('Picking PDF file - STRICT VERSION');
      }

      // Clear any previous errors
      state = state.copyWith(clearError: true);

      // Use the dedicated method for picking PDF files
      final file = await _repository.pickPdfFromGallery();

      if (file != null) {
        // Validate that it's actually a PDF
        final filePath = file.path.toLowerCase();
        final extension = filePath.split('.').last;

        if (kDebugMode) {
          print('Selected file: $filePath');
          print('File extension: $extension');
        }

        // Make sure it's a PDF
        if (extension != 'pdf' && !filePath.endsWith('.pdf')) {
          if (kDebugMode) {
            print('WARNING: Selected file is not a PDF!');
            print('Extension: $extension');
          }

          // Show an error and don't update the state
          state = state.copyWith(
            errorMessage: 'Please select a PDF file (file extension .pdf).',
          );
          return null;
        }

        if (kDebugMode) {
          print('PDF file validation successful: $filePath');
        }

        // If we got here, it's a valid PDF, so update the state
        state = state.copyWith(selectedInvoiceFile: file, clearError: true);
        return file;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error picking PDF file: $e');
      }

      state = state.copyWith(
        errorMessage: 'Failed to select PDF file. Please try again.',
      );
      return null;
    }
  }

  // Select an invoice file from camera
  Future<void> pickInvoiceFromCamera() async {
    try {
      final file = await _repository.pickImageFromCamera();
      if (file != null) {
        state = state.copyWith(selectedInvoiceFile: file, clearError: true);
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to take photo: ${e.toString()}',
      );
    }
  }

  // Remove the currently selected invoice file
  void clearInvoiceFile() {
    state = state.copyWith(clearInvoiceFile: true);
  }

  // Submit the form data and file
  Future<bool> submitServiceRequest({
    required String resellerId,
    required String resellerName,
  }) async {
    // Validate required fields (can be enhanced based on form requirements)
    if (state.selectedInvoiceFile == null) {
      state = state.copyWith(errorMessage: 'Please select an invoice file');
      return false;
    }

    // Check if form data is complete based on your app's requirements
    // This is just a basic example - you should adapt to your actual required fields
    final formData = state.formData;
    if (!_validateFormData(formData)) {
      state = state.copyWith(
        errorMessage: 'Please fill in all required fields',
      );
      return false;
    }

    // Start loading state
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccessMessage: true,
    );

    try {
      if (kDebugMode) {
        print('Starting service submission request');
        print('Reseller data: id=$resellerId, name=$resellerName');
        print('Form data: $formData');
      }

      // Call repository to submit the request
      final submissionId = await _repository.submitServiceRequest(
        clientDetails: formData,
        invoiceFile: state.selectedInvoiceFile!,
        resellerId: resellerId,
        resellerName: resellerName,
      );

      if (kDebugMode) {
        print('Service submission created with ID: $submissionId');
      }

      // Update state with success
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Service request submitted successfully',
        submissionId: submissionId,
        // Clear the form data and file
        formData: {},
        clearInvoiceFile: true,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting service request: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      // Update state with error
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to submit service request: ${e.toString()}',
      );
      return false;
    }
  }

  // Reset the form to its initial state
  void resetForm() {
    state = ServiceSubmissionState();
  }

  // Private method to validate form data based on requirements
  bool _validateFormData(Map<String, dynamic> data) {
    // These are just example required fields - adapt to your actual requirements
    final requiredFields = [
      'serviceCategory',
      'clientType',
      'provider',
      'responsibleName',
      'nif',
      'email',
      'phone',
    ];

    for (final field in requiredFields) {
      if (!data.containsKey(field) ||
          data[field] == null ||
          data[field] == '') {
        return false;
      }
    }

    // Check if energyType is required based on service category
    if (data['serviceCategory'] == 'energy' &&
        (!data.containsKey('energyType') || data['energyType'] == null)) {
      return false;
    }

    // If client type is commercial, company name is required
    if (data['clientType'] == 'commercial' &&
        (!data.containsKey('companyName') ||
            data['companyName'] == null ||
            data['companyName'] == '')) {
      return false;
    }

    return true;
  }
}

// Provider to access the notifier
final serviceSubmissionProvider =
    StateNotifierProvider<ServiceSubmissionNotifier, ServiceSubmissionState>(
      (ref) => ServiceSubmissionNotifier(
        ref.watch(serviceSubmissionRepositoryProvider),
      ),
    );

// Helper provider to check if the form is valid
final isFormValidProvider = Provider<bool>((ref) {
  final state = ref.watch(serviceSubmissionProvider);

  // Check if we have an invoice file and all required form data
  if (state.selectedInvoiceFile == null) {
    return false;
  }

  // Create a temporary instance of the notifier to use validation logic
  final notifier = ref.read(serviceSubmissionProvider.notifier);
  return notifier._validateFormData(state.formData);
});
