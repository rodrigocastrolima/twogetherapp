import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart' hide Provider;
import '../../../../core/models/service_types.dart'
    as service_types
    show Provider;
import '../../data/repositories/service_submission_repository.dart';

// Provider for the repository
final serviceSubmissionRepositoryProvider =
    Provider<ServiceSubmissionRepository>((ref) {
      return ServiceSubmissionRepository();
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

// State class for the form
class ServiceFormState {
  final ServiceCategory? selectedCategory;
  final EnergyType? selectedEnergyType;
  final ClientType? selectedClientType;
  final service_types.Provider? selectedProvider;
  final List<dynamic> selectedImages;
  final bool isSubmitting;
  final String? errorMessage;

  ServiceFormState({
    this.selectedCategory,
    this.selectedEnergyType,
    this.selectedClientType,
    this.selectedProvider,
    this.selectedImages = const [],
    this.isSubmitting = false,
    this.errorMessage,
  });

  ServiceFormState copyWith({
    ServiceCategory? selectedCategory,
    EnergyType? selectedEnergyType,
    ClientType? selectedClientType,
    service_types.Provider? selectedProvider,
    List<dynamic>? selectedImages,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return ServiceFormState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedEnergyType: selectedEnergyType ?? this.selectedEnergyType,
      selectedClientType: selectedClientType ?? this.selectedClientType,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedImages: selectedImages ?? this.selectedImages,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

// Notifier class for the form
class ServiceFormNotifier extends StateNotifier<ServiceFormState> {
  final ServiceSubmissionRepository _repository;

  ServiceFormNotifier(this._repository) : super(ServiceFormState());

  void setCategory(ServiceCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setEnergyType(EnergyType energyType) {
    state = state.copyWith(selectedEnergyType: energyType);
  }

  void setClientType(ClientType clientType) {
    state = state.copyWith(selectedClientType: clientType);
  }

  void setProvider(service_types.Provider provider) {
    state = state.copyWith(selectedProvider: provider);
  }

  void addImage(dynamic image) {
    state = state.copyWith(selectedImages: [...state.selectedImages, image]);
  }

  void removeImage(int index) {
    final newImages = List<dynamic>.from(state.selectedImages);
    newImages.removeAt(index);
    state = state.copyWith(selectedImages: newImages);
  }

  void clearImages() {
    state = state.copyWith(selectedImages: []);
  }

  void reset() {
    state = ServiceFormState();
  }

  // Pick image from gallery or camera
  Future<void> pickImage({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (pickedImage != null) {
        if (kIsWeb) {
          // For web, use XFile directly
          addImage(pickedImage);
        } else {
          // For mobile, we can use the File
          addImage(File(pickedImage.path));
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      state = state.copyWith(
        errorMessage: 'Failed to pick image: ${e.toString()}',
      );
    }
  }

  Future<bool> submitForm({
    required String companyName,
    required String responsibleName,
    required String nif,
    required String email,
    required String phone,
    bool ignoreInitialValidation = false,
  }) async {
    // Validate required fields - only if not coming from UI with selections
    if (!ignoreInitialValidation) {
      if (state.selectedCategory == null) {
        state = state.copyWith(
          errorMessage: 'Please select a service category',
        );
        return false;
      }

      if (state.selectedCategory == ServiceCategory.energy &&
          state.selectedEnergyType == null) {
        state = state.copyWith(errorMessage: 'Please select an energy type');
        return false;
      }

      if (state.selectedClientType == null) {
        state = state.copyWith(errorMessage: 'Please select a client type');
        return false;
      }

      if (state.selectedProvider == null) {
        state = state.copyWith(errorMessage: 'Please select a provider');
        return false;
      }
    }

    if (state.selectedClientType == ClientType.commercial &&
        companyName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a company name');
      return false;
    }

    if (responsibleName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter the responsible name');
      return false;
    }

    if (nif.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter the NIF');
      return false;
    }

    if (email.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter an email');
      return false;
    }

    if (phone.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a phone number');
      return false;
    }

    if (state.selectedImages.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please upload at least one document image',
      );
      return false;
    }

    // Start submission process
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      // Check for nulls in required fields even with ignoreInitialValidation
      if (state.selectedCategory == null) {
        debugPrint('Error: selectedCategory is null during submission');
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Service category is required',
        );
        return false;
      }

      if (state.selectedClientType == null) {
        debugPrint('Error: selectedClientType is null during submission');
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Client type is required',
        );
        return false;
      }

      if (state.selectedProvider == null) {
        debugPrint('Error: selectedProvider is null during submission');
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Provider is required',
        );
        return false;
      }

      // Create a partial submission to get an ID
      final submission = ServiceSubmission(
        resellerId: 'temp', // Will be replaced by the repository
        resellerName: 'temp', // Will be replaced by the repository
        serviceCategory: state.selectedCategory!,
        energyType: state.selectedEnergyType,
        clientType: state.selectedClientType!,
        provider: state.selectedProvider!,
        companyName: companyName.trim(),
        responsibleName: responsibleName.trim(),
        nif: nif.trim(),
        email: email.trim(),
        phone: phone.trim(),
        documentUrls: [],
      );

      // Save the submission to get an ID
      final submissionId = await _repository.saveSubmission(submission);

      // Upload the images
      debugPrint('Uploading ${state.selectedImages.length} images...');
      final imageUrls = await _repository.uploadImages(
        state.selectedImages,
        submissionId,
      );

      debugPrint('Uploaded ${imageUrls.length} images successfully');

      // Update the submission with the image URLs
      await _repository.updateSubmissionWithImages(submissionId, imageUrls);

      debugPrint('Updated submission with imageUrls and status');

      // Reset the form after successful submission
      reset();

      return true;
    } catch (e) {
      debugPrint('Error submitting form: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to submit: ${e.toString()}',
      );
      return false;
    }
  }
}

// Provider for the form state
final serviceFormProvider =
    StateNotifierProvider<ServiceFormNotifier, ServiceFormState>((ref) {
      final repository = ref.watch(serviceSubmissionRepositoryProvider);
      return ServiceFormNotifier(repository);
    });
