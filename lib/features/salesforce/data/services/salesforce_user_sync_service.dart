import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'salesforce_connection_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service for synchronizing user data between Salesforce and Firebase
class SalesforceUserSyncService {
  final SalesforceConnectionService _salesforceService;
  final FirebaseFirestore _firestore;

  // Default field mapping between Salesforce and Firebase
  static const Map<String, String> _defaultFieldMapping = {
    'Id': 'salesforceId',
    'Name': 'displayName',
    'Email': 'email',
    'IsActive': 'isActive',
    'Phone': 'phoneNumber',
    'MobilePhone': 'mobilePhone',
    'Department': 'department',
    'Username': 'salesforceUsername',
    'FirstName': 'firstName',
    'LastName': 'lastName',
    'Revendedor_Retail__c': 'revendedorRetail',
  };

  SalesforceUserSyncService({
    required SalesforceConnectionService salesforceService,
    FirebaseFirestore? firestore,
  }) : _salesforceService = salesforceService,
       _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get the Salesforce user data for a specific ID
  Future<Map<String, dynamic>?> getSalesforceUserById(
    String salesforceId,
  ) async {
    if (!await _ensureConnected()) {
      return null;
    }

    try {
      // Build query to fetch the Salesforce user - only request valid fields
      final fieldList = _defaultFieldMapping.keys.join(', ');
      final query =
          "SELECT $fieldList FROM User WHERE Id = '${salesforceId.replaceAll("'", "\\'")}' LIMIT 1";
      final encodedQuery = Uri.encodeComponent(query);

      if (kDebugMode) {
        print('Executing Salesforce query: $query');
      }

      final data = await _salesforceService.get(
        '/services/data/v58.0/query/?q=$encodedQuery',
      );

      if (data == null ||
          !data.containsKey('records') ||
          data['records'].isEmpty) {
        if (kDebugMode) {
          print('No Salesforce user found with ID: $salesforceId');
        }
        return null;
      }

      // Error handling for invalid fields in the query
      if (data.containsKey('errors') && (data['errors'] as List).isNotEmpty) {
        final errors = data['errors'] as List;
        for (final error in errors) {
          if (kDebugMode) {
            print('Salesforce query error: ${error['message']}');
          }
        }

        // Try again with a minimal set of guaranteed fields
        final fallbackQuery =
            "SELECT Id, Name, Email FROM User WHERE Id = '${salesforceId.replaceAll("'", "\\'")}' LIMIT 1";
        final fallbackEncodedQuery = Uri.encodeComponent(fallbackQuery);

        if (kDebugMode) {
          print('Retrying with fallback query: $fallbackQuery');
        }

        final fallbackData = await _salesforceService.get(
          '/services/data/v58.0/query/?q=$fallbackEncodedQuery',
        );

        if (fallbackData == null ||
            !fallbackData.containsKey('records') ||
            fallbackData['records'].isEmpty) {
          return null;
        }

        return fallbackData['records'][0] as Map<String, dynamic>;
      }

      return data['records'][0] as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching Salesforce user: $e');
      }
      return null;
    }
  }

  /// Fetch information about available fields on the User object
  Future<List<Map<String, dynamic>>?> getFieldInfoForUserObject() async {
    if (!await _ensureConnected()) {
      return null;
    }

    try {
      final data = await _salesforceService.get(
        '/services/data/v58.0/sobjects/User/describe',
      );

      if (data == null || !data.containsKey('fields')) {
        if (kDebugMode) {
          print('Failed to retrieve field information for User object');
        }
        return null;
      }

      final fields = data['fields'] as List<dynamic>;
      return fields.map((field) => field as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching User object field information: $e');
      }
      return null;
    }
  }

  /// Print available fields for debugging
  Future<void> debugPrintAvailableFields() async {
    if (kDebugMode) {
      print('Fetching available fields for the User object...');
    }

    final fields = await getFieldInfoForUserObject();
    if (fields == null) {
      if (kDebugMode) {
        print('Failed to retrieve field information.');
      }
      return;
    }

    // Sort fields by name for easier reading
    fields.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    if (kDebugMode) {
      print('Available fields on User object:');
      for (final field in fields) {
        final name = field['name'] as String;
        final label = field['label'] as String;
        final type = field['type'] as String;
        final custom = field['custom'] as bool;
        final nullable = field['nillable'] as bool;

        print(
          '- $name: Type=$type, Label="$label", Custom=$custom, Nullable=$nullable',
        );
      }
    }
  }

  /// Sync Salesforce user data to a Firebase user
  Future<bool> syncSalesforceUserToFirebase(
    String firebaseUserId,
    String salesforceId,
  ) async {
    try {
      // Get Salesforce user data
      final salesforceUser = await getSalesforceUserById(salesforceId);
      if (salesforceUser == null) {
        return false;
      }

      // Map Salesforce data to Firebase format
      final Map<String, dynamic> firebaseData = _mapSalesforceToFirebase(
        salesforceUser,
      );

      // Add timestamp for the sync
      firebaseData['salesforceSyncedAt'] = FieldValue.serverTimestamp();

      // Update the Firebase user document
      await _firestore
          .collection('users')
          .doc(firebaseUserId)
          .update(firebaseData);

      if (kDebugMode) {
        print('Successfully synced Salesforce data for user: $firebaseUserId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing Salesforce user to Firebase: $e');
      }
      return false;
    }
  }

  /// Find Firebase users that need to be synced with Salesforce
  /// Returns a list of {firebaseUserId, salesforceId} maps
  Future<List<Map<String, String>>> findUsersNeedingSalesforceSync({
    Duration? olderThan,
    int limit = 50,
  }) async {
    try {
      // Create a query for users with salesforceId but not synced recently
      Query query = _firestore
          .collection('users')
          .where('salesforceId', isNull: false)
          .limit(limit);

      // Add time constraint if provided
      if (olderThan != null) {
        final cutoffTime = Timestamp.fromDate(
          DateTime.now().subtract(olderThan),
        );

        query = query.where('salesforceSyncedAt', isLessThan: cutoffTime);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;

            // Fix: Add null check for data and safe access to salesforceId
            if (data == null) {
              if (kDebugMode) {
                print('Warning: Document ${doc.id} has null data');
              }
              return <String, String>{};
            }

            final salesforceId = data['salesforceId'] as String?;

            if (salesforceId == null) {
              if (kDebugMode) {
                print(
                  'Warning: User ${doc.id} has null salesforceId despite query filter',
                );
              }
              return <String, String>{}; // This will be filtered out below
            }

            return {'firebaseUserId': doc.id, 'salesforceId': salesforceId};
          })
          .where((map) => map.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error finding users needing Salesforce sync: $e');
      }
      return [];
    }
  }

  /// Sync all users that have a Salesforce ID but haven't been synced recently
  Future<Map<String, int>> syncAllUsersWithSalesforce({
    Duration? olderThan,
    int limit = 50,
  }) async {
    int successCount = 0;
    int errorCount = 0;

    try {
      // Find users that need syncing
      final usersToSync = await findUsersNeedingSalesforceSync(
        olderThan: olderThan,
        limit: limit,
      );

      if (kDebugMode) {
        print('Found ${usersToSync.length} users to sync with Salesforce');
      }

      // Sync each user
      for (final userMap in usersToSync) {
        if (userMap.containsKey('firebaseUserId') &&
            userMap.containsKey('salesforceId')) {
          final success = await syncSalesforceUserToFirebase(
            userMap['firebaseUserId']!,
            userMap['salesforceId']!,
          );

          if (success) {
            successCount++;
          } else {
            errorCount++;
          }
        } else {
          if (kDebugMode) {
            print('Skipping user map with missing keys: $userMap');
          }
          errorCount++;
        }
      }

      return {
        'totalFound': usersToSync.length,
        'success': successCount,
        'error': errorCount,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error in bulk Salesforce user sync: $e');
      }
      return {'totalFound': 0, 'success': successCount, 'error': errorCount};
    }
  }

  /// Map Salesforce data to Firebase format using field mapping
  Map<String, dynamic> _mapSalesforceToFirebase(
    Map<String, dynamic> salesforceUser,
  ) {
    final Map<String, dynamic> result = {};

    _defaultFieldMapping.forEach((salesforceField, firebaseField) {
      if (salesforceUser.containsKey(salesforceField)) {
        result[firebaseField] = salesforceUser[salesforceField];
      }
    });

    return result;
  }

  /// Ensure we have an active connection to Salesforce
  Future<bool> _ensureConnected() async {
    if (!_salesforceService.isConnected) {
      if (kDebugMode) {
        print(
          'SalesforceUserSyncService: Salesforce not connected. User may need to sign in.',
        );
      }
      return false;
    }
    return true;
  }

  /// Get the field mapping to use for syncing Salesforce data to Firebase
  Map<String, String> get salesforceFieldMapping => _defaultFieldMapping;

  static Map<String, String> getDefaultFieldMapping() => _defaultFieldMapping;
}

// Define the provider for SalesforceUserSyncService
final salesforceUserSyncServiceProvider = Provider<SalesforceUserSyncService>((ref) {
  final salesforceConnectionService = ref.watch(salesforceConnectionServiceProvider);
  return SalesforceUserSyncService(salesforceService: salesforceConnectionService);
});
