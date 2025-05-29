import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart' as service_types;
import '../../data/repositories/service_submission_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

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

@immutable
class ServiceSubmissionState {
  final String? serviceCategory;
  final String? energyType;
  final String? clientType;
  final String? provider;
  final String? companyName;
  final String? responsibleName;
  final String? nif;
  final String? email;
  final String? phone;
  final List<PlatformFile> selectedFiles;
  final bool isSubmitting;
  final String? errorMessage;
  final bool submissionSuccess;

  const ServiceSubmissionState({
    this.serviceCategory,
    this.energyType,
    this.clientType,
    this.provider,
    this.companyName,
    this.responsibleName,
    this.nif,
    this.email,
    this.phone,
    this.selectedFiles = const [],
    this.isSubmitting = false,
    this.errorMessage,
    this.submissionSuccess = false,
  });

  ServiceSubmissionState copyWith({
    String? serviceCategory,
    String? energyType,
    String? clientType,
    String? provider,
    String? companyName,
    ValueGetter<String?>? responsibleName,
    ValueGetter<String?>? nif,
    ValueGetter<String?>? email,
    ValueGetter<String?>? phone,
    List<PlatformFile>? selectedFiles,
    bool? isSubmitting,
    ValueGetter<String?>? errorMessage,
    bool? submissionSuccess,
  }) {
    return ServiceSubmissionState(
      serviceCategory: serviceCategory ?? this.serviceCategory,
      energyType: energyType ?? this.energyType,
      clientType: clientType ?? this.clientType,
      provider: provider ?? this.provider,
      companyName: companyName ?? this.companyName,
      responsibleName:
          responsibleName != null ? responsibleName() : this.responsibleName,
      nif: nif != null ? nif() : this.nif,
      email: email != null ? email() : this.email,
      phone: phone != null ? phone() : this.phone,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      submissionSuccess: submissionSuccess ?? this.submissionSuccess,
    );
  }
}

class ServiceSubmissionNotifier extends StateNotifier<ServiceSubmissionState> {
  final ServiceSubmissionRepository _repository;
  final ImagePicker _picker = ImagePicker();

  ServiceSubmissionNotifier(this._repository)
    : super(const ServiceSubmissionState());

  void updateFormFields(Map<String, String?> fields) {
    state = state.copyWith(
      serviceCategory:
          fields.containsKey('serviceCategory')
              ? fields['serviceCategory']
              : state.serviceCategory,
      energyType:
          fields.containsKey('energyType')
              ? fields['energyType']
              : state.energyType,
      clientType:
          fields.containsKey('clientType')
              ? fields['clientType']
              : state.clientType,
      provider:
          fields.containsKey('provider') ? fields['provider'] : state.provider,
      companyName:
          fields.containsKey('companyName')
              ? fields['companyName']
              : state.companyName,
      responsibleName:
          () =>
              fields.containsKey('responsibleName')
                  ? fields['responsibleName']
                  : state.responsibleName,
      nif: () => fields.containsKey('nif') ? fields['nif'] : state.nif,
      email: () => fields.containsKey('email') ? fields['email'] : state.email,
      phone: () => fields.containsKey('phone') ? fields['phone'] : state.phone,
    );
  }

