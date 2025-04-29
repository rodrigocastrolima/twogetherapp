import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart'; // <-- Corrected path

import '../models/salesforce_opportunity.dart'; // Import the new model
import '../models/detailed_salesforce_opportunity.dart'; // Import the detail model

class OpportunityService {
  final FirebaseFunctions _functions;

  // Optional: Pass functions instance for testing/customization
  OpportunityService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instance; // Use default instance

  /// Fetches a list of Salesforce Opportunities (specifically 'Retail' type).
  Future<List<SalesforceOpportunity>> fetchSalesforceOpportunities({
    required String accessToken,
    required String instanceUrl,
  }) async {
    if (kDebugMode) {
      print('[OpportunityService] Fetching Salesforce Opportunities...');
    }
    try {
      // Get the callable function reference
      // Note: We exported the whole module as sfOppManagement in index.ts
      final HttpsCallable callable = _functions.httpsCallable(
        'sfOppManagement-getSalesforceOpportunities', // Correct callable name
        // options: HttpsCallableOptions(timeout: const Duration(seconds: 60)), // Optional timeout
      );

      // Call the function with required parameters
      final result = await callable.call<List<dynamic>>({
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
      });

      // Process the result (which should be List<dynamic>)
      final List<dynamic> data = result.data;
      if (kDebugMode) {
        print(
          '[OpportunityService] Received ${data.length} opportunities from function.',
        );
      }

      // Map the dynamic list to a list of SalesforceOpportunity objects
      final opportunities =
          data
              .map((item) {
                try {
                  // Ensure each item is a Map before passing to fromJson
                  if (item is Map<String, dynamic>) {
                    // Add specific checks for mandatory fields BEFORE parsing
                    // Make the check case-insensitive for Id/id and Name/name
                    final dynamic idValue = item['Id'] ?? item['id'];
                    final dynamic nameValue = item['Name'] ?? item['name'];

                    if (idValue == null || nameValue == null) {
                      print(
                        '[OpportunityService] Error: Record missing required Id/Name field (case-insensitive check): $item',
                      );
                      return null; // Skip this record
                    }
                    // If checks pass, proceed with fromJson
                    return SalesforceOpportunity.fromJson(item);
                  } else {
                    // Log error or throw if the structure isn't as expected
                    print(
                      '[OpportunityService] Error: Received non-map item in list: $item',
                    );
                    // throw const FormatException(
                    //   'Invalid data structure received from Cloud Function.',
                    // );
                    return null; // Skip this record
                  }
                } catch (e) {
                  print('[OpportunityService] Error parsing record $item: $e');
                  return null; // Skip records that cause parsing errors
                }
              })
              .whereType<SalesforceOpportunity>()
              .toList(); // Filter out nulls

      return opportunities;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] Caught FirebaseFunctionsException fetching opportunities:',
        );
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details Type: ${e.details?.runtimeType}');
        print('  Details: ${e.details}');
      }

      if (e.message == 'SALESFORCE_SESSION_EXPIRED') {
        if (kDebugMode) {
          print(
            '[OpportunityService] Session expired detected via exception message.',
          );
        }
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      if (kDebugMode) {
        print(
          '[OpportunityService] Session expired NOT detected via message. Rethrowing generic error.',
        );
      }
      throw Exception(
        'Failed to fetch Salesforce opportunities: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error fetching opportunities: $e');
      }
      throw Exception(
        'An unexpected error occurred while fetching opportunities.',
      );
    }
  }

  /// Fetches detailed information for a single Salesforce Opportunity.
  Future<DetailedSalesforceOpportunity> getOpportunityDetails({
    required String accessToken,
    required String instanceUrl,
    required String opportunityId,
  }) async {
    if (kDebugMode) {
      print(
        '[OpportunityService] Fetching details for Opportunity ID: $opportunityId',
      );
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'getSalesforceOpportunityDetails', // Ensure this matches the deployed function name
      );

      final result = await callable.call<Map<String, dynamic>>({
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'opportunityId': opportunityId,
      });

      final bool success = result.data['success'] as bool? ?? false;
      final Map<String, dynamic>? data =
          result.data['data'] as Map<String, dynamic>?;

      if (success && data != null) {
        if (kDebugMode) {
          print('[OpportunityService] Successfully received details data.');
          // print('[OpportunityService] Raw Details: ${data}'); // Optional detailed logging
        }
        // Parse the combined data using the DetailedSalesforceOpportunity model
        return DetailedSalesforceOpportunity.fromJson(data);
      } else {
        final String errorMsg =
            result.data['error'] as String? ??
            'Unknown error fetching details.';
        final bool sessionExpired =
            result.data['sessionExpired'] as bool? ?? false;
        final bool permissionDenied =
            result.data['permissionDenied'] as bool? ?? false;

        if (kDebugMode) {
          print('[OpportunityService] Failed to get details: $errorMsg');
        }
        if (sessionExpired) {
          throw Exception(
            'Salesforce session expired. Please re-authenticate.',
          );
        }
        if (permissionDenied) {
          throw Exception('Permission denied to view this opportunity.');
        }
        throw Exception('Failed to get opportunity details: $errorMsg');
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] FirebaseFunctionsException getting details:',
        );
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
      }
      // Handle specific codes like 'unauthenticated' or 'permission-denied' if needed
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied to view this opportunity.');
      }
      if (e.code == 'unauthenticated') {
        throw Exception('Authentication error. Please log in again.');
      }
      throw Exception(
        'Cloud Function error getting details: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error getting details: $e');
      }
      throw Exception(
        'An unexpected error occurred while getting opportunity details.',
      );
    }
  }

  /// Deletes a specific Salesforce Opportunity.
  Future<void> deleteSalesforceOpportunity({
    required String accessToken,
    required String instanceUrl,
    required String opportunityId,
  }) async {
    if (kDebugMode) {
      print(
        '[OpportunityService] Deleting Salesforce Opportunity ID: $opportunityId',
      );
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'sfOppManagement-deleteSalesforceOpportunity', // Correct callable name
        // options: HttpsCallableOptions(timeout: const Duration(seconds: 60)), // Optional timeout
      );

      final result = await callable.call<Map<String, dynamic>>({
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'opportunityId': opportunityId,
      });

      // Check the success flag from the result
      final bool success = result.data['success'] as bool? ?? false;
      if (!success) {
        final String errorMsg =
            result.data['error'] as String? ??
            'Unknown deletion error from function.';
        if (kDebugMode) {
          print(
            '[OpportunityService] Deletion failed according to function result: $errorMsg',
          );
        }
        throw Exception('Failed to delete opportunity: $errorMsg');
      }

      if (kDebugMode) {
        print(
          '[OpportunityService] Opportunity $opportunityId deleted successfully.',
        );
      }
      // No return value needed for success
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] Caught FirebaseFunctionsException deleting opportunity:',
        );
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details Type: ${e.details?.runtimeType}');
        print('  Details: ${e.details}');
      }

      if (e.message == 'SALESFORCE_SESSION_EXPIRED') {
        if (kDebugMode) {
          print(
            '[OpportunityService] Session expired detected via exception message.',
          );
        }
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      if (kDebugMode) {
        print(
          '[OpportunityService] Session expired NOT detected via message. Rethrowing generic error.',
        );
      }
      throw Exception(
        'Failed to delete Salesforce opportunity: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error deleting opportunity: $e');
      }
      throw Exception(
        'An unexpected error occurred while deleting the opportunity.',
      );
    }
  }

  // --- NEW Method: Fetch Activation Cycles ---
  Future<List<SalesforceCiclo>> getActivationCycles({
    required String accessToken,
    required String instanceUrl,
  }) async {
    if (kDebugMode) {
      print('[OpportunityService] Fetching Salesforce Activation Cycles...');
    }
    try {
      // Get the callable function reference
      final HttpsCallable callable = _functions.httpsCallable(
        'getActivationCycles', // Matches the exported function name
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ), // Optional timeout
      );

      // Call the function with required parameters
      final result = await callable.call<Map<String, dynamic>>({
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
      });

      // Process the result (expecting {'cycles': [{'id': '...', 'name': '...'}, ...]})
      final List<dynamic> cycleList =
          result.data['cycles'] as List<dynamic>? ?? [];
      if (kDebugMode) {
        print(
          '[OpportunityService] Received ${cycleList.length} cycles from function.',
        );
      }

      // Map the dynamic list to a list of SalesforceCiclo objects
      final cycles =
          cycleList
              .map((item) {
                if (item is Map<String, dynamic> &&
                    item['id'] != null &&
                    item['name'] != null) {
                  return SalesforceCiclo(
                    id: item['id'] as String,
                    name: item['name'] as String,
                  );
                } else {
                  print(
                    '[OpportunityService] Warning: Received invalid cycle item: $item',
                  );
                  return null; // Skip invalid items
                }
              })
              .whereType<SalesforceCiclo>()
              .toList(); // Filter out nulls

      return cycles;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] Caught FirebaseFunctionsException fetching cycles:',
        );
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
      }

      // Check if the error indicates a session expiry (based on the function's throw)
      if (e.code == 'unauthenticated' &&
          (e.details as Map?)?['sessionExpired'] == true) {
        if (kDebugMode) {
          print(
            '[OpportunityService] Salesforce session expired detected via exception details.',
          );
        }
        // Consider throwing a more specific exception type if you have one for auth errors
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }

      // Handle other function errors
      throw Exception(
        'Failed to fetch activation cycles: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error fetching cycles: $e');
      }
      throw Exception(
        'An unexpected error occurred while fetching activation cycles.',
      );
    }
  }

  // --- END NEW Method ---
}
