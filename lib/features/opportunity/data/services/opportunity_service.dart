import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/salesforce_opportunity.dart'; // Import the new model

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
                    if (item['Id'] == null || item['Name'] == null) {
                      print(
                        '[OpportunityService] Error: Record missing Id or Name: $item',
                      );
                      return null; // Skip this record
                    }
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
}