  Future<void> pickInvoiceFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'heic'],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final currentFiles = state.selectedFiles;
        final newFiles = result.files;
        state = state.copyWith(selectedFiles: [...currentFiles, ...newFiles]);
        debugPrint(
          'Selected files: ${state.selectedFiles.map((f) => f.name).toList()}',
        );
      } else {
        debugPrint('File picking cancelled or no files selected.');
      }
    } catch (e) {
      debugPrint('Error picking file(s): $e');
    }
  }

  Future<void> pickInvoiceFileFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final bytes = kIsWeb ? await photo.readAsBytes() : null;
        final platformFile = PlatformFile(
          name: photo.name,
          path: kIsWeb ? null : photo.path,
          bytes: bytes,
          size: await photo.length(),
        );

        final currentFiles = state.selectedFiles;
        state = state.copyWith(selectedFiles: [...currentFiles, platformFile]);
        debugPrint('Added camera file: ${platformFile.name}');
        debugPrint(
          'Selected files: ${state.selectedFiles.map((f) => f.name).toList()}',
        );
      } else {
        debugPrint('Camera picking cancelled.');
      }
    } catch (e) {
      debugPrint('Error picking file from camera: $e');
    }
  }

  void removeFile(int index) {
    if (index < 0 || index >= state.selectedFiles.length) return;
    final currentFiles = List<PlatformFile>.from(state.selectedFiles);
    final removedFile = currentFiles.removeAt(index);
    state = state.copyWith(selectedFiles: currentFiles);
    debugPrint('Removed file: ${removedFile.name}');
    debugPrint(
      'Remaining files: ${state.selectedFiles.map((f) => f.name).toList()}',
    );
  }

  void resetForm() {
    state = const ServiceSubmissionState();
  }

  Future<bool> submitServiceRequest({
    required String resellerId,
    required String resellerName,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: () => null,
      submissionSuccess: false,
    );

    // 1. Generate unique submission ID/Ref beforehand using Firestore
    final docRef = _repository.getNewSubmissionReference(); // Use repo method
    final submissionId = docRef.id;

    try {
      List<String> attachmentUrls = [];

      // 2. --- Upload Loop (Using updated Repository method) ---
      if (state.selectedFiles.isEmpty) {
        throw Exception(
          "No files selected for upload.",
        ); // Should be caught by validation, but safety check
      }

      for (int i = 0; i < state.selectedFiles.length; i++) {
        final file = state.selectedFiles[i];
        try {
          // Call the actual repository upload method
          final downloadUrl = await _repository.uploadServiceAttachment(
            submissionId, // Pass the generated ID
            i, // Pass the file index
            file, // Pass the PlatformFile object
          );
          attachmentUrls.add(downloadUrl);
          debugPrint('Uploaded ${file.name}, URL: $downloadUrl');

          // Remove simulation block
          // await Future.delayed(const Duration(milliseconds: 100));
          // final simulatedUrl = 'gs://your-bucket/submissions/$resellerId/file_${i}_${file.name}';
          // attachmentUrls.add(simulatedUrl);
          // debugPrint('Simulated upload for ${file.name}, URL: $simulatedUrl');
        } catch (e) {
          debugPrint('Error uploading file ${file.name}: $e');
          // Add more context to the error message shown to the user
          throw Exception(
            'Failed to upload file: ${file.name}. Error: ${e.toString()}',
          );
        }
      }
      // --- End Upload Loop ---

      // 5. Save the final submission data
      final finalData = {
        // Spread individual fields instead of formData map
        'serviceCategory': state.serviceCategory,
        'energyType': state.energyType,
        'clientType': state.clientType,
        'provider': state.provider,
        'companyName': state.companyName,
        'responsibleName': state.responsibleName,
        'nif': state.nif,
        'email': state.email,
        'phone': state.phone,
        // Add other necessary fields
        'submissionTimestamp': FieldValue.serverTimestamp(),
        'resellerId': resellerId,
        'resellerName': resellerName,
        'attachmentUrls': attachmentUrls,
        'status': 'pending_review', // Ensure this EXACT string is used
      };

      await _repository.saveFinalSubmission(
        docRef, // Pass the reference
        finalData,
        resellerName, // Pass details for notification
        state.responsibleName ?? 'N/A',
        state.serviceCategory ?? 'N/A',
        state.energyType,
        state.clientType,
      );

      // 5. Update state on success
      state = state.copyWith(isSubmitting: false, submissionSuccess: true);
      resetForm(); // Reset form on success
      return true;
    } catch (e) {
      debugPrint('Error submitting service request: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: () => e.toString(),
        submissionSuccess: false,
      );
      return false;
    }
  }
}

final serviceSubmissionProvider =
    StateNotifierProvider<ServiceSubmissionNotifier, ServiceSubmissionState>((
      ref,
    ) {
      final repository = ref.watch(serviceSubmissionRepositoryProvider);
      return ServiceSubmissionNotifier(repository);
    });

final isFormValidProvider = Provider<bool>((ref) {
  final state = ref.watch(serviceSubmissionProvider);

  bool baseValid =
      state.serviceCategory != null &&
      state.responsibleName != null &&
      state.responsibleName!.isNotEmpty &&
      state.nif != null &&
      state.nif!.isNotEmpty &&
      state.email != null &&
      state.email!.isNotEmpty &&
      state.phone != null &&
      state.phone!.isNotEmpty;

  if (state.clientType == 'Commercial') {
    baseValid =
        baseValid &&
        (state.companyName != null && state.companyName!.isNotEmpty);
  }

  bool fileValid = state.selectedFiles.isNotEmpty;

  return baseValid && fileValid;
});

final showSubmissionSuccessDialogProvider = StateProvider<bool>((ref) => false);
