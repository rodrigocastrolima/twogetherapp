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

class ServiceSubmissionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  final CollectionReference _submissionsCollection = FirebaseFirestore.instance
      .collection('service_submissions');
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
        .orderBy('submissionDate', descending: true)
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
        .orderBy('submissionDate', descending: true)
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
    String status,
  ) async {
    try {
      await _submissionsCollection.doc(submissionId).update({'status': status});
    } catch (e) {
      debugPrint('Error updating submission status: $e');
      throw Exception('Failed to update submission status: $e');
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
}
