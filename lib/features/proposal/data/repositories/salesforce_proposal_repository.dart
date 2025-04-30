import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For HttpException
import 'package:http/http.dart' as http; // For API calls
import 'package:cloud_functions/cloud_functions.dart'; // Import Cloud Functions
import 'dart:typed_data'; // For Uint8List

import '../models/detailed_salesforce_proposal.dart';
import '../models/cpe_proposal_link.dart'; // Although parsing happens in DetailedSalesforceProposal.fromJson
import '../../../../features/opportunity/data/models/salesforce_file.dart'; // For file parsing
import '../models/proposal_file.dart'; // Use proposal file model

class SalesforceProposalRepository {
  // Base URL construction might be improved later (e.g., constants)
  // Version should ideally be configurable
  static const String _apiVersion = 'v58.0';

  // Get instance of Cloud Functions
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  /// Fetches detailed information for a specific proposal from Salesforce via Cloud Function.
  ///
  /// Requires a valid [accessToken] and the Salesforce [instanceUrl] to be passed TO the function.
  Future<DetailedSalesforceProposal> getProposalDetails({
    required String accessToken,
    required String instanceUrl,
    required String proposalId,
  }) async {
    try {
      // Get a callable function reference
      final callable = _functions.httpsCallable('getSalesforceProposalDetails');

      // Prepare the data to send to the function
      final Map<String, dynamic> data = {
        'proposalId': proposalId,
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
      };

      // Call the function
      final HttpsCallableResult result = await callable.call(data);

      // The result.data should be the raw JSON record returned by the function
      if (result.data == null) {
        throw Exception('Cloud function returned null data.');
      }

      // Parse the raw JSON data using the existing factory
      // Ensure the factory handles the exact structure returned by the function
      return DetailedSalesforceProposal.fromJson(
        result.data as Map<String, dynamic>,
      );
    } on FirebaseFunctionsException catch (e) {
      print(
        "FirebaseFunctionsException calling getSalesforceProposalDetails: Code[${e.code}] Message[${e.message}] Details[${e.details}]",
      );
      // Handle specific function errors (e.g., unauthenticated, not-found, internal)
      if (e.code == 'unauthenticated' && e.details?['sessionExpired'] == true) {
        throw Exception(
          'Salesforce session expired. Please re-authenticate.',
        ); // Or a custom exception
      }
      if (e.code == 'not-found') {
        throw Exception('Proposal not found via Cloud Function.');
      }
      // Rethrow as a generic exception or handle more specifically
      throw Exception('Cloud function error: ${e.message}');
    } catch (e) {
      // Handle any other errors (e.g., casting result.data)
      print("Error processing Cloud Function result: $e");
      throw Exception(
        'An unexpected error occurred while fetching proposal details: $e',
      );
    }
  }

  /// Updates specified fields for a proposal via Cloud Function.
  Future<void> updateProposal({
    required String accessToken,
    required String instanceUrl,
    required String proposalId,
    required Map<String, dynamic> fieldsToUpdate,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateSalesforceProposal');
      final Map<String, dynamic> data = {
        'proposalId': proposalId,
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'fieldsToUpdate': fieldsToUpdate,
      };

      await callable.call(data);
      // Assume success if no exception is thrown
      print("Successfully requested proposal update via Cloud Function.");
    } on FirebaseFunctionsException catch (e) {
      print(
        "FirebaseFunctionsException calling updateSalesforceProposal: Code[${e.code}] Message[${e.message}] Details[${e.details}]",
      );
      if (e.code == 'unauthenticated' && e.details?['sessionExpired'] == true) {
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      // Rethrow as a generic exception or handle more specifically
      throw Exception(
        'Cloud function error during proposal update: ${e.message}',
      );
    } catch (e) {
      print("Error calling update proposal function: $e");
      throw Exception(
        'An unexpected error occurred while updating proposal: $e',
      );
    }
  }

  /// Uploads a file to Salesforce associated with a parent record (Proposal).
  /// Returns the ContentDocumentId if successful.
  Future<String?> uploadFile({
    required String accessToken,
    required String instanceUrl,
    required String parentId, // proposalId
    required String fileName,
    required Uint8List fileBytes, // Expect Uint8List for base64 conversion
    String? mimeType,
  }) async {
    try {
      final callable = _functions.httpsCallable('uploadSalesforceFile');
      // Convert bytes to base64 string
      final String base64Content = base64Encode(fileBytes);

      final Map<String, dynamic> data = {
        'parentId': parentId,
        'fileName': fileName,
        'fileContentBase64': base64Content,
        // 'mimeType': mimeType, // Optional
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
      };

      final HttpsCallableResult result = await callable.call(data);

      if (result.data?['success'] == true) {
        print(
          "Successfully uploaded file via Cloud Function: ${result.data?['contentDocumentId']}",
        );
        // Return the ContentDocumentId
        return result.data?['contentDocumentId'] as String?;
      } else {
        throw Exception(
          result.data?['error'] ?? 'Unknown file upload error from function.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      print(
        "FirebaseFunctionsException calling uploadSalesforceFile: Code[${e.code}] Message[${e.message}] Details[${e.details}]",
      );
      if (e.code == 'unauthenticated' && e.details?['sessionExpired'] == true) {
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      if (e.code == 'invalid-argument' &&
          e.message?.contains('size limit') == true) {
        throw Exception('File size limit exceeded.');
      }
      throw Exception('Cloud function error during file upload: ${e.message}');
    } catch (e) {
      print("Error calling upload file function: $e");
      throw Exception('An unexpected error occurred while uploading file: $e');
    }
  }

  /// Deletes a file (ContentDocument) from Salesforce.
  Future<void> deleteFile({
    required String accessToken,
    required String instanceUrl,
    required String contentDocumentId,
  }) async {
    try {
      final callable = _functions.httpsCallable('deleteSalesforceFile');
      final Map<String, dynamic> data = {
        'contentDocumentId': contentDocumentId,
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
      };

      final HttpsCallableResult result = await callable.call(data);

      if (result.data?['success'] != true) {
        throw Exception(
          result.data?['error'] ?? 'Unknown file deletion error from function.',
        );
      }
      print("Successfully requested file deletion via Cloud Function.");
    } on FirebaseFunctionsException catch (e) {
      print(
        "FirebaseFunctionsException calling deleteSalesforceFile: Code[${e.code}] Message[${e.message}] Details[${e.details}]",
      );
      if (e.code == 'unauthenticated' && e.details?['sessionExpired'] == true) {
        throw Exception('Salesforce session expired. Please re-authenticate.');
      }
      if (e.code == 'not-found') {
        throw Exception('File not found or already deleted.');
      }
      if (e.code == 'permission-denied') {
        throw Exception('Insufficient permissions to delete this file.');
      }
      throw Exception(
        'Cloud function error during file deletion: ${e.message}',
      );
    } catch (e) {
      print("Error calling delete file function: $e");
      throw Exception('An unexpected error occurred while deleting file: $e');
    }
  }
}
