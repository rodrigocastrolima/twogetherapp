import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../opportunity/data/models/salesforce_opportunity.dart';
import '../../domain/models/account.dart';
import '../../../../core/models/service_submission.dart';
import '../../../proposal/data/models/salesforce_proposal.dart';
import '../../../proposal/data/models/salesforce_proposal_ref.dart';
import '../../../opportunity/data/models/create_opp_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../proposal/data/models/salesforce_cpe_proposal_data.dart';
import '../../../proposal/data/models/salesforce_proposal_data.dart';

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
            .map((json) {
              // Ensure json is treated as a Map before converting
              if (json is Map) {
                try {
                  final mapJson = Map<String, dynamic>.from(json);
                  // Add specific checks for mandatory fields BEFORE parsing
                  if (mapJson['Id'] == null || mapJson['Name'] == null) {
                    print(
                      '[SalesforceRepository] Error: Record missing Id or Name: $mapJson',
                    );
                    return null; // Skip this record
                  }
                  return SalesforceOpportunity.fromJson(mapJson);
                } catch (e) {
                  print(
                    '[SalesforceRepository] Error parsing record $json: $e',
                  );
                  return null; // Skip records that cause parsing errors
                }
              } else {
                // Handle unexpected item type
                if (kDebugMode) {
                  print(
                    '[SalesforceRepository] Skipping unexpected item type in opportunities list: ${json?.runtimeType}',
                  );
                }
                return null; // Skip non-map items
              }
            })
            .whereType<SalesforceOpportunity>()
            .toList(); // Filter out nulls
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

  /// Fetches proposals related to a specific opportunity from Salesforce
  ///
  /// [opportunityId] is the Salesforce Opportunity ID.
  /// Returns a list of [SalesforceProposal] objects or throws an exception.
  Future<List<SalesforceProposal>> getOpportunityProposals(
    String opportunityId,
  ) async {
    if (kDebugMode) {
      print('Fetching proposals for Opportunity ID: $opportunityId');
    }
    // Validate input
    if (opportunityId.isEmpty) {
      throw Exception('Opportunity ID cannot be empty');
    }

    try {
      // Call the Cloud Function
      final callable = _functions.httpsCallable('getOpportunityProposals');
      final result = await callable.call<Map<String, dynamic>>({
        'opportunityId': opportunityId,
      });

      // Parse the response
      final data = result.data;
      if (kDebugMode) {
        print('getOpportunityProposals Cloud Function response: $data');
      }

      if (data['success'] == true) {
        final proposalsJson = data['proposals'] as List<dynamic>?;

        if (proposalsJson == null || proposalsJson.isEmpty) {
          return []; // Return empty list if no proposals
        }

        // Convert each JSON object to a SalesforceProposal
        return proposalsJson
            .map((json) {
              if (json is Map) {
                try {
                  final mapJson = Map<String, dynamic>.from(json);
                  // Add specific checks for mandatory fields BEFORE parsing
                  if (mapJson['Id'] == null ||
                      mapJson['Name'] == null ||
                      mapJson['Data_de_Validade__c'] == null ||
                      mapJson['Status__c'] == null) {
                    print(
                      '[SalesforceRepository] Proposal record missing required fields (Id, Name, Data_de_Validade__c, Status__c): $mapJson',
                    );
                    return null; // Skip this record
                  }
                  return SalesforceProposal.fromJson(mapJson);
                } catch (e) {
                  print(
                    '[SalesforceRepository] Error parsing proposal record $json: $e',
                  );
                  return null; // Skip records that cause parsing errors
                }
              } else {
                if (kDebugMode) {
                  print(
                    '[SalesforceRepository] Skipping unexpected item type in proposals list: ${json?.runtimeType}',
                  );
                }
                // Removed the throw Exception to allow skipping
                return null; // Skip non-map items
              }
            })
            .whereType<SalesforceProposal>()
            .toList(); // Filter out nulls
      } else {
        // Handle error response from the function
        final errorMessage =
            data['error'] as String? ?? 'Unknown error from function';
        final errorCode = data['errorCode'] as String? ?? 'FUNCTION_ERROR';
        throw Exception(
          'Failed to fetch proposals: [$errorCode] $errorMessage',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          'getOpportunityProposals Firebase Functions error: [${e.code}] ${e.message}',
        );
      }
      throw Exception(
        'Cloud function error fetching proposals: [${e.code}] ${e.message ?? "Unknown error"}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('getOpportunityProposals General error: $e');
      }
      throw Exception('Failed to fetch proposals: $e');
    }
  }

  /// Calls the Cloud Function to create an Account (if needed) and Opportunity in Salesforce.
  Future<CreateOppResult> createSalesforceOpportunity(
    CreateOppParams params,
  ) async {
    // Get callable function instance
    final functions = FirebaseFunctions.instance;
    // Optional: Use emulator
    // functions.useFunctionsEmulator('localhost', 5001);
    final callable = functions.httpsCallable('createSalesforceOpportunity');

    print(
      'Calling createSalesforceOpportunity with params: ${params.toJson()}',
    ); // Debug log

    try {
      // Call the function with parameters converted to JSON
      final HttpsCallableResult result = await callable
          .call<Map<String, dynamic>>(params.toJson());

      print('Cloud Function result data: ${result.data}'); // Debug log

      // Parse the result using the factory constructor
      return CreateOppResult.fromJson(result.data as Map<String, dynamic>);
    } on FirebaseFunctionsException catch (e, stacktrace) {
      // Handle specific Cloud Function errors
      print(
        'FirebaseFunctionsException calling createSalesforceOpportunity: $e',
      );
      print('Stacktrace: $stacktrace');
      // Check if the error details contain the sessionExpired flag
      bool sessionExpired = false;
      if (e.details is Map<String, dynamic>) {
        sessionExpired =
            (e.details as Map<String, dynamic>)['sessionExpired'] == true;
      }
      // Return a failure result
      return CreateOppResult(
        success: false,
        error: '${e.code}: ${e.message}', // Combine code and message
        sessionExpired: sessionExpired,
      );
    } catch (e, stacktrace) {
      // Handle any other unexpected errors during the call
      print('Generic error calling createSalesforceOpportunity: $e');
      print('Stacktrace: $stacktrace');
      return CreateOppResult(
        success: false,
        error: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  // --- Fetch Single Proposal Details ---
  Future<SalesforceProposal> getProposalDetails(String proposalId) async {
    if (kDebugMode) {
      print(
        '[SalesforceRepository] Fetching details for proposal ID: $proposalId',
      );
    }
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('getProposalDetails'); // Assumes Cloud Function exists
      final result = await callable.call<Map<String, dynamic>>({
        'proposalId': proposalId,
      });

      final data = result.data;
      if (data['success'] == true && data['proposal'] != null) {
        if (kDebugMode) {
          print(
            '[SalesforceRepository] getProposalDetails Cloud Function response: ${data['proposal']}',
          );
        }
        // Add robust parsing
        try {
          final Map<String, dynamic> proposalJson = Map<String, dynamic>.from(
            data['proposal'],
          );

          // Basic validation (adjust fields as needed based on actual function response)
          if (proposalJson['Id'] == null ||
              proposalJson['Name'] ==
                  null || // Keep Name for now if needed internally
              proposalJson['Data_de_Validade__c'] == null ||
              proposalJson['Status__c'] == null) {
            print(
              '[SalesforceRepository] Proposal record missing required fields: $proposalJson',
            );
            throw Exception(
              'Received invalid proposal data from Cloud Function.',
            );
          }
          return SalesforceProposal.fromJson(proposalJson);
        } catch (e) {
          print(
            '[SalesforceRepository] Error parsing single proposal record ${data['proposal']}: $e',
          );
          throw Exception('Error processing proposal data.');
        }
      } else {
        final errorMessage =
            data['error'] ?? 'Unknown error fetching proposal details.';
        if (kDebugMode) {
          print(
            '[SalesforceRepository] getProposalDetails Cloud Function failed: $errorMessage',
          );
        }
        throw Exception(errorMessage);
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[SalesforceRepository] getProposalDetails Firebase Error: ${e.code} - ${e.message}',
        );
      }
      throw Exception('Error communicating with server: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        print('[SalesforceRepository] getProposalDetails General error: $e');
      }
      // TODO: Implement appropriate error handling if needed
      rethrow; // Rethrow other exceptions
    }
  }

  // --- Fetch All-Time Total Commission for Reseller ---
  Future<double> getTotalResellerCommission(String resellerId) async {
    if (kDebugMode) {
      print(
        '[SalesforceRepository] Fetching total commission for reseller ID: $resellerId',
      );
    }
    if (resellerId.isEmpty) {
      throw Exception('Reseller Salesforce ID cannot be empty');
    }

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1', // Ensure correct region
      ).httpsCallable('getTotalResellerCommission'); // Assumes CF exists
      final result = await callable.call<Map<String, dynamic>>({
        'resellerSalesforceId': resellerId,
      });

      final data = result.data;
      if (kDebugMode) {
        print(
          '[SalesforceRepository] getTotalResellerCommission CF response: $data',
        );
      }

      if (data['success'] == true && data['totalCommission'] != null) {
        // Ensure the returned value is treated as a number (double or int)
        final commission = data['totalCommission'];
        if (commission is num) {
          return commission.toDouble();
        } else {
          print(
            '[SalesforceRepository] Warning: totalCommission received was not a number: $commission (${commission.runtimeType})',
          );
          return 0.0; // Return 0 if type is unexpected
        }
      } else if (data['success'] == true && data['totalCommission'] == null) {
        // Handle case where query returns null (no matching proposals)
        if (kDebugMode) {
          print(
            '[SalesforceRepository] getTotalResellerCommission returned null sum, likely no matching proposals.',
          );
        }
        return 0.0;
      } else {
        final errorMessage =
            data['error'] ?? 'Unknown error fetching total commission.';
        if (kDebugMode) {
          print(
            '[SalesforceRepository] getTotalResellerCommission CF failed: $errorMessage',
          );
        }
        throw Exception('Failed to fetch total commission: $errorMessage');
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[SalesforceRepository] getTotalResellerCommission Firebase Error: ${e.code} - ${e.message}',
        );
      }
      throw Exception('Error communicating with server: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        print(
          '[SalesforceRepository] getTotalResellerCommission General error: $e',
        );
      }
      rethrow;
    }
  }
  // --------------------------------------------------

  // --- NEW: Fetch Reseller Opportunity Proposal Names (JWT Flow) ---
  Future<List<SalesforceProposalRef>> getResellerOpportunityProposalNames(
    String opportunityId,
  ) async {
    if (kDebugMode) {
      print(
        '[SalesforceRepository] Fetching proposal names for Opportunity ID (Reseller Flow): $opportunityId',
      );
    }
    if (opportunityId.isEmpty) {
      throw Exception('Opportunity ID cannot be empty');
    }

    try {
      // --- Force token refresh before calling --- <-
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        if (kDebugMode) {
          print(
            '[SalesforceRepository] Forcing ID token refresh before calling function...',
          );
        }
        await currentUser.getIdToken(true);
        if (kDebugMode) {
          print('[SalesforceRepository] Token refresh attempted.');
        }
      } else {
        // This shouldn't happen if the function requires auth, but good practice
        if (kDebugMode) {
          print(
            '[SalesforceRepository] Cannot refresh token, no current user.',
          );
        }
        throw Exception('No authenticated user found for token refresh.');
      }
      // ---------------------------------------- <-

      // Call the NEW Cloud Function using the JWT flow implicitly
      final callable = _functions.httpsCallable(
        'getResellerOpportunityProposals',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'opportunityId': opportunityId,
      });

      // Parse the response
      final data = result.data;

      if (kDebugMode) {
        print(
          '[SalesforceRepository] getResellerOpportunityProposalNames Cloud Function response: $data',
        );
      }

      if (data['success'] == true) {
        final proposalsJson = data['proposals'] as List<dynamic>?;

        if (proposalsJson == null || proposalsJson.isEmpty) {
          return []; // Return empty list if no proposals
        }

        // Convert each JSON object to a SalesforceProposalRef
        return proposalsJson
            .map((json) {
              if (json is Map) {
                try {
                  final mapJson = Map<String, dynamic>.from(json);
                  // Use the new model's fromJson
                  return SalesforceProposalRef.fromJson(mapJson);
                } catch (e) {
                  print(
                    '[SalesforceRepository] Error parsing proposal ref record $json: $e',
                  );
                  return null;
                }
              } else {
                if (kDebugMode) {
                  print(
                    '[SalesforceRepository] Skipping non-map item in proposals list: ${json?.runtimeType}',
                  );
                }
                return null;
              }
            })
            .whereType<
              SalesforceProposalRef
            >() // Filter out nulls using new type
            .toList();
      } else {
        // Handle error response from the function
        final errorMessage =
            data['error'] as String? ?? 'Unknown error from function';
        final errorCode = data['errorCode'] as String? ?? 'FUNCTION_ERROR';
        if (kDebugMode) {
          print(
            '[SalesforceRepository] getResellerOpportunityProposalNames failed: [$errorCode] $errorMessage',
          );
        }
        throw Exception(
          'Failed to fetch proposal names: [$errorCode] $errorMessage',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[SalesforceRepository] getResellerOpportunityProposalNames Firebase Functions error: [${e.code}] ${e.message}',
        );
      }
      throw Exception(
        'Cloud function error fetching proposal names: [${e.code}] ${e.message ?? "Unknown error"}',
      );
    } catch (e) {
      if (kDebugMode) {
        print(
          '[SalesforceRepository] getResellerOpportunityProposalNames General error: $e',
        );
      }
      throw Exception('Failed to fetch proposal names: $e');
    }
  }
  // ---------------------------------------------------------------

  // --- UPDATED: Fetch Reseller Proposal Details (JWT Flow) ---
  // Now returns SalesforceProposalData directly
  Future<SalesforceProposalData> getResellerProposalDetails(
    String proposalId,
  ) async {
    final functionName = "getResellerProposalDetails";
    if (kDebugMode) {
      print(
        '[$runtimeType] Fetching details for Proposal ID (Reseller Flow): $proposalId',
      );
    }
    if (proposalId.isEmpty) {
      throw Exception('Proposal ID cannot be empty');
    }

    try {
      // Call the Cloud Function (which now returns the proposal object directly)
      final callable = _functions.httpsCallable(functionName);
      // The result.data is now expected to be the Map representing SalesforceProposalData
      final result = await callable.call<Map<String, dynamic>>({
        'proposalId': proposalId,
      });

      final data = result.data;

      if (kDebugMode) {
        print(
          '[$runtimeType] $functionName Cloud Function raw response: $data',
        );
      }

      // Directly parse the received data into SalesforceProposalData
      try {
        // Ensure the received data is correctly typed before parsing
        final Map<String, dynamic> typedData = Map<String, dynamic>.from(data);
        // The SalesforceProposalData.fromJson factory will handle parsing the nested CPEs
        return SalesforceProposalData.fromJson(typedData);
      } catch (e) {
        print(
          '[$runtimeType] Error parsing $functionName result JSON: $e - Data: $data',
        );
        throw Exception(
          'Error processing proposal details data from function.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[$runtimeType] $functionName Firebase Functions error: [${e.code}] ${e.message}',
        );
      }
      // Rethrow specific errors if needed (like not-found)
      if (e.code == 'not-found') {
        throw FirebaseFunctionsException(
          code: 'not-found',
          message: e.message ?? 'Proposal not found.',
        );
      }
      if (e.code == 'unauthenticated') {
        throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: e.message ?? 'Salesforce session expired or invalid.',
          details:
              e.details, // Pass details which might include sessionExpired flag
        );
      }
      // Rethrow other Firebase exceptions
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('[$runtimeType] $functionName General error: $e');
      }
      throw Exception('Failed to fetch proposal details: $e');
    }
  }
  // --------------------------------------------------------

  // -------------------------------------
}

/// Provider for the SalesforceRepository
final salesforceRepositoryProvider = Provider<SalesforceRepository>((ref) {
  return SalesforceRepository();
});
