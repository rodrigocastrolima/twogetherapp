import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../../core/models/notification.dart';

// Callback type for notification creation
typedef NotificationCreationCallback = void Function();

class ServiceSubmissionRepository {
  // Static callback that can be set to refresh notifications when created
  static NotificationCreationCallback? onNotificationCreated;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker;

  ServiceSubmissionRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required ImagePicker imagePicker,
  }) : _firestore = firestore,
       _storage = storage,
       _imagePicker = imagePicker;

  // Collection references
  final CollectionReference _submissionsCollection = FirebaseFirestore.instance
      .collection('serviceSubmissions');
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    if (currentUserId == null) return null;

    try {
      final userDoc = await _usersCollection.doc(currentUserId).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Save a new service submission (Note: This only saves metadata, upload happens separately now)
  Future<String> saveSubmissionMetadata(ServiceSubmission submission) async {
    try {
      if (kDebugMode) {
        print('Saving submission metadata...');
      }

      final userData = await getCurrentUserData();
      if (userData == null) throw Exception('User data not found');

      final updatedSubmission = submission.copyWith(
        resellerId: currentUserId!,
        resellerName: userData['displayName'] ?? 'Unknown Reseller',
      );

      final docRef = await _submissionsCollection.add(
        updatedSubmission.toFirestore(),
      );
      final submissionId = docRef.id;

      if (kDebugMode) {
        print('Submission metadata created with ID: $submissionId');
      }

      // // Notification creation moved to after successful upload in submitServiceRequest
      // await _createSubmissionNotification(
      //   submissionId,
      //   updatedSubmission.resellerName,
      //   updatedSubmission.responsibleName,
      //   updatedSubmission.serviceCategory.displayName,
      // );

      return submissionId;
    } catch (e) {
      if (kDebugMode) print('Error saving submission metadata: $e');
      throw Exception('Failed to save submission metadata: $e');
    }
  }

  // --- NEW: Unified File Picker from Guide ---
  Future<Map<String, dynamic>?> pickFileFromGalleryAndGetName() async {
    try {
      if (kDebugMode) {
        print('Opening unified file picker');
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: kIsWeb, // Request byte data for web platform
      );

      if (result != null && result.files.single != null) {
        final pickedFile = result.files.single;
        final fileName = pickedFile.name; // Get the original file name

        dynamic fileData;
        if (kIsWeb) {
          fileData = pickedFile.bytes; // Uint8List for web
        } else {
          if (pickedFile.path == null) {
            throw Exception("File path is null on mobile platform");
          }
          fileData = File(pickedFile.path!); // File object for mobile
        }

        if (fileData == null) return null; // If bytes are null on web

        return {'fileData': fileData, 'fileName': fileName};
      } else {
        // No file selected
        return null;
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      throw Exception(
        "Error picking file: $e",
      ); // Re-throw to be caught by notifier
    }
  }

  // --- ADD: Pick Image from Camera ---
  Future<Map<String, dynamic>?> pickImageFromCameraAndGetName() async {
    // Camera is not supported on web
    if (kIsWeb) {
      throw UnsupportedError(
        "Camera access is not supported on the web platform.",
      );
    }

    try {
      if (kDebugMode) {
        print('Opening camera');
      }
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        // Optionally set image quality, max width/height if needed
        // imageQuality: 80,
        // maxWidth: 1024,
      );

      if (pickedFile != null) {
        final fileName = path.basename(pickedFile.path);
        final fileData = File(pickedFile.path); // File object for mobile

        return {'fileData': fileData, 'fileName': fileName};
      } else {
        // User cancelled camera
        return null;
      }
    } catch (e) {
      debugPrint("Error picking image from camera: $e");
      throw Exception(
        "Error picking image from camera: $e",
      ); // Re-throw to be caught by notifier
    }
  }

  // --- NEW: Firebase Upload Function from Guide ---
  Future<String> uploadFileToFirebase(
    dynamic fileData,
    String submissionId,
    String fileName,
  ) async {
    // Construct the storage path; e.g., submissions/{submissionId}/{fileName}
    final storagePath = 'submissions/$submissionId/$fileName';
    final storageRef = _storage.ref().child(storagePath);
    UploadTask uploadTask;

    try {
      SettableMetadata? metadata;
      // Determine content type based on filename extension
      final extension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      if (extension == 'pdf') {
        metadata = SettableMetadata(contentType: 'application/pdf');
      } else if (['jpg', 'jpeg'].contains(extension)) {
        metadata = SettableMetadata(contentType: 'image/jpeg');
      } else if (extension == 'png') {
        metadata = SettableMetadata(contentType: 'image/png');
      } else if (extension == 'heic') {
        metadata = SettableMetadata(
          contentType: 'image/heic',
        ); // Optional: HEIC support
      }

      if (kIsWeb) {
        // For web, fileData is expected to be Uint8List
        if (fileData is Uint8List) {
          uploadTask = storageRef.putData(fileData, metadata);
        } else {
          throw Exception(
            "Invalid file data type for web upload. Expected Uint8List.",
          );
        }
      } else {
        // For mobile, fileData is a File instance
        if (fileData is File) {
          uploadTask = storageRef.putFile(fileData, metadata);
        } else {
          throw Exception(
            "Invalid file data type for mobile upload. Expected File.",
          );
        }
      }

      // Wait for the upload to complete
      final snapshot = await uploadTask;
      // Get and return the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (kDebugMode) {
        print('File uploaded successfully: $downloadUrl');
      }
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print("Error uploading file: $e");
        print("Stack trace: ${StackTrace.current}");
      }
      throw Exception("Error uploading file: $e");
    }
  }

  // Get submissions for the current user
  Stream<List<ServiceSubmission>> getSubmissionsForCurrentUser() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _submissionsCollection
        .where('resellerId', isEqualTo: currentUserId)
        .orderBy('submissionTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ServiceSubmission.fromFirestore(doc))
              .toList();
        });
  }

  // Get all submissions (for admin users)
  Stream<List<ServiceSubmission>> getAllSubmissions() {
    return _submissionsCollection
        .orderBy('submissionTimestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ServiceSubmission.fromFirestore(doc))
              .toList();
        });
  }

  // Update submission status
  Future<void> updateSubmissionStatus(
    String submissionId,
    String newStatus,
  ) async {
    try {
      final submissionDoc =
          await _submissionsCollection.doc(submissionId).get();
      if (!submissionDoc.exists) throw Exception('Submission not found');

      final data = submissionDoc.data() as Map<String, dynamic>;
      final oldStatus = data['status'] ?? 'unknown';
      final resellerId = data['resellerId'] ?? '';
      final clientName =
          data['responsibleName'] ??
          'Client'; // Assuming responsibleName is client name

      await _submissionsCollection.doc(submissionId).update({
        'status': newStatus,
        // Optionally add a timestamp for status update
        // 'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for the reseller
      if (resellerId.isNotEmpty && oldStatus != newStatus) {
        await NotificationRepository().createStatusChangeNotification(
          userId: resellerId,
          submissionId: submissionId,
          oldStatus: oldStatus,
          newStatus: newStatus,
          clientName: clientName,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error updating submission status: $e');
      rethrow;
    }
  }

  // Delete an image from storage (kept as it might be useful)
  Future<void> deleteImageFromUrl(String imageUrl) async {
    // Note: This requires the storage path to be derivable from the URL,
    // which might not always be the case depending on URL format/rules.
    // A more robust approach stores the storagePath alongside the URL.
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      debugPrint('Deleted image from storage: $imageUrl');
    } catch (e) {
      debugPrint('Error deleting image from storage URL: $e');
      // Don't throw, allow deletion from Firestore array even if storage fails
    }
  }

  // Check if user is admin
  Future<bool> isCurrentUserAdmin() async {
    if (currentUserId == null) return false;
    try {
      final userDoc = await _usersCollection.doc(currentUserId).get();
      // Cast data() result to Map before accessing the key
      return userDoc.exists &&
          (userDoc.data() as Map<String, dynamic>?)?['role'] == 'admin';
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Pick an image from camera (kept, but might need update for web consistency)
  Future<dynamic> pickImageFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75, // Moderate quality for reasonable file size
      );

      if (pickedFile == null) return null;

      // Return the appropriate type based on platform
      if (kIsWeb) {
        // For web, return the XFile directly (consistent with picker logic)
        // Upload function needs to handle XFile.readAsBytes()
        return pickedFile;
      } else {
        // For mobile, convert to File
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      throw Exception('Failed to pick image: $e');
    }
  }

  // Get download URL for a storage path (kept)
  Future<String> getDownloadUrlForPath(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      final downloadUrl = await ref.getDownloadURL();
      print("Generated download URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("Error getting download URL: $e");
      throw Exception("Failed to get download URL: $e");
    }
  }

  // --- REVISED: submitServiceRequest using new upload function ---
  Future<String> submitServiceRequest({
    required Map<String, dynamic> clientDetails,
    required dynamic invoiceFile, // Supports File or Uint8List
    required String invoiceFileName, // Need the original file name
    required String resellerId,
    required String resellerName,
  }) async {
    // Cast clientDetails to the correct type for safety
    final details = clientDetails as Map<String, dynamic>;

    // 1. Generate a new document reference to get the submission ID
    final docRef = _firestore.collection('serviceSubmissions').doc();
    final submissionId = docRef.id;

    // 2. Upload the file using the new function
    // Ensure the file name is unique or handled appropriately if needed
    final uniqueFileName =
        '${DateTime.now().millisecondsSinceEpoch}_$invoiceFileName';
    final downloadUrl = await uploadFileToFirebase(
      invoiceFile,
      submissionId,
      uniqueFileName, // Use the unique name for storage path
    );

    // 3. Determine content type from the original file name
    final extension =
        uniqueFileName.contains('.')
            ? uniqueFileName.split('.').last.toLowerCase()
            : '';
    String contentType = 'application/octet-stream'; // Default
    if (extension == 'pdf') {
      contentType = 'application/pdf';
    } else if (['jpg', 'jpeg'].contains(extension)) {
      contentType = 'image/jpeg';
    } else if (extension == 'png') {
      contentType = 'image/png';
    } else if (extension == 'heic') {
      contentType = 'image/heic';
    }

    // 4. Create the invoice photo metadata
    final invoicePhoto = InvoicePhoto(
      // Use the derived storage path used in uploadFileToFirebase
      storagePath: 'submissions/$submissionId/$uniqueFileName',
      fileName: uniqueFileName, // Store the potentially modified unique name
      contentType: contentType,
      uploadedTimestamp: Timestamp.now(),
      uploadedBy: resellerId,
    );

    // 5. Create the service submission object
    // Use the casted 'details' map here
    final serviceCategory = _getEnumValueFromString(
      ServiceCategory.values,
      details['serviceCategory']?.toString() ?? '', // Ensure string comparison
    );
    final energyType =
        details['energyType'] != null
            ? _getEnumValueFromString(
              EnergyType.values,
              details['energyType']?.toString() ?? '',
            )
            : null;
    final clientType = _getEnumValueFromString(
      ClientType.values,
      details['clientType']?.toString() ?? '',
    );
    final serviceProvider = _getEnumValueFromString(
      Provider.values,
      details['provider']?.toString() ?? '',
    );

    final submission = ServiceSubmission(
      id: submissionId,
      resellerId: resellerId,
      resellerName: resellerName,
      serviceCategory: serviceCategory ?? ServiceCategory.energy,
      energyType: energyType,
      clientType: clientType ?? ClientType.residential,
      provider: serviceProvider ?? Provider.repsol,
      companyName: details['companyName'], // Use 'details' map
      responsibleName: details['responsibleName'] ?? '',
      nif: details['nif'] ?? '',
      email: details['email'] ?? '',
      phone: details['phone'] ?? '',
      invoicePhoto: invoicePhoto, // Embed metadata object
      submissionTimestamp: Timestamp.now(),
      status: 'pending_review',
      documentUrls: [downloadUrl], // Store the single download URL
    );

    // 6. Write to Firestore
    await docRef.set(submission.toFirestore());

    // 7. Create notification for admins
    await _createSubmissionNotification(
      submissionId,
      resellerName,
      submission.responsibleName,
      submission.serviceCategory.displayName,
    );

    // 8. Return the submission ID
    return submissionId;
  }

  // Helper method to get enum value from string (Ensure this handles toString() correctly)
  T? _getEnumValueFromString<T extends Enum>(List<T> enumValues, String value) {
    if (value.isEmpty) return null;
    for (final enumValue in enumValues) {
      // Compare against the name property which is reliable
      if (enumValue.name == value) {
        return enumValue;
      }
    }
    if (kDebugMode) {
      print("Warning: Could not find enum value for string '$value' in $T");
    }
    return null; // Return null if no match
  }

  // Get a specific submission by ID
  Future<ServiceSubmission?> getSubmissionById(String submissionId) async {
    try {
      final doc = await _submissionsCollection.doc(submissionId).get();
      return doc.exists ? ServiceSubmission.fromFirestore(doc) : null;
    } catch (e) {
      debugPrint('Error getting submission by ID: $e');
      throw Exception('Failed to get submission: $e');
    }
  }

  // Create notification helper
  Future<void> _createSubmissionNotification(
    String submissionId,
    String resellerName,
    String clientName,
    String serviceType,
  ) async {
    if (kDebugMode) {
      print('========== NOTIFICATION CREATION START ==========');
      print('Creating admin notification for submission: $submissionId');
      print(
        'Notification details: resellerName=$resellerName, clientName=$clientName, serviceType=$serviceType',
      );
    }

    try {
      final resellerId = currentUserId;
      if (resellerId == null) {
        if (kDebugMode) print('ERROR: Current user ID is null');
        return;
      }

      if (kDebugMode) print('Using resellerId for notification: $resellerId');

      final notificationRepo = NotificationRepository();

      final notificationId = await notificationRepo
          .createNewSubmissionNotification(
            submissionId: submissionId,
            resellerName: resellerName,
            clientName: clientName,
            serviceType: serviceType,
          );

      if (notificationId.isEmpty) {
        if (kDebugMode)
          print('WARNING: Notification creation returned empty ID');
      } else {
        if (kDebugMode)
          print('SUCCESSFULLY created notification with ID: $notificationId');
      }

      // Trigger the onNotificationCreated callback if set
      if (onNotificationCreated != null) {
        if (kDebugMode) print('Triggering notification refresh callback');
        onNotificationCreated!();
      }
    } catch (e) {
      if (kDebugMode) print('ERROR creating notification: $e');
      // Handle specific errors like permissions if necessary
    } finally {
      if (kDebugMode) print('========== NOTIFICATION CREATION END ==========');
    }
  }
}

// Provider for the repository
final serviceSubmissionRepositoryProvider =
    riverpod.Provider<ServiceSubmissionRepository>((ref) {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;
      final imagePicker = ImagePicker(); // Keep for camera

      return ServiceSubmissionRepository(
        firestore: firestore,
        storage: storage,
        imagePicker: imagePicker,
      );
    });
