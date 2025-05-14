import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../services/salesforce_connection_service.dart';
import 'package:http/http.dart' as http;

class SalesforceUserRepository {
  final SalesforceConnectionService _connectionService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SalesforceUserRepository({
    required SalesforceConnectionService connectionService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _connectionService = connectionService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Query Salesforce for all active users
  Future<List<Map<String, dynamic>>> getSalesforceUsers() async {
    try {
      if (!_connectionService.isConnected) {
        throw Exception('Salesforce not connected. Please sign in.');
      }

      final accessToken = await _connectionService.accessToken;
      final instanceUrl = await _connectionService.instanceUrl;

      if (accessToken == null || instanceUrl == null) {
        throw Exception('Salesforce authentication token or instance URL is missing.');
      }

      // Query to get all active users with their IDs, names, and emails
      final query =
          'SELECT Id, Name, Email, IsActive FROM User WHERE IsActive = true';
      final encodedQuery = Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse('$instanceUrl/services/data/v58.0/query/?q=$encodedQuery'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['records'] != null) {
          return List<Map<String, dynamic>>.from(data['records']);
        }
        return [];
      } else {
        throw Exception(
          'Failed to load Salesforce users: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Salesforce users: $e');
      }
      rethrow;
    }
  }

  /// Get Salesforce User ID for a specific email
  Future<String?> getSalesforceUserIdByEmail(String email) async {
    try {
      if (!_connectionService.isConnected) {
        throw Exception('Salesforce not connected. Please sign in.');
      }

      final accessToken = await _connectionService.accessToken;
      final instanceUrl = await _connectionService.instanceUrl;

      if (accessToken == null || instanceUrl == null) {
        throw Exception('Salesforce authentication token or instance URL is missing.');
      }

      // Query for specific user by email
      final query =
          "SELECT Id FROM User WHERE Email = '${email.replaceAll("'", "\\'")}' AND IsActive = true LIMIT 1";
      final encodedQuery = Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse('$instanceUrl/services/data/v58.0/query/?q=$encodedQuery'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['records'] != null && data['records'].isNotEmpty) {
          return data['records'][0]['Id'];
        }
        return null;
      } else {
        throw Exception(
          'Failed to query Salesforce user: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Salesforce user by email: $e');
      }
      return null;
    }
  }

  /// Update the current user's Salesforce ID in Firestore
  Future<void> updateCurrentUserSalesforceId() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No authenticated user or user has no email');
      }

      final salesforceId = await getSalesforceUserIdByEmail(currentUser.email!);
      if (salesforceId == null) {
        if (kDebugMode) {
          print('No Salesforce user found for email: ${currentUser.email}');
        }
        return;
      }

      // Update Firestore document
      await _firestore.collection('users').doc(currentUser.uid).set({
        'salesforceId': salesforceId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print(
          'Updated user ${currentUser.email} with Salesforce ID: $salesforceId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating current user Salesforce ID: $e');
      }
      rethrow;
    }
  }

  /// Match and update all Firebase users with Salesforce IDs (admin only)
  Future<Map<String, dynamic>> syncAllUsersSalesforceIds() async {
    try {
      // Check if current user is an admin
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final isAdmin = userDoc.data()?['isAdmin'] == true;

      if (!isAdmin) {
        throw Exception('Only admin users can perform this operation');
      }

      // Get all Salesforce users
      final salesforceUsers = await getSalesforceUsers();

      // Create a map of Salesforce users by email for easy lookup
      final salesforceUsersByEmail = <String, Map<String, dynamic>>{};
      for (final user in salesforceUsers) {
        final email = user['Email'] as String?;
        if (email != null) {
          salesforceUsersByEmail[email.toLowerCase()] = user;
        }
      }

      // Get all Firebase user documents
      final firebaseUsers = await _firestore.collection('users').get();

      int matchedCount = 0;
      int updatedCount = 0;
      int notFoundCount = 0;

      // Update each Firebase user with their Salesforce ID
      for (final userDoc in firebaseUsers.docs) {
        final userData = userDoc.data();
        final email = userData['email'] as String?;

        if (email != null) {
          final salesforceUser = salesforceUsersByEmail[email.toLowerCase()];

          if (salesforceUser != null) {
            matchedCount++;
            final salesforceId = salesforceUser['Id'] as String;

            // Check if user already has this Salesforce ID
            if (userData['salesforceId'] != salesforceId) {
              await _firestore.collection('users').doc(userDoc.id).set({
                'salesforceId': salesforceId,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              updatedCount++;
            }
          } else {
            notFoundCount++;
          }
        }
      }

      return {
        'totalFirebaseUsers': firebaseUsers.docs.length,
        'totalSalesforceUsers': salesforceUsers.length,
        'matchedCount': matchedCount,
        'updatedCount': updatedCount,
        'notFoundCount': notFoundCount,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing all users with Salesforce IDs: $e');
      }
      rethrow;
    }
  }
}
