import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import '../../../notifications/data/repositories/notification_repository.dart';

class ServiceSubmissionRepository {
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

  // Save a new service submission
  Future<String> saveSubmission(ServiceSubmission submission) async {
    try {
      // Ensure we have the current user data
      final userData = await getCurrentUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }

      // Create a submission with the current user's data
      final updatedSubmission = submission.copyWith(
        resellerId: currentUserId!,
        resellerName: userData['displayName'] ?? 'Unknown Reseller',
      );

      // Save to Firestore
      final docRef = await _submissionsCollection.add(
        updatedSubmission.toFirestore(),
      );

      // Return the new document ID
      return docRef.id;
    } catch (e) {
      debugPrint('Error saving submission: $e');
      throw Exception('Failed to save submission: $e');
    }
  }

  // Upload an image to Firebase Storage
  Future<String> uploadImage(dynamic image, String submissionId) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${currentUserId!}';
      final path = 'service_submissions/$submissionId/$fileName';

      UploadTask uploadTask;

      if (kIsWeb) {
        // Web implementation
        if (image is XFile) {
          final bytes = await image.readAsBytes();
          uploadTask = _storage
              .ref()
              .child(path)
              .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          throw Exception('Unsupported image format for web');
        }
      } else {
        // Mobile implementation
        if (image is XFile) {
          final file = File(image.path);
          uploadTask = _storage.ref().child(path).putFile(file);
        } else if (image is File) {
          uploadTask = _storage.ref().child(path).putFile(image);
        } else {
          throw Exception('Unsupported image format for mobile');
        }
      }

      // Wait for the upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload multiple images and return URLs
  Future<List<String>> uploadImages(
    List<dynamic> images,
    String submissionId,
  ) async {
    final List<String> urls = [];

    for (final image in images) {
      final url = await uploadImage(image, submissionId);
      urls.add(url);
    }

    return urls;
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
          await _firestore
              .collection('serviceSubmissions')
              .doc(submissionId)
              .get();

      if (!submissionDoc.exists) {
        throw Exception('Submission not found');
      }

      final data = submissionDoc.data() as Map<String, dynamic>;
      final oldStatus = data['status'] as String? ?? 'unknown';
      final resellerId = data['resellerId'] as String? ?? '';
      final clientName =
          data['clientDetails']?['responsibleName'] as String? ?? 'Client';

      // Update the status
      await _firestore
          .collection('serviceSubmissions')
          .doc(submissionId)
          .update({
            'status': newStatus,
            'statusUpdatedAt': FieldValue.serverTimestamp(),
          });

      // Create a notification for the reseller
      if (resellerId.isNotEmpty && oldStatus != newStatus) {
        final notificationRepo = NotificationRepository();
        await notificationRepo.createStatusChangeNotification(
          userId: resellerId,
          submissionId: submissionId,
          oldStatus: oldStatus,
          newStatus: newStatus,
          clientName: clientName,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating submission status: $e');
      }
      rethrow;
    }
  }

  // Update submission with images
  Future<void> updateSubmissionWithImages(
    String submissionId,
    List<String> imageUrls,
  ) async {
    try {
      await _submissionsCollection.doc(submissionId).update({
        'documentUrls': imageUrls,
        'status': 'pending',
      });
      debugPrint(
        'Updated submission $submissionId with ${imageUrls.length} images',
      );
    } catch (e) {
      debugPrint('Error updating submission with images: $e');
      throw Exception('Failed to update submission with images: $e');
    }
  }

  // Delete a document image
  Future<void> deleteImage(String imageUrl, String submissionId) async {
    try {
      // Extract the path from the URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // The filename should be the last segment before any query parameters
      final fileName = pathSegments.last.split('?').first;

      // Construct the storage path
      final storagePath = 'service_submissions/$submissionId/$fileName';

      // Delete from Storage
      await _storage.ref().child(storagePath).delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
      throw Exception('Failed to delete image: $e');
    }
  }

  // Check if user is admin
  Future<bool> isCurrentUserAdmin() async {
    if (currentUserId == null) return false;

    try {
      final userDoc = await _usersCollection.doc(currentUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] == 'admin';
      }
      return false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Method to pick an image file from the device
  Future<File?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  // Convenience method to pick from camera
  Future<File?> pickImageFromCamera() async {
    return pickImageFile(source: ImageSource.camera);
  }

  // Convenience method to pick from gallery
  Future<File?> pickImageFromGallery() async {
    return pickImageFile(source: ImageSource.gallery);
  }

  // Get download URL for a storage path
  Future<String> getDownloadUrlForPath(String storagePath) async {
    try {
      // Get storage reference from the path
      final ref = _storage.ref(storagePath);

      // Get the download URL
      final downloadUrl = await ref.getDownloadURL();

      print("Generated download URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("Error getting download URL: $e");
      throw Exception("Failed to get download URL: $e");
    }
  }

  // Submit a service request with client details and invoice file
  Future<String> submitServiceRequest({
    required Map<String, dynamic> clientDetails,
    required File invoiceFile,
    required String resellerId,
    required String resellerName,
  }) async {
    // 1. Generate a new document reference to get the submission ID
    final docRef = _firestore.collection('serviceSubmissions').doc();
    final submissionId = docRef.id;

    // 2. Define the storage path for the invoice file
    final fileExtension = invoiceFile.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'invoice_${timestamp}.$fileExtension';
    final storagePath = 'submissions/$submissionId/$fileName';

    // 3. Upload the file to Firebase Storage
    final storageRef = _storage.ref(storagePath);
    final uploadTask = storageRef.putFile(invoiceFile);

    // Wait for the upload to complete
    await uploadTask;

    // 4. Get file metadata and download URL
    final metadata = await storageRef.getMetadata();
    final downloadUrl = await storageRef.getDownloadURL();

    // 5. Create the invoice photo metadata
    final invoicePhoto = InvoicePhoto(
      storagePath: storagePath,
      fileName: fileName,
      contentType:
          metadata.contentType ??
          'image/jpeg', // Default to jpeg if not detected
      uploadedTimestamp: Timestamp.now(),
      uploadedBy: resellerId,
    );

    // 6. Create the service submission object
    // Extract standard fields from clientDetails if they exist
    final serviceCategory = _getEnumValueFromString(
      ServiceCategory.values,
      clientDetails['serviceCategory'] ?? '',
    );

    final energyType =
        clientDetails['energyType'] != null
            ? _getEnumValueFromString(
              EnergyType.values,
              clientDetails['energyType'],
            )
            : null;

    final clientType = _getEnumValueFromString(
      ClientType.values,
      clientDetails['clientType'] ?? '',
    );

    final serviceProvider = _getEnumValueFromString(
      Provider.values,
      clientDetails['provider'] ?? '',
    );

    final submission = ServiceSubmission(
      id: submissionId,
      resellerId: resellerId,
      resellerName: resellerName,
      serviceCategory:
          serviceCategory ?? ServiceCategory.energy, // Default if not provided
      energyType: energyType,
      clientType:
          clientType ?? ClientType.residential, // Default if not provided
      provider: serviceProvider ?? Provider.repsol, // Default if not provided
      companyName: clientDetails['companyName'],
      responsibleName: clientDetails['responsibleName'] ?? '',
      nif: clientDetails['nif'] ?? '',
      email: clientDetails['email'] ?? '',
      phone: clientDetails['phone'] ?? '',
      invoicePhoto: invoicePhoto,
      submissionTimestamp: Timestamp.now(),
      status: 'pending_review',
      documentUrls: [downloadUrl], // Add the download URL to documentUrls
    );

    // 7. Write to Firestore
    await docRef.set(submission.toFirestore());

    // 8. Return the submission ID
    return submissionId;
  }

  // Helper method to get enum value from string
  T? _getEnumValueFromString<T>(List<T> enumValues, String value) {
    for (final enumValue in enumValues) {
      if (enumValue.toString().split('.').last == value) {
        return enumValue;
      }
    }
    return null;
  }

  // Get a specific submission by ID
  Future<ServiceSubmission?> getSubmissionById(String submissionId) async {
    try {
      final doc = await _submissionsCollection.doc(submissionId).get();

      if (!doc.exists) {
        return null;
      }

      return ServiceSubmission.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting submission by ID: $e');
      throw Exception('Failed to get submission: $e');
    }
  }
}

// Provider for the repository
final serviceSubmissionRepositoryProvider =
    riverpod.Provider<ServiceSubmissionRepository>((ref) {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;
      final imagePicker = ImagePicker();

      return ServiceSubmissionRepository(
        firestore: firestore,
        storage: storage,
        imagePicker: imagePicker,
      );
    });
