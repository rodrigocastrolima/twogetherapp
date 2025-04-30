import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';

import 'package:twogether/core/services/salesforce_auth_service.dart';

class OpportunityService {
  final Logger logger = Logger();
  final SalesforceAuthNotifier _authNotifier;
  final FirebaseFunctions _functions;

  OpportunityService({
    required SalesforceAuthNotifier authNotifier,
    required FirebaseFunctions functions,
  }) : _authNotifier = authNotifier,
       _functions = functions;

  Future<({bool success, String? error, bool sessionExpired})> deleteFile({
    required String contentDocumentId,
  }) async {
    logger.w(
      'deleteFile function not implemented yet. contentDocumentId: $contentDocumentId',
    );
    return (success: false, error: 'Not implemented', sessionExpired: false);
  }

  // --- NEW METHOD: Download File Data ---
  Future<
    ({
      Uint8List? fileData,
      String? contentType,
      String? error,
      bool sessionExpired,
    })
  >
  downloadFile({required String contentVersionId}) async {
    logger.i(
      'Calling downloadSalesforceFile Cloud Function. contentVersionId: $contentVersionId',
    );
    try {
      final String? accessToken = await _authNotifier.getValidAccessToken();
      final String? instanceUrl = _authNotifier.currentInstanceUrl;

      if (accessToken == null || instanceUrl == null) {
        logger.w(
          'Missing Salesforce credentials for file download (token or instanceUrl is null)',
        );
        return (
          fileData: null,
          contentType: null,
          error: 'Salesforce credentials missing or invalid.',
          sessionExpired: true,
        );
      }

      final HttpsCallable callable = _functions.httpsCallable(
        'downloadSalesforceFile',
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
        logger.i(
          'Successfully downloaded file data. contentType: $contentType',
        );
        try {
          final Uint8List fileBytes = base64Decode(base64String);
          return (
            fileData: fileBytes,
            contentType: contentType,
            error: null,
            sessionExpired: false,
          );
        } catch (e, s) {
          logger.e('Error decoding Base64 file data', error: e, stackTrace: s);
          return (
            fileData: null,
            contentType: null,
            error: 'Failed to process downloaded file data.',
            sessionExpired: false,
          );
        }
      } else {
        logger.w(
          'downloadSalesforceFile function returned success=false or missing data. Result: ${result.data}',
        );
        return (
          fileData: null,
          contentType: null,
          error: 'Cloud function failed to download file.',
          sessionExpired: false,
        );
      }
    } on FirebaseFunctionsException catch (e, s) {
      logger.e(
        'FirebaseFunctionsException calling downloadSalesforceFile',
        error: e,
        stackTrace: s,
      );
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
        error: message,
        sessionExpired: sessionExpired,
      );
    } catch (e, s) {
      logger.e(
        'Unexpected error calling downloadSalesforceFile',
        error: e,
        stackTrace: s,
      );
      return (
        fileData: null,
        contentType: null,
        error: 'An unexpected error occurred.',
        sessionExpired: false,
      );
    }
  }
  // --- END NEW METHOD ---

  // Helper to handle session expiry
  Future<void> _handleSalesforceSessionExpiry() async {
    logger.i('Handling Salesforce session expiry...');
    await _authNotifier.signOut();
  }
}
