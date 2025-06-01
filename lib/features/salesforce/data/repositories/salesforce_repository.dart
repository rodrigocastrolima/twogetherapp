import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../opportunity/data/models/salesforce_opportunity.dart';
import '../../domain/models/account.dart';
import '../../domain/models/dashboard_stats.dart';

import '../../../proposal/data/models/salesforce_proposal.dart';
import '../../../proposal/data/models/salesforce_proposal_ref.dart';
import '../../../opportunity/data/models/create_opp_models.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../proposal/data/models/salesforce_proposal_data.dart';
import 'dart:convert'; // <-- Add import for jsonEncode/Decode
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Repository for interacting with Salesforce data through Firebase Cloud Functions
class SalesforceRepository {
  final FirebaseFunctions _functions;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Constructor that accepts a FirebaseFunctions instance
  SalesforceRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Initialize the Salesforce connection
  /// Returns true if successful
  Future<bool> initialize() async {
    try {
      // For now, just return true to simulate successful initialization
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Salesforce connection: $e');
      }
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
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to Salesforce: $e');
      }
      return false;
    }
  }

  /// Disconnect from Salesforce
  Future<void> disconnect() async {
    try {
      // For now, just set connected to false
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
  /// Handles token refresh automatically.
  ///
  /// [resellerSalesforceId] is the Salesforce User ID of the reseller
  /// Returns a list of [SalesforceOpportunity] objects or throws an exception
  Future<List<SalesforceOpportunity>> getResellerOpportunities(
    String resellerSalesforceId, {
    int retryCount = 0, // Add retry count to prevent infinite loops
  }) async {
    if (retryCount > 1) {
      // Avoid infinite loops if refresh keeps failing
      throw Exception("Failed to fetch opportunities after token refresh attempt.");
    }

    if (kDebugMode) {
      print(
        'Fetching opportunities for Salesforce ID: $resellerSalesforceId (Attempt ${retryCount + 1})',
      );
    }

    // Validate input
    if (resellerSalesforceId.isEmpty) {
      throw Exception('Reseller Salesforce ID cannot be empty');
    }

    // Prepare the Cloud Function call
    final callable = _functions.httpsCallable('getResellerOpportunities');
    final params = {'resellerSalesforceId': resellerSalesforceId};

    try {
      // Make the initial call
      final result = await callable.call<Map<String, dynamic>>(params);
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
              if (json is Map) {
                try {
                  final mapJson = Map<String, dynamic>.from(json);
                  if (mapJson['Id'] == null || mapJson['Name'] == null) {
                    if (kDebugMode) {
                      print(
                        '[SalesforceRepository Map] Skipping record missing Id or Name: $mapJson',
                      );
                    }
                    return null; // Skip this record
                  }

                  // --- Add Detailed Logging Here ---
                  if (kDebugMode) {
                    final hasPropostasR = mapJson.containsKey('Propostas__r');
                    print(
                      '[SalesforceRepository Map] Processing Id: ${mapJson['Id']}',
                    );
                    print(
                      '[SalesforceRepository Map] JSON has Propostas__r key: $hasPropostasR',
                    );
                    if (hasPropostasR) {
                      print(
                        '[SalesforceRepository Map] Propostas__r value: ${mapJson['Propostas__r']}',
                      );
                      print(
                        '[SalesforceRepository Map] Propostas__r type: ${mapJson['Propostas__r'].runtimeType}',
                      );
                    }
                  }
                  // --- End Detailed Logging ---

                  final opportunity = SalesforceOpportunity.fromJson(mapJson);

                  // --- Add Logging AFTER FromJson ---
                  if (kDebugMode) {
                    print(
                      '[SalesforceRepository Map] Parsed Opportunity ID: ${opportunity.id}',
                    );
                    print(
                      '[SalesforceRepository Map] Parsed Opportunity PropostasR: ${opportunity.propostasR}',
                    );
                    // Optionally print the full parsed object
                    // print('[SalesforceRepository Map] Parsed Opportunity Object: $opportunity');
                  }
                  // --- End Logging AFTER FromJson ---

                  return opportunity; // Return the parsed object
                } catch (e, s) {
                  // Added stack trace
                  if (kDebugMode) {
                    print(
                      '[SalesforceRepository Map] Error parsing record $json: $e\nStack trace: $s',
                    );
                  }
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
        // Handle error response within the function's success:false payload
        final errorMessage = data['error'] as String? ?? 'Unknown error';
        final errorCode = data['errorCode'] as String? ?? 'UNKNOWN';
        // Log the error or throw a specific exception
        if (kDebugMode) {
          print(
            'Error from getResellerOpportunities function payload: $errorCode - $errorMessage',
          );
        }
        throw Exception(
          'Failed to fetch opportunities: $errorCode - $errorMessage',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print("FirebaseFunctionsException caught: Code=${e.code}, Message=${e.message}, Details=${e.details}");
      }
      // Check if the error indicates an expired token (adjust code as needed)
      // Common codes: 'unauthenticated', 'permission-denied'. Details might be needed.
      bool needsRefresh = e.code == 'unauthenticated'; 
      
      if (needsRefresh && retryCount == 0) { // Only attempt refresh once
        if (kDebugMode) {
          print("Potential expired token detected. Attempting refresh...");
        }
        try {
          final refreshToken = await _getRefreshToken();
          if (refreshToken == null) {
            if (kDebugMode) {
              print("No refresh token found. Cannot refresh. User needs to re-login.");
            }
            // Re-throw the original error or a specific "LoginRequiredError"
            throw Exception("User re-authentication required (no refresh token)."); 
          }

          // Call the refresh token function
          final refreshCallable = _functions.httpsCallable('refreshSalesforceToken');
          final refreshResult = await refreshCallable.call<Map<String, dynamic>>({
            'refreshToken': refreshToken,
          });

          final refreshData = refreshResult.data;
           if (kDebugMode) {
              print("Refresh token function response: $refreshData");
           }

          // Check if refreshData contains the expected fields directly
          final newAccessToken = refreshData['newAccessToken'] as String?;
          final newInstanceUrl = refreshData['newInstanceUrl'] as String?;
          final newExpiresIn = refreshData['newExpiresInSeconds'] as int?;

          if (newAccessToken != null && newInstanceUrl != null && newExpiresIn != null) {
            if (kDebugMode) {
              print("Token refresh successful. Saving new tokens.");
            }
            // Save the new tokens (implementation depends on _saveTokens)
            // Note: refreshSalesforceToken usually doesn't return a *new* refresh token
            await _saveTokens(newAccessToken, null, newInstanceUrl, newExpiresIn); 

            if (kDebugMode) {
              print("Retrying getResellerOpportunities call...");
            }
            // Retry the original call
            return await getResellerOpportunities(resellerSalesforceId, retryCount: retryCount + 1);
          } else {
            // Handle cases where refresh function succeeded but response was unexpected
            if (kDebugMode) {
              print("Refresh token function returned success but response format was unexpected.");
            }
             throw Exception("Token refresh failed (unexpected response). User should re-login.");
          }

        } on FirebaseFunctionsException catch (refreshError) {
           // Handle errors during the refresh call itself
           if (kDebugMode) {
             print("Error calling refreshSalesforceToken function: ${refreshError.code} - ${refreshError.message}");
           }
           // If refresh specifically fails with unauthenticated/invalid_grant, re-login is needed
           if (refreshError.code == 'unauthenticated' || refreshError.details?['salesforceError'] == 'invalid_grant') {
               if (kDebugMode) {
                 print("Refresh token invalid. User needs to re-login.");
               }
               throw Exception("User re-authentication required (invalid refresh token).");
           } else {
               // Throw a general error for other refresh failures
               throw Exception("Failed to refresh token: ${refreshError.message}");
           }
        } catch (refreshError) {
           // Catch any other non-Functions exceptions during refresh/storage
           if (kDebugMode) {
             print("Unexpected error during token refresh flow: $refreshError");
           }
           throw Exception("An unexpected error occurred during token refresh.");
        }
      } else if (needsRefresh && retryCount > 0) {
         // Already tried refreshing, but failed again - force login
         if (kDebugMode) {
           print("Call failed again after token refresh attempt. Forcing re-login.");
         }
         throw Exception("User re-authentication required (refresh failed).");
      } else {
        // The error was not related to token expiry, re-throw it
        if (kDebugMode) {
          print("HttpsError was not related to token expiry. Rethrowing.");
        }
        rethrow;
      }
    } catch (e) {
      // Catch any other non-Functions exceptions during the initial call
      if (kDebugMode) {
        print('Generic error fetching opportunities: $e');
      }
      // Rethrow the error to be handled by the caller
      throw Exception('An unexpected error occurred: ${e.toString()}');
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
                    if (kDebugMode) {
                      print(
                        '[SalesforceRepository] Proposal record missing required fields (Id, Name, Data_de_Validade__c, Status__c): $mapJson',
                      );
                    }
                    return null; // Skip this record
                  }
                  return SalesforceProposal.fromJson(mapJson);
                } catch (e) {
                  if (kDebugMode) {
                    print(
                      '[SalesforceRepository] Error parsing proposal record $json: $e',
                    );
                  }
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

    if (kDebugMode) {
      print(
        'Calling createSalesforceOpportunity with params: ${params.toJson()}',
      ); // Debug log
    }

    try {
      // Call the function with parameters converted to JSON
      final HttpsCallableResult result = await callable
          .call<Map<String, dynamic>>(params.toJson());

      if (kDebugMode) {
        print('Cloud Function result data: ${result.data}'); // Debug log
      }

      // Parse the result using the factory constructor
      return CreateOppResult.fromJson(result.data as Map<String, dynamic>);
    } on FirebaseFunctionsException catch (e, stacktrace) {
      // Handle specific Cloud Function errors
      if (kDebugMode) {
        print(
          'FirebaseFunctionsException calling createSalesforceOpportunity: $e',
        );
        print('Stacktrace: $stacktrace');
      }
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
      if (kDebugMode) {
        print('Generic error calling createSalesforceOpportunity: $e');
        print('Stacktrace: $stacktrace');
      }
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
            if (kDebugMode) {
              print(
                '[SalesforceRepository] Proposal record missing required fields: $proposalJson',
              );
            }
            throw Exception(
              'Received invalid proposal data from Cloud Function.',
            );
          }
          return SalesforceProposal.fromJson(proposalJson);
        } catch (e) {
          if (kDebugMode) {
            print(
              '[SalesforceRepository] Error parsing single proposal record ${data['proposal']}: $e',
            );
          }
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
        region: 'us-central1', // Updated to match the function's region
      ).httpsCallable('getTotalResellerCommission');
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
          if (kDebugMode) {
            print(
              '[SalesforceRepository] Warning: totalCommission received was not a number: $commission (${commission.runtimeType})',
            );
          }
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
                  if (kDebugMode) {
                    print(
                      '[SalesforceRepository] Error parsing proposal ref record $json: $e',
                    );
                  }
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
        // Force correct typing using jsonEncode/Decode
        final jsonString = jsonEncode(data); // Encode to JSON string
        final typedData =
            jsonDecode(jsonString)
                as Map<String, dynamic>?; // Decode back to Map<String, dynamic>

        if (typedData == null) {
          throw Exception(
            'Received null or invalid data structure after JSON conversion.',
          );
        }

        // The SalesforceProposalData.fromJson factory will handle parsing the nested CPEs
        return SalesforceProposalData.fromJson(typedData);
      } catch (e) {
        if (kDebugMode) {
          print(
            '[$runtimeType] Error parsing $functionName result JSON: $e - Data: $data',
          );
        }
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

  // --- Helper methods for token storage (ASSUMED IMPLEMENTATION) ---
  // These need to be implemented based on how you actually store tokens.
  
  Future<String?> _getRefreshToken() async {
    // Replace with your actual logic to retrieve the refresh token
    return await _secureStorage.read(key: 'salesforce_refresh_token');
  }

  Future<void> _saveTokens(String accessToken, String? refreshToken, String instanceUrl, int expiresIn) async {
    // Replace with your actual logic to save tokens
    await _secureStorage.write(key: 'salesforce_access_token', value: accessToken);
    if (refreshToken != null) { // Refresh token might not always be returned by refresh endpoint
        await _secureStorage.write(key: 'salesforce_refresh_token', value: refreshToken);
    }
    await _secureStorage.write(key: 'salesforce_instance_url', value: instanceUrl);
    // Store expiry time (current time + expires_in)
    final expiryTime = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
    await _secureStorage.write(key: 'salesforce_token_expiry', value: expiryTime.toString());
  }
  
  // --- End Helper methods ---

  // -------------------------------------

  /// Fetches dashboard stats for a specific reseller
  /// Handles token refresh automatically.
  ///
  /// [resellerSalesforceId] is the Salesforce User ID of the reseller
  /// Returns a [DashboardStats] object or throws an exception
  Future<DashboardStats> getResellerDashboardStats(
    String resellerSalesforceId, {
    int retryCount = 0,
  }) async {
    if (retryCount > 1) {
      throw Exception("Failed to fetch dashboard stats after token refresh attempt.");
    }

    if (kDebugMode) {
      print('Fetching dashboard stats for Salesforce ID: $resellerSalesforceId (Attempt ${retryCount + 1})');
    }

    // Validate input
    if (resellerSalesforceId.isEmpty) {
      throw Exception('Reseller Salesforce ID cannot be empty');
    }

    // Prepare the Cloud Function call
    final callable = _functions.httpsCallable('getResellerDashboardStats');
    final params = {'resellerSalesforceId': resellerSalesforceId};

    try {
      // Make the call
      final result = await callable.call<Map<String, dynamic>>(params);
      final data = result.data;

      if (kDebugMode) {
        print('Cloud Function response: $data');
      }

      if (data['success'] == true) {
        return DashboardStats.fromJson(data);
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch dashboard stats');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching dashboard stats: $e');
      }
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }
}

/// Provider for the SalesforceRepository
final salesforceRepositoryProvider = Provider<SalesforceRepository>((ref) {
  return SalesforceRepository();
});
