import 'dart:convert';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Import the SalesforceAuthNotifier provider
import '../../../../core/services/salesforce_auth_service.dart';

class SalesforceConnectionService {
  final Ref _ref;

  // The SalesforceAuthNotifier will be our source of truth for auth state
  SalesforceAuthNotifier get _authNotifier => _ref.read(salesforceAuthProvider.notifier);

  // Constructor now takes a Ref
  SalesforceConnectionService(this._ref);

  // Expose the auth state directly if needed by consumers of this service
  SalesforceAuthState get authState => _ref.watch(salesforceAuthProvider);

  bool get isConnected => authState == SalesforceAuthState.authenticated;

  Future<String?> get instanceUrl async {
    await _authNotifier.getValidAccessToken();
    return _authNotifier.currentInstanceUrl;
  }

  Future<String?> get accessToken async {
    return await _authNotifier.getValidAccessToken();
  }

  Future<void> disconnect() async {
    await _authNotifier.signOut();
  }

  Future<bool> testConnection() async {
    final token = await accessToken;
    final currentInstanceUrl = await instanceUrl;

    if (token == null || currentInstanceUrl == null) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$currentInstanceUrl/services/data/v58.0/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error testing connection: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> get(String path) async {
    final token = await accessToken;
    final currentInstanceUrl = await instanceUrl;

    if (token == null || currentInstanceUrl == null) {
      print('Salesforce GET: No token or instance URL. Current auth state: ${_authNotifier.state}');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$currentInstanceUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        print('Salesforce GET error: 401 Unauthorized. Token might be invalid. Response: ${response.body}');
        return null;
      } else {
        if (kDebugMode) {
          print(
            'Salesforce GET error: ${response.statusCode} - ${response.body}',
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error making Salesforce GET request: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final token = await accessToken;
    final currentInstanceUrl = await instanceUrl;

    if (token == null || currentInstanceUrl == null) {
      print('Salesforce POST: No token or instance URL. Current auth state: ${_authNotifier.state}');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$currentInstanceUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body);
        }
        return {};
      } else if (response.statusCode == 401) {
        print('Salesforce POST error: 401 Unauthorized. Token might be invalid. Response: ${response.body}');
        return null;
      } else {
        if (kDebugMode) {
          print(
            'Salesforce POST error: ${response.statusCode} - ${response.body}',
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error making Salesforce POST request: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> patch(
    String path,
    Map<String, dynamic> data,
  ) async {
    final token = await accessToken;
    final currentInstanceUrl = await instanceUrl;

    if (token == null || currentInstanceUrl == null) {
      print('Salesforce PATCH: No token or instance URL. Current auth state: ${_authNotifier.state}');
      return null;
    }

    try {
      final response = await http.patch(
        Uri.parse('$currentInstanceUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body);
        }
        return {};
      } else if (response.statusCode == 401) {
        print('Salesforce PATCH error: 401 Unauthorized. Token might be invalid. Response: ${response.body}');
        return null;
      } else {
        if (kDebugMode) {
          print(
            'Salesforce PATCH error: ${response.statusCode} - ${response.body}',
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error making Salesforce PATCH request: $e');
      }
      return null;
    }
  }

  Future<bool> delete(String path) async {
    final token = await accessToken;
    final currentInstanceUrl = await instanceUrl;

    if (token == null || currentInstanceUrl == null) {
      print('Salesforce DELETE: No token or instance URL. Current auth state: ${_authNotifier.state}');
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('$currentInstanceUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else if (response.statusCode == 401) {
        print('Salesforce DELETE error: 401 Unauthorized. Token might be invalid. Response: ${response.body}');
        return false;
      } else {
        if (kDebugMode) {
          print(
            'Salesforce DELETE error: ${response.statusCode} - ${response.body}',
          );
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error making Salesforce DELETE request: $e');
      }
      return false;
    }
  }
}

// Define the provider for SalesforceConnectionService
final salesforceConnectionServiceProvider = Provider<SalesforceConnectionService>((ref) {
  return SalesforceConnectionService(ref);
});
