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
  final File? selectedInvoiceFile;
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
    File? selectedInvoiceFile,
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

  // Select an invoice file from gallery
  Future<void> pickInvoiceFile() async {
    try {
      final file = await _repository.pickImageFromGallery();
      if (file != null) {
        state = state.copyWith(selectedInvoiceFile: file, clearError: true);
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to pick file: ${e.toString()}',
      );
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
