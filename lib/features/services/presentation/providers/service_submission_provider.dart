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
  final dynamic selectedInvoiceFile; // Supports File or Uint8List
  final String? selectedInvoiceFileName; // Added to store file name
  final String? submissionId; // ID of the created submission (if successful)

  ServiceSubmissionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    Map<String, dynamic>? formData,
    this.selectedInvoiceFile,
    this.selectedInvoiceFileName, // Added
    this.submissionId,
  }) : formData = formData ?? {};

  // Create a copy with updated fields
  ServiceSubmissionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    Map<String, dynamic>? formData,
    dynamic selectedInvoiceFile,
    String? selectedInvoiceFileName, // Added
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
      selectedInvoiceFileName: // Added
          clearInvoiceFile
              ? null
              : (selectedInvoiceFileName ?? this.selectedInvoiceFileName),
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

  // --- REVISED: Pick invoice file using new repository method ---
  Future<void> pickInvoiceFile() async {
    state = state.copyWith(isLoading: true, clearError: true); // Show loading
    try {
      if (kDebugMode) {
        print('Calling repository.pickFileFromGalleryAndGetName()');
      }
      final result = await _repository.pickFileFromGalleryAndGetName();

      if (result != null) {
        final fileData = result['fileData'];
        final fileName = result['fileName'] as String?;

        if (kDebugMode) {
          print(
            'File picked: Name = $fileName, Type = ${fileData?.runtimeType}',
          );
        }

        if (fileData != null && fileName != null) {
          state = state.copyWith(
            selectedInvoiceFile: fileData,
            selectedInvoiceFileName: fileName,
            isLoading: false,
          );
        } else {
          // Handle case where file picking succeeded but data/name is missing
          if (kDebugMode) print('File picking returned null data or name');
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to get file details.',
          );
        }
      } else {
        // User likely cancelled the picker
        if (kDebugMode) print('File picking cancelled by user.');
        state = state.copyWith(isLoading: false); // Just stop loading, no error
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking file via notifier: $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Failed to select file: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }

  // --- Add method to pick from Camera ---
  Future<void> pickInvoiceFileFromCamera() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (kDebugMode) {
        print('Calling repository.pickImageFromCameraAndGetName()');
      }
      // ASSUMPTION: Repository has a method like pickImageFromCameraAndGetName
      // If not, it needs to be added there using ImagePicker().pickImage(source: ImageSource.camera)
      final result = await _repository.pickImageFromCameraAndGetName();

      if (result != null) {
        final fileData = result['fileData']; // Should be File for mobile camera
        final fileName = result['fileName'] as String?;

        if (kDebugMode) {
          print(
            'Camera image picked: Name = $fileName, Type = ${fileData?.runtimeType}',
          );
        }

        if (fileData is File && fileName != null) {
          // Explicitly check for File type
          state = state.copyWith(
            selectedInvoiceFile: fileData,
            selectedInvoiceFileName: fileName,
            isLoading: false,
          );
        } else {
          if (kDebugMode)
            print('Camera picking returned null data/name or invalid type');
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to get image details from camera.',
          );
        }
      } else {
        if (kDebugMode) print('Camera picking cancelled by user.');
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking file from camera via notifier: $e');
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Failed to use camera: ${e.toString().replaceFirst("Exception: ", "")}',
      );
    }
  }

  // --- OLD/REPLACED PICKERS ---
  // Future<dynamic> pickPdfFile() async { ... }
  // Future<void> pickInvoiceFromCamera() async { ... } // Original commented out

  // --- REVISED: Clear invoice file state ---
  void clearInvoiceFile() {
    state = state.copyWith(
      clearInvoiceFile: true,
    ); // This now clears both file and name
  }

  // --- REVISED: Submit the form data and file ---
  Future<bool> submitServiceRequest({
    required String resellerId,
    required String resellerName,
  }) async {
    // Validate required fields
    if (state.selectedInvoiceFile == null ||
        state.selectedInvoiceFileName == null) {
      state = state.copyWith(errorMessage: 'Please select an invoice file');
      return false;
    }

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
        print('Starting service submission via notifier');
      }

      // Call repository to submit the request, passing the file data AND name
      final submissionId = await _repository.submitServiceRequest(
        clientDetails: formData,
        invoiceFile: state.selectedInvoiceFile!,
        invoiceFileName:
            state.selectedInvoiceFileName!, // Pass the stored file name
        resellerId: resellerId,
        resellerName: resellerName,
      );

      if (kDebugMode) {
        print('Notifier: Submission successful with ID: $submissionId');
      }

      // Update state with success
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Service request submitted successfully',
        submissionId: submissionId,
        // Clear the form data and file
        formData: {}, // Clear form data map
        clearInvoiceFile: true, // Clear file data and name
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Notifier: Error submitting service request: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      // Update state with error
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Failed to submit service request: ${e.toString().replaceFirst("Exception: ", "")}',
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
    // Log the data map being validated
    if (kDebugMode) print('[_validateFormData] Validating data: $data');

    // Basic check for essential fields - Adapt as needed!
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
      final value = data[field];
      // Checks if value is null OR if it's a String that's empty after trimming
      if (value == null || (value is String && value.trim().isEmpty)) {
        // Log specific field failure
        if (kDebugMode)
          print(
            '[_validateFormData] FAILED: Missing or empty required field -> $field',
          );
        return false; // Fails if any required field is missing/empty
      }
    }

    // Conditional validation
    final serviceCategory = data['serviceCategory']?.toString();
    final clientType = data['clientType']?.toString();

    // Check energyType if category is energy
    if (serviceCategory == service_types.ServiceCategory.energy.name) {
      final energyType = data['energyType'];
      // Check if energyType is null OR if it's an empty string
      if (energyType == null ||
          (energyType is String && energyType.trim().isEmpty)) {
        // Log specific field failure
        if (kDebugMode)
          print(
            '[_validateFormData] FAILED: Missing energyType for energy category',
          );
        return false;
      }
    }

    // Check companyName if client type is commercial
    if (clientType == service_types.ClientType.commercial.name) {
      final companyName = data['companyName'];
      // Check if companyName is null OR if it's an empty string
      if (companyName == null ||
          (companyName is String && companyName.trim().isEmpty)) {
        // Log specific field failure
        if (kDebugMode)
          print(
            '[_validateFormData] FAILED: Missing companyName for commercial client',
          );
        return false;
      }
    }

    // Log success if all checks pass
    if (kDebugMode) print('[_validateFormData] PASSED');
    return true; // Passes only if all checks succeed
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

  // Check if we have an invoice file AND file name
  if (state.selectedInvoiceFile == null ||
      state.selectedInvoiceFileName == null) {
    if (kDebugMode)
      print('isFormValidProvider: false (missing file or filename)');
    return false;
  }

  // Use the notifier's internal validation logic for form data
  final notifier = ref.read(serviceSubmissionProvider.notifier);
  final isDataValid = notifier._validateFormData(state.formData);

  if (kDebugMode)
    print('isFormValidProvider: File present, Data valid = $isDataValid');

  return isDataValid; // Return true only if file is present AND form data is valid
});

// --- NEW: Provider to signal success dialog display ---
final showSubmissionSuccessDialogProvider = StateProvider<bool>((ref) => false);
