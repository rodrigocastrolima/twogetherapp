import 'dart:convert'; // <-- Import for base64Encode

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:twogether/features/proposal/domain/salesforce_ciclo.dart'; // <-- Corrected path

import '../models/salesforce_opportunity.dart'; // Import the new model
import '../models/detailed_salesforce_opportunity.dart'; // Import the detail model

// Import the Auth Notifier needed for downloadFile
import '../../../../core/services/salesforce_auth_service.dart';

class OpportunityService {
  final FirebaseFunctions _functions;
  // ADD dependency on the auth notifier
  final SalesforceAuthNotifier _authNotifier;

  // UPDATE constructor to require SalesforceAuthNotifier
  OpportunityService({
    required SalesforceAuthNotifier authNotifier,
    FirebaseFunctions? functions,
  }) : _authNotifier = authNotifier, // Initialize _authNotifier
       _functions = functions ?? FirebaseFunctions.instance;

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
                      if (kDebugMode) {
                      print(
                        '[OpportunityService] Error: Record missing required Id/Name field (case-insensitive check): $item',
                      );
                      }
                      return null; // Skip this record
                    }
                    // If checks pass, proceed with fromJson
                    return SalesforceOpportunity.fromJson(item);
                  } else {
                    // Log error or throw if the structure isn't as expected
                    if (kDebugMode) {
                    print(
                      '[OpportunityService] Error: Received non-map item in list: $item',
                    );
                    }
                    // throw const FormatException(
                    //   'Invalid data structure received from Cloud Function.',
                    // );
                    return null; // Skip this record
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print(
                      '[OpportunityService] Error parsing record $item: $e',
                    );
                  }
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

  // --- START: NEW Methods for Edit Feature ---

  /// Updates fields on a Salesforce Opportunity.
  Future<void> updateOpportunity({
    required String accessToken,
    required String instanceUrl,
    required String opportunityId,
    required Map<String, dynamic>
    fieldsToUpdate, // Use Salesforce API Names as keys
  }) async {
    if (kDebugMode) {
      print(
        '[OpportunityService] Updating Opportunity ID: $opportunityId with fields: ${fieldsToUpdate.keys.join(', ')}',
      );
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'updateSalesforceOpportunity', // Matches the deployed function name
        options: HttpsCallableOptions(timeout: Duration(seconds: 60)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'opportunityId': opportunityId,
        'fieldsToUpdate': fieldsToUpdate,
      });

      final bool success = result.data['success'] as bool? ?? false;
      if (!success) {
        final String errorMsg =
            result.data['error'] as String? ??
            'Unknown error updating opportunity.';
        final dynamic validationErrors =
            result.data['validationErrors']; // Capture validation details
        if (kDebugMode) {
          print(
            '[OpportunityService] Opportunity update failed via function: $errorMsg',
          );
          if (validationErrors != null) {
            print('[OpportunityService] Validation Errors: $validationErrors');
          }
        }
        // Consider throwing a more specific exception for validation errors
        throw Exception('Failed to update opportunity: $errorMsg');
      }

      if (kDebugMode) {
        print(
          '[OpportunityService] Opportunity $opportunityId updated successfully.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] FirebaseFunctionsException updating opportunity:',
        );
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
      }
      // Handle specific codes
      if ((e.details as Map<String, dynamic>?)?['sessionExpired'] == true ||
          e.code == 'unauthenticated') {
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied to update this opportunity.');
      }
      if ((e.details as Map<String, dynamic>?)?['validationErrors'] != null) {
        // Rethrow with validation info if possible (might need custom exception)
        final validationDetails =
            (e.details as Map<String, dynamic>?)?['validationErrors'];
        throw Exception(
          'Salesforce validation failed: ${e.message} Details: $validationDetails',
        );
      }
      throw Exception(
        'Cloud Function error updating opportunity: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error updating opportunity: $e');
      }
      throw Exception(
        'An unexpected error occurred while updating the opportunity.',
      );
    }
  }

  /// Uploads a file to Salesforce and links it to a parent record (e.g., Opportunity).
  /// Returns the ContentDocument ID of the uploaded file, or null on failure.
  Future<String?> uploadFile({
    required String accessToken,
    required String instanceUrl,
    required String parentId, // The ID of the record to link the file to
    required String fileName,
    required Uint8List fileBytes,
    String? mimeType, // Optional: Helps Salesforce identify file type
  }) async {
    if (kDebugMode) {
      print(
        '[OpportunityService] Uploading file \'$fileName\' to parent ID: $parentId',
      );
    }
    try {
      final String fileContentBase64 = base64Encode(fileBytes);

      final HttpsCallable callable = _functions.httpsCallable(
        'uploadSalesforceFile', // Matches the deployed function name
        options: HttpsCallableOptions(timeout: Duration(seconds: 120)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'parentId': parentId,
        'fileName': fileName,
        'fileContentBase64': fileContentBase64,
        if (mimeType != null) 'mimeType': mimeType,
      });

      final bool success = result.data['success'] as bool? ?? false;
      final String? contentDocumentId =
          result.data['contentDocumentId'] as String?;

      if (success && contentDocumentId != null) {
        if (kDebugMode) {
          print(
            '[OpportunityService] File uploaded successfully. ContentDocument ID: $contentDocumentId',
          );
        }
        return contentDocumentId;
      } else {
        final String errorMsg =
            result.data['error'] as String? ?? 'Unknown error uploading file.';
        if (kDebugMode) {
          print(
            '[OpportunityService] File upload failed via function: $errorMsg',
          );
        }
        // Throwing null signifies failure to the caller in this implementation
        // Could throw Exception('Failed to upload file: $errorMsg') instead
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] FirebaseFunctionsException uploading file:',
        );
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
      }
      if ((e.details as Map<String, dynamic>?)?['sessionExpired'] == true ||
          e.code == 'unauthenticated') {
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied to upload files here.');
      }
      if (e.code == 'invalid-argument' &&
          e.message?.contains('limit exceeded') == true) {
        throw Exception('File size limit exceeded.');
      }
      // Throw specific error or return null
      print(
        '[OpportunityService] Cloud function error during upload, returning null.',
      );
      return null;
      // throw Exception('Cloud Function error uploading file: ${e.message ?? e.code}');
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error uploading file: $e');
      }
      // Throw specific error or return null
      print(
        '[OpportunityService] Generic error during upload, returning null.',
      );
      return null;
      // throw Exception('An unexpected error occurred while uploading the file.');
    }
  }

  /// Deletes a file (ContentDocument) from Salesforce.
  Future<void> deleteFile({
    required String accessToken,
    required String instanceUrl,
    required String contentDocumentId,
  }) async {
    if (kDebugMode) {
      print(
        '[OpportunityService] Deleting ContentDocument ID: $contentDocumentId',
      );
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'deleteSalesforceFile', // Matches the deployed function name
        options: HttpsCallableOptions(timeout: Duration(seconds: 60)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'contentDocumentId': contentDocumentId,
      });

      final bool success = result.data['success'] as bool? ?? false;
      if (!success) {
        final String errorMsg =
            result.data['error'] as String? ?? 'Unknown error deleting file.';
        if (kDebugMode) {
          print(
            '[OpportunityService] File deletion failed via function: $errorMsg',
          );
        }
        throw Exception('Failed to delete file: $errorMsg');
      }

      if (kDebugMode) {
        print(
          '[OpportunityService] File $contentDocumentId deleted successfully.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] FirebaseFunctionsException deleting file:');
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
      }
      if ((e.details as Map<String, dynamic>?)?['sessionExpired'] == true ||
          e.code == 'unauthenticated') {
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied to delete this file.');
      }
      if (e.code == 'not-found') {
        // Maybe handle silently or rethrow depending on UX
        print(
          '[OpportunityService] File not found for deletion (maybe already deleted): $contentDocumentId',
        );
        // throw Exception('File not found or already deleted.');
        return; // Treat as success if not found?
      }
      throw Exception(
        'Cloud Function error deleting file: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error deleting file: $e');
      }
      throw Exception('An unexpected error occurred while deleting the file.');
    }
  }

  // --- END: NEW Methods for Edit Feature ---

  // --- NEW METHOD: Download File Data ---
  Future<
    ({
      Uint8List? fileData,
      String? contentType,
      String? fileExtension,
      String? error,
      bool sessionExpired,
    })
  >
  downloadFile({required String contentVersionId}) async {
    if (kDebugMode) {
      print(
        '[OpportunityService] Calling downloadSalesforceFile Cloud Function. contentVersionId: $contentVersionId',
      );
    }
    try {
      final String? accessToken = await _authNotifier.getValidAccessToken();
      final String? instanceUrl = _authNotifier.currentInstanceUrl;

      if (accessToken == null || instanceUrl == null) {
        if (kDebugMode) {
          print(
            '[OpportunityService] Missing Salesforce credentials for file download (token or instanceUrl is null)',
          );
        }
        return (
          fileData: null,
          contentType: null,
          fileExtension: null,
          error: 'Salesforce credentials missing or invalid.',
          sessionExpired: true,
        );
      }

      final HttpsCallable callable = _functions.httpsCallable(
        'downloadSalesforceFile', // The name of the Cloud Function
      );
      final result = await callable.call<Map<String, dynamic>>({
        'contentVersionId': contentVersionId,
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
      });

      final Map<String, dynamic>? data =
          result.data['data'] as Map<String, dynamic>?;
      final bool success = result.data['success'] as bool? ?? false;

      if (success && data != null && data['fileData'] != null) {
        final String base64String = data['fileData'] as String;
        final String? contentType = data['contentType'] as String?;
        final String? fileExtension = data['fileExtension'] as String?;
        if (kDebugMode) {
          print(
            '[OpportunityService] Successfully downloaded file data. contentType: $contentType',
          );
        }
        try {
          final Uint8List fileBytes = base64Decode(base64String);
          return (
            fileData: fileBytes,
            contentType: contentType,
            fileExtension: fileExtension,
            error: null,
            sessionExpired: false,
          );
        } catch (e) {
          if (kDebugMode) {
            print('[OpportunityService] Error decoding Base64 file data: $e');
          }
          return (
            fileData: null,
            contentType: null,
            fileExtension: null,
            error: 'Failed to process downloaded file data.',
            sessionExpired: false,
          );
        }
      } else {
        if (kDebugMode) {
          print(
            '[OpportunityService] downloadSalesforceFile function returned success=false or missing data. Result: ${result.data}',
          );
        }
        return (
          fileData: null,
          contentType: null,
          fileExtension: null,
          error: 'Cloud function failed to download file.',
          sessionExpired: false,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] FirebaseFunctionsException calling downloadSalesforceFile: Code=${e.code}, Msg=${e.message}, Details=${e.details}',
        );
      }
      bool sessionExpired =
          (e.details as Map? ?? {})['sessionExpired'] == true ||
          e.code == 'unauthenticated';
      String message =
          sessionExpired
              ? 'Salesforce session expired. Please log in again.'
              : e.message ?? 'Failed to download file.';
      if (sessionExpired) {
        _handleSalesforceSessionExpiry();
      }
      return (
        fileData: null,
        contentType: null,
        fileExtension: null,
        error: message,
        sessionExpired: sessionExpired,
      );
    } catch (e) {
      if (kDebugMode) {
        print(
          '[OpportunityService] Unexpected error calling downloadSalesforceFile: $e',
        );
      }
      return (
        fileData: null,
        contentType: null,
        fileExtension: null,
        error: 'An unexpected error occurred.',
        sessionExpired: false,
      );
    }
  }
  // --- END ADDED METHOD ---

  // --- ADDED: Helper to handle session expiry ---
  Future<void> _handleSalesforceSessionExpiry() async {
    if (kDebugMode) {
      print('[OpportunityService] Handling Salesforce session expiry...');
    }
    await _authNotifier.signOut();
  }

  // --- END ADDED HELPER ---

  // --- NEW METHOD: Download File Data FOR RESELLERS (JWT Flow) ---
  Future<
    ({
      Uint8List? fileData,
      String? contentType,
      String? fileExtension,
      String? error,
      bool sessionExpired,
    })
  >
  downloadFileForReseller({required String contentVersionId}) async {
    if (kDebugMode) {
      print(
        '[OpportunityService] Calling downloadFileForReseller Cloud Function. contentVersionId: $contentVersionId',
      );
    }
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'downloadFileForReseller', // The name of the Cloud Function for resellers
      );
      final result = await callable.call<Map<String, dynamic>>({
        'contentVersionId': contentVersionId,
      });

      final Map<String, dynamic>? data =
          result.data['data'] as Map<String, dynamic>?;
      final bool success = result.data['success'] as bool? ?? false;

      if (success && data != null) {
        // Decode the base64 file data
        final String? base64Data = data['fileData'] as String?;
        if (base64Data != null) {
          final Uint8List fileBytes = base64Decode(base64Data);
          if (kDebugMode) {
            print(
              '[OpportunityService] Successfully downloaded file via downloadFileForReseller. Size: ${fileBytes.length} bytes',
            );
          }
          return (
            fileData: fileBytes,
            contentType: data['contentType'] as String?,
            fileExtension: data['fileExtension'] as String?,
            error: null,
            sessionExpired: false,
          );
        }
      }

      // Handle unsuccessful response
      final String errorMsg = result.data['error'] as String? ?? 'Unknown error from downloadFileForReseller';
      if (kDebugMode) {
        print('[OpportunityService] downloadFileForReseller error: $errorMsg');
      }
      return (
        fileData: null,
        contentType: null,
        fileExtension: null,
        error: errorMsg,
        sessionExpired: false,
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] FirebaseFunctionsException in downloadFileForReseller:');
        print('  Code: ${e.code}');
        print('  Message: ${e.message}');
        print('  Details: ${e.details}');
      }

      // Check for session expiry or auth issues
      if ((e.details as Map<String, dynamic>?)?['sessionExpired'] == true ||
          e.code == 'unauthenticated') {
        return (
          fileData: null,
          contentType: null,
          fileExtension: null,
          error: 'Salesforce session expired. Please re-authenticate.',
          sessionExpired: true,
        );
      }

      return (
        fileData: null,
        contentType: null,
        fileExtension: null,
        error: 'Cloud Function error: ${e.message ?? e.code}',
        sessionExpired: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[OpportunityService] Generic error in downloadFileForReseller: $e');
      }
      return (
        fileData: null,
        contentType: null,
        fileExtension: null,
        error: 'An unexpected error occurred while downloading the file.',
        sessionExpired: false,
      );
    }
  }
}
