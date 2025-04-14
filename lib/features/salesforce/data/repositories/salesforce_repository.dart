import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../opportunity/presentation/pages/salesforce_opportunity.dart';
import '../../domain/models/account.dart';

/// Repository for interacting with Salesforce data through Firebase Cloud Functions
class SalesforceRepository {
  final FirebaseFunctions _functions;
  bool _isConnected = false;

  /// Constructor that accepts a FirebaseFunctions instance
  SalesforceRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Initialize the Salesforce connection
  /// Returns true if successful
  Future<bool> initialize() async {
    try {
      // For now, just return true to simulate successful initialization
      _isConnected = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Salesforce connection: $e');
      }
      _isConnected = false;
      return false;
    }
  }

  /// Connect to Salesforce with credentials
  /// Returns true if successful
  Future<bool> connect(
    String username,
    String password, {
    bool isSandbox = false,
  }) async {
    try {
      // For now, just return true to simulate successful connection
      _isConnected = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to Salesforce: $e');
      }
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from Salesforce
  Future<void> disconnect() async {
    try {
      // For now, just set connected to false
      _isConnected = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting from Salesforce: $e');
      }
    }
  }

  /// Get a list of Salesforce accounts
  /// Returns mock data for now
  Future<List<Account>> getAccounts({String? filter, int limit = 10}) async {
    try {
      // Return mock data for now
      return [
        Account(id: 'acc1', name: 'Sample Account 1'),
        Account(id: 'acc2', name: 'Sample Account 2'),
      ];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Salesforce accounts: $e');
      }
      return [];
    }
  }

  /// Get a Salesforce account by ID
  /// Returns mock data for now
  Future<Account?> getAccountById(String accountId) async {
    try {
      // Return mock data for now
      return Account(id: accountId, name: 'Sample Account $accountId');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Salesforce account by ID: $e');
      }
      return null;
    }
  }

  /// Get a list of Salesforce object fields
  /// Returns mock data for now
  Future<Map<String, dynamic>> getObjectFields(String objectName) async {
    try {
      // Return mock data for now
      return {
        'Id': {'type': 'id', 'label': 'ID'},
        'Name': {'type': 'string', 'label': 'Name'},
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Salesforce object fields: $e');
      }
      return {};
    }
  }

  /// Get a list of Salesforce opportunities
  /// Returns mock data for now
  Future<List<SalesforceOpportunity>> getOpportunities() async {
    try {
      // Return mock data for now
      // Reuse the method we already have
      return getResellerOpportunities('mocksalesforceId');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Salesforce opportunities: $e');
      }
      return [];
    }
  }

  /// Fetches opportunities from Salesforce for a specific reseller
  ///
  /// [resellerSalesforceId] is the Salesforce User ID of the reseller
  /// Returns a list of [SalesforceOpportunity] objects or throws an exception
  Future<List<SalesforceOpportunity>> getResellerOpportunities(
    String resellerSalesforceId,
  ) async {
    try {
      if (kDebugMode) {
        print(
          'Fetching opportunities for Salesforce ID: $resellerSalesforceId',
        );
      }

      // Validate input
      if (resellerSalesforceId.isEmpty) {
        throw Exception('Reseller Salesforce ID cannot be empty');
      }

      // Call the Cloud Function
      final callable = _functions.httpsCallable('getResellerOpportunities');
      final result = await callable.call<Map<String, dynamic>>({
        'resellerSalesforceId': resellerSalesforceId,
      });

      // Parse the response
      final data = result.data;

      if (kDebugMode) {
        print('Cloud Function response: $data');
      }

      if (data['success'] == true) {
        final opportunitiesJson = data['opportunities'] as List<dynamic>?;

        if (opportunitiesJson == null || opportunitiesJson.isEmpty) {
          return []; // Return empty list if no opportunities
        }

        // Convert each JSON object to a SalesforceOpportunity
        return opportunitiesJson
            .map(
              (json) =>
                  SalesforceOpportunity.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        // Handle error response from the function
        final errorMessage = data['error'] as String? ?? 'Unknown error';
        final errorCode = data['errorCode'] as String? ?? 'UNKNOWN';
        throw Exception(
          'Failed to fetch opportunities: [$errorCode] $errorMessage',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('Firebase Functions error: [${e.code}] ${e.message}');
      }
      throw Exception(
        'Cloud function error: [${e.code}] ${e.message ?? "Unknown error"}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching opportunities: $e');
      }
      throw Exception('Failed to fetch opportunities: $e');
    }
  }
}

/// Provider for the SalesforceRepository
final salesforceRepositoryProvider = Provider<SalesforceRepository>((ref) {
  return SalesforceRepository();
});
