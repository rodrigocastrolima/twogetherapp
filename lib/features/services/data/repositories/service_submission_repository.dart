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

  // Save a new service submission
  Future<String> saveSubmission(ServiceSubmission submission) async {
    try {
      if (kDebugMode) {
        print('Starting submission save process...');
      }

      // Ensure we have the current user data
      final userData = await getCurrentUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }

      if (kDebugMode) {
        print(
          'Got user data, user: ${userData['displayName']}, role: ${userData['role']}',
        );
      }

      // Create a submission with the current user's data
      final updatedSubmission = submission.copyWith(
        resellerId: currentUserId!,
        resellerName: userData['displayName'] ?? 'Unknown Reseller',
      );

      if (kDebugMode) {
        print('Saving submission to Firestore...');
      }

      // Save to Firestore
      final docRef = await _submissionsCollection.add(
        updatedSubmission.toFirestore(),
      );

      // Get the new document ID
      final submissionId = docRef.id;

      if (kDebugMode) {
        print('Submission created with ID: $submissionId');
        print('Creating admin notification for submission...');
      }

      // Create notification for admins about the new submission
      await _createSubmissionNotification(
        submissionId,
        updatedSubmission.resellerName,
        updatedSubmission.responsibleName,
        updatedSubmission.serviceCategory.displayName,
      );

      // Return the new document ID
      return submissionId;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving submission: $e');
        print('Stack trace: ${StackTrace.current}');
      }
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

  // Universal file picker for all platforms and file types
  Future<dynamic> pickFileFromGallery({List<String>? allowedExtensions}) async {
    try {
      if (kDebugMode) {
        print('Opening universal file picker');
      }

      // Default allowed extensions (support both images and PDFs)
      final validExtensions =
          allowedExtensions ?? ['jpg', 'jpeg', 'png', 'pdf', 'heic'];

      // Create a case-insensitive list of extensions that includes both upper and lowercase
      final allExtensions = <String>[];
      for (final ext in validExtensions) {
        allExtensions.add(ext.toLowerCase());
        allExtensions.add(ext.toUpperCase());
      }

      if (kIsWeb) {
        // Web implementation uses ImagePicker for now
        // This is simpler and more reliable on web
    final pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
        );

        if (pickedFile == null) {
          return null;
        }

        // Validate file extension
        final fileName = pickedFile.name.toLowerCase();
        if (!_isFileExtensionValid(fileName, validExtensions)) {
          throw Exception(
            'Please select a valid file type: ${validExtensions.join(", ")}',
          );
        }

        return pickedFile;
      } else {
        // For all other platforms (mobile/desktop)
        // Use FilePicker with minimal configuration to avoid errors
        try {
          if (kDebugMode) {
            print('Using file picker with extensions: $allExtensions');
          }

          // On Windows, explicitly use FileType.custom with all allowed extensions
          // This works better than FileType.any which sometimes has issues with PDFs
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: allExtensions,
            allowMultiple: false,
            dialogTitle:
                'Open File', // Standard dialog title recognized by Windows
            lockParentWindow: true,
          );

          if (result == null || result.files.isEmpty) {
            if (kDebugMode) {
              print('No file selected or selection canceled');
            }
            return null;
          }

          final file = result.files.first;
          if (kDebugMode) {
            print('Selected file: ${file.name}, type: ${file.extension}');
          }

          final filePath = file.path;

          if (filePath == null) {
            if (kDebugMode) {
              print('Invalid file path');
            }
            return null;
          }

          // Create a File object
          final selectedFile = File(filePath);

          // Validate if the file exists
          if (!await selectedFile.exists()) {
            if (kDebugMode) {
              print('File does not exist: $filePath');
            }
            return null;
          }

          // Validate file extension
          if (!_isFileExtensionValid(filePath, validExtensions)) {
            throw Exception(
              'Please select a valid file type: ${validExtensions.join(", ")}',
            );
          }

          if (kDebugMode) {
            print('Successfully selected file: $filePath');
          }

          return selectedFile;
        } catch (e) {
          if (kDebugMode) {
            print('Error with FilePicker: $e');
          }

          // Windows-specific workaround
          if (Platform.isWindows) {
            try {
              if (kDebugMode) {
                print('Trying Windows-specific fallback approach...');
              }

              // Try with a broader approach without extension filtering
              final fallbackResult = await FilePicker.platform.pickFiles(
                type: FileType.any, // No filtering to see anything
                allowMultiple: false,
                dialogTitle: 'Open File',
                withReadStream: true,
              );

              if (fallbackResult != null && fallbackResult.files.isNotEmpty) {
                final fallbackFile = fallbackResult.files.first;
                if (fallbackFile.path != null) {
                  final file = File(fallbackFile.path!);

                  // Validate manually
                  if (await file.exists()) {
                    if (kDebugMode) {
                      print('Fallback approach success: ${file.path}');
                    }

                    // We'll allow any file to be selected at this point and handle validation in UI
                    return file;
                  }
                }
              }
            } catch (fallbackError) {
              if (kDebugMode) {
                print('Windows fallback approach also failed: $fallbackError');
              }
            }
          }

          // If FilePicker fails on any platform, try a fallback method with ImagePicker
          // This ensures we always have a working file picker
          final pickedFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 75,
          );

          if (pickedFile == null) {
            return null;
          }

          // On non-web platforms, convert XFile to File
      return File(pickedFile.path);
    }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking file: $e');
      }
      throw Exception('Failed to select file: $e');
    }
  }

  // Helper method to check if file extension is valid
  bool _isFileExtensionValid(String filePath, List<String> validExtensions) {
    final lowerPath = filePath.toLowerCase();
    return validExtensions.any((ext) => lowerPath.endsWith('.$ext'));
  }

  // Legacy method for backward compatibility
  Future<dynamic> pickImageFromGallery() async {
    return pickFileFromGallery(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic'],
    );
  }

  // Method to pick PDF files ONLY
  Future<File?> pickPdfFromGallery() async {
    try {
      if (kDebugMode) {
        print('Opening PDF-only file picker (CASE-INSENSITIVE VERSION)');
      }

      // WEB PLATFORM
      if (kIsWeb) {
        if (kDebugMode) {
          print(
            'Web implementation - using pickFileFromGallery with PDF filter only',
          );
        }
        // For web, just use the universal picker with PDF filter
        final result = await pickFileFromGallery(allowedExtensions: ['pdf']);
        if (result is XFile) {
          if (kDebugMode) {
            print('Selected file on web: ${result.name}');
          }
          return File(result.path);
    }
    return null;
  }

      // WINDOWS/DESKTOP PLATFORM - use FilePicker with AGGRESSIVE PDF-only approach
      try {
        if (kDebugMode) {
          print('Using FilePicker with AGGRESSIVE settings for PDFs only');
          print('Trying to set dialogTitle to "Select PDF File (.pdf)"');
          // Allow both lowercase and uppercase PDF extensions
          print(
            'Using explicitly ["pdf"] as allowed extensions (will be handled case-insensitively)',
          );
        }

        // Use explicit FileType.custom with clear PDF-only extensions
        // Note: FilePicker handles extensions case-insensitively on most platforms
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Select PDF File (.pdf)',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowCompression: false,
          allowMultiple: false,
          withData: false,
          lockParentWindow: true,
        );

        if (result == null || result.files.isEmpty) {
          if (kDebugMode) {
            print('No file selected or selection canceled');
          }
          return null;
        }

        final file = result.files.first;
        final filePath = file.path;

        if (kDebugMode) {
          print('SELECTED FILE INFO:');
          print('- Name: ${file.name}');
          print('- Path: $filePath');
          print('- Size: ${file.size} bytes');
          print('- Extension from FilePicker: ${file.extension}');
        }

        if (filePath == null) {
          if (kDebugMode) {
            print('File path is null');
          }
          return null;
        }

        // Create a File object
        final pdfFile = File(filePath);

        // Validate if file exists
        final exists = await pdfFile.exists();
        if (kDebugMode) {
          print('File exists: $exists');
        }

        if (exists) {
          // Verify it's a PDF by checking extension - force lowercase for case-insensitive comparison
          final extension = path.extension(filePath).toLowerCase();
          if (kDebugMode) {
            print('File extension (lowercase): $extension');
          }

          if (extension == '.pdf') {
            if (kDebugMode) {
              print('Successfully selected PDF file: $filePath');
            }
            return pdfFile;
          } else {
            if (kDebugMode) {
              print('Selected file is not a PDF. Extension: $extension');
              print('Still returning the file for further validation in UI');
            }
            return pdfFile;
          }
        } else {
          if (kDebugMode) {
            print('Selected file does not exist: $filePath');
          }
          return null;
        }
      } catch (e) {
        // If the first approach fails, try an even simpler fallback approach
        if (kDebugMode) {
          print('First PDF picker attempt failed: $e');
          print('Trying absolute simplified fallback...');
        }

        // Ultra-simple fallback - just try to get ANY file and then validate
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.any,
            allowMultiple: false,
          );

          if (result == null ||
              result.files.isEmpty ||
              result.files.first.path == null) {
            if (kDebugMode) {
              print('Fallback file picker failed or user canceled');
            }
            return null;
          }

          final file = File(result.files.first.path!);
          if (await file.exists()) {
            // Always use lowercase for case-insensitive comparison
            final fileExtension = path.extension(file.path).toLowerCase();
            if (kDebugMode) {
              print('Fallback selected file extension: $fileExtension');
            }

            if (fileExtension == '.pdf') {
              if (kDebugMode) {
                print('Fallback success - found PDF: ${file.path}');
              }
              return file;
            } else {
              if (kDebugMode) {
                print('Fallback file is not a PDF. Extension: $fileExtension');
                print('Still returning for UI validation');
              }
              return file;
            }
          }
        } catch (fallbackError) {
          if (kDebugMode) {
            print('Even the fallback approach failed: $fallbackError');
          }
        }
      }

      if (kDebugMode) {
        print('All PDF file picking attempts failed, returning null');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error picking PDF: $e');
      }
      return null;
    }
  }

  // Pick an image from camera
  Future<dynamic> pickImageFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75, // Moderate quality for reasonable file size
      );

      if (pickedFile == null) {
        return null;
      }

      // Return the appropriate type based on platform
      if (kIsWeb) {
        // For web, return the XFile directly
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
    required dynamic invoiceFile, // Supports File, XFile, or Uint8List
    required String resellerId,
    required String resellerName,
  }) async {
    // 1. Generate a new document reference to get the submission ID
    final docRef = _firestore.collection('serviceSubmissions').doc();
    final submissionId = docRef.id;

    // 2. Define the storage path for the invoice file
    String fileName;
    String fileExtension = 'jpg'; // Default extension
    String contentType = 'image/jpeg'; // Default content type
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Handle file name and extension based on platform
    if (kIsWeb) {
      // For web, we may not have a path property
      if (invoiceFile is XFile) {
        // Try to get extension from name if available
        final name = invoiceFile.name.toLowerCase();
        if (name.contains('.')) {
          fileExtension = name.split('.').last;

          // Set contentType based on file extension
          if (fileExtension == 'pdf') {
            contentType = 'application/pdf';
          } else if (['jpg', 'jpeg'].contains(fileExtension)) {
            contentType = 'image/jpeg';
          } else if (fileExtension == 'png') {
            contentType = 'image/png';
          } else if (fileExtension == 'heic') {
            contentType = 'image/heic';
          }
        }
      }
    } else {
      // For mobile platforms
      String path = '';
      if (invoiceFile is File) {
        path = invoiceFile.path.toLowerCase();
      } else if (invoiceFile is XFile) {
        path = invoiceFile.path.toLowerCase();
      }

      if (path.isNotEmpty) {
        if (path.contains('.')) {
          fileExtension = path.split('.').last;

          // Set contentType based on file extension
          if (fileExtension == 'pdf') {
            contentType = 'application/pdf';
          } else if (['jpg', 'jpeg'].contains(fileExtension)) {
            contentType = 'image/jpeg';
          } else if (fileExtension == 'png') {
            contentType = 'image/png';
          } else if (fileExtension == 'heic') {
            contentType = 'image/heic';
          }
        }
      }
    }

    fileName = 'invoice_${timestamp}.$fileExtension';
    final storagePath = 'submissions/$submissionId/$fileName';

    // 3. Upload the file to Firebase Storage
    final storageRef = _storage.ref(storagePath);
    UploadTask uploadTask;

    if (kIsWeb) {
      // Web implementation
      if (invoiceFile is Uint8List) {
        // If it's already binary data
        uploadTask = storageRef.putData(
          invoiceFile,
          SettableMetadata(contentType: contentType),
        );
      } else if (invoiceFile is XFile) {
        // If it's an XFile
        final bytes = await invoiceFile.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        throw Exception("Unsupported file format for web platform");
      }
    } else {
      // Mobile implementation
      if (invoiceFile is File) {
        uploadTask = storageRef.putFile(
          invoiceFile,
          SettableMetadata(contentType: contentType),
        );
      } else if (invoiceFile is XFile) {
        uploadTask = storageRef.putFile(
          File(invoiceFile.path),
          SettableMetadata(contentType: contentType),
        );
      } else {
        throw Exception("Unsupported file format for mobile platform");
      }
    }

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

    // Create notification for admins about the new submission
    await _createSubmissionNotification(
      submissionId,
      resellerName,
      submission.responsibleName,
      submission.serviceCategory.displayName,
    );

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

  // Create a helper method to ensure notification creation works consistently
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
      // Ensure we have the current user data to use as the resellerId
      final resellerId = currentUserId;

      if (resellerId == null) {
        if (kDebugMode) {
          print('ERROR: Current user ID is null, cannot create notification');
        }
        return;
      }

      if (kDebugMode) {
        print('Using resellerId for notification: $resellerId');
        print('Creating NotificationRepository instance');
      }

      final notificationRepo = NotificationRepository();

      if (kDebugMode) {
        print('Calling createNewSubmissionNotification on repository');
        print(
          'Parameters: submissionId=$submissionId, resellerName=$resellerName, clientName=$clientName, serviceType=$serviceType',
        );
        // Verify NotificationType.newSubmission exists
        print(
          'NotificationType.newSubmission = ${NotificationType.newSubmission.toString()}',
        );
        print(
          'Which translates to string value: ${NotificationType.newSubmission.toString().split('.').last}',
        );
      }

      final notificationId = await notificationRepo
          .createNewSubmissionNotification(
            submissionId: submissionId,
            resellerName: resellerName,
            clientName: clientName,
            serviceType: serviceType,
          );

      if (notificationId.isEmpty) {
        if (kDebugMode) {
          print(
            'WARNING: Notification creation returned empty ID, possible permission issue',
          );
          print(
            'The submission was created successfully, but the notification may have failed',
          );
          print(
            'You can manually check the admin dashboard for the submission',
          );
        }
      } else {
        if (kDebugMode) {
          print('SUCCESSFULLY created notification with ID: $notificationId');
          // Add diagnostic information for troubleshooting
          print(
            'DEBUG: Notification created successfully. Please check the admin dashboard',
          );
          print('DEBUG: For the notification to appear properly, ensure:');
          print(
            'DEBUG: 1. NotificationType.newSubmission is set correctly (${NotificationType.newSubmission})',
          );
          print(
            'DEBUG: 2. Admin users are properly set up with role="admin" in Firestore',
          );
          print(
            'DEBUG: 3. getAdminSubmissionNotifications() is querying correctly',
          );

          // Verify a notification exists in Firestore with this type
          try {
            final snapshot =
                await _firestore
                    .collection('notifications')
                    .where('type', isEqualTo: 'newSubmission')
                    .limit(1)
                    .get();

            print(
              'DEBUG: Verification query found ${snapshot.docs.length} matching notifications',
            );
            if (snapshot.docs.isNotEmpty) {
              print(
                'DEBUG: Sample notification data: ${snapshot.docs.first.data()}',
              );
            }
          } catch (e) {
            print('DEBUG: Verification query failed: $e');
          }
        }
      }

      // Trigger the onNotificationCreated callback if set
      if (onNotificationCreated != null) {
        if (kDebugMode) {
          print('Triggering notification refresh callback');
        }
        onNotificationCreated!();
      }
    } catch (e) {
      // Don't fail the submission creation if notification fails
      if (kDebugMode) {
        print('ERROR creating notification: $e');
        print('Exception type: ${e.runtimeType}');
        print('Stack trace: ${StackTrace.current}');

        if (e.toString().contains('permission')) {
          print(
            'PERMISSION ERROR: This is likely a Firestore security rule issue.',
          );
          print(
            'The notification could not be created due to permission restrictions.',
          );
          print(
            'Ensure your security rules allow system notifications to be created.',
          );
        }
      }
    } finally {
      if (kDebugMode) {
        print('========== NOTIFICATION CREATION END ==========');
      }
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
