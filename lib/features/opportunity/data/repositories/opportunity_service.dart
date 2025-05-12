import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

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
        final String? fileExtension = data['fileExtension'] as String?;
        if (kDebugMode) {
          print(
            '[OpportunityService] Successfully downloaded file data. contentType: $contentType, fileExtension: $fileExtension',
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
      logger.e(
        'FirebaseFunctionsException calling downloadSalesforceFile',
        error: e,
      );
      bool sessionExpired = false;
      if (e.code == 'unauthenticated' && e.details?['sessionExpired'] == true) {
        sessionExpired = true;
      }
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
      logger.e('Unexpected error calling downloadSalesforceFile', error: e);
      return (
        fileData: null,
        contentType: null,
        fileExtension: null,
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
