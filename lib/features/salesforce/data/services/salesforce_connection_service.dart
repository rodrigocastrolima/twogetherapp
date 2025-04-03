import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SalesforceConnectionService {
  // TODO: Replace these with your actual values from your Salesforce Connected App
  static const String clientId =
      '3MVG9T46ZAw5GTfWlGzpUr1bL14rAr48fglmDfgf4oWyIBerrrJBQz21SWPWmYoRGJqBzULovmWZ2ROgCyixB';
  static const String clientSecret =
      'A8DEF0E44455CB442078B1111CD88E6C54E1666620B6C060DABA986FEBB3AE54';

  // Salesforce endpoints
  static const String loginUrl =
      'https://login.salesforce.com/services/oauth2/token';
  static const String testLoginUrl =
      'https://test.salesforce.com/services/oauth2/token';

  // Storage keys
  static const String accessTokenKey = 'salesforce_access_token';
  static const String refreshTokenKey = 'salesforce_refresh_token';
  static const String instanceUrlKey = 'salesforce_instance_url';
  static const String userIdKey = 'salesforce_user_id';
  static const String orgIdKey = 'salesforce_org_id';

  // For secure storage
  final _storage = const FlutterSecureStorage();

  // Status
  bool _isConnected = false;
  String? _accessToken;
  String? _refreshToken;
  String? _instanceUrl;
  String? _userId;
  String? _orgId;

  // Singleton pattern
  static final SalesforceConnectionService _instance =
      SalesforceConnectionService._internal();

  factory SalesforceConnectionService() {
    return _instance;
  }

  SalesforceConnectionService._internal();

  // Getters
  bool get isConnected => _isConnected;
  String? get instanceUrl => _instanceUrl;
  String? get userId => _userId;
  String? get orgId => _orgId;

  // Get Access Token with automatic refresh if needed
  Future<String?> get accessToken async {
    if (_accessToken == null) {
      return null;
    }

    // Check if token needs to be refreshed
    try {
      final response = await http.get(
        Uri.parse('$_instanceUrl/services/data/v58.0/'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode != 200) {
        // Token expired, try to refresh
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          return null;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking token validity: $e');
      }
      // Try to refresh on error
      await _refreshAccessToken();
    }

    return _accessToken;
  }

  // Initialize by checking for existing credentials
  Future<bool> initialize() async {
    try {
      if (kDebugMode) {
        print('SalesforceConnectionService: Starting initialization...');
      }

      _accessToken = await _storage.read(key: accessTokenKey);
      _refreshToken = await _storage.read(key: refreshTokenKey);
      _instanceUrl = await _storage.read(key: instanceUrlKey);
      _userId = await _storage.read(key: userIdKey);
      _orgId = await _storage.read(key: orgIdKey);

      if (kDebugMode) {
        print('SalesforceConnectionService: Stored tokens found:');
        print('  - Access token exists: ${_accessToken != null}');
        print('  - Refresh token exists: ${_refreshToken != null}');
        print('  - Instance URL: ${_instanceUrl ?? "None"}');
      }

      _isConnected = _accessToken != null && _instanceUrl != null;

      if (_isConnected) {
        // Validate the connection with a simple API call
        if (kDebugMode) {
          print('SalesforceConnectionService: Testing existing token...');
        }
        _isConnected = await testConnection();
        if (kDebugMode) {
          print(
            'SalesforceConnectionService: Test connection result: $_isConnected',
          );
        }

        // If token validation failed, try to refresh it
        if (!_isConnected) {
          if (kDebugMode) {
            print(
              'SalesforceConnectionService: Token validation failed, trying to refresh token...',
            );
          }
          _isConnected = await refreshTokenUsingFirebaseFunction();
          if (kDebugMode) {
            print(
              'SalesforceConnectionService: Token refresh result: $_isConnected',
            );
          }
        }
      } else {
        // No stored tokens, try to get a fresh token
        if (kDebugMode) {
          print(
            'SalesforceConnectionService: No valid tokens, trying to get a fresh token...',
          );
        }
        _isConnected = await refreshTokenUsingFirebaseFunction();
        if (kDebugMode) {
          print(
            'SalesforceConnectionService: Fresh token acquisition result: $_isConnected',
          );
        }
      }

      if (kDebugMode) {
        print(
          'SalesforceConnectionService: Initialization complete. Connected: $_isConnected',
        );
      }

      return _isConnected;
    } catch (e) {
      if (kDebugMode) {
        print(
          'SalesforceConnectionService: Error initializing Salesforce connection: $e',
        );
      }
      return false;
    }
  }

  // Get a fresh token using Firebase Function
  Future<bool> refreshTokenUsingFirebaseFunction() async {
    try {
      if (kDebugMode) {
        print(
          'SalesforceConnectionService: Attempting to get token via Firebase Function...',
        );
        // Log platform information to help diagnose issues
        print(
          'SalesforceConnectionService: Platform: ${kIsWeb ? 'Web' : 'Native'}',
        );
      }

      // Try with region specification - US-Central1 is the default
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      if (kDebugMode) {
        print(
          'SalesforceConnectionService: Firebase Functions instance created, getting callable...',
        );
      }

      // Call our Firebase function that handles JWT generation and token exchange
      final HttpsCallable callable = functions.httpsCallable(
        'getSalesforceAccessToken',
      );

      if (kDebugMode) {
        print('SalesforceConnectionService: Calling Firebase function...');
      }

      // Add a timeout to prevent hanging indefinitely
      final resultFuture = callable.call();
      final timeoutFuture = Future.delayed(const Duration(seconds: 30), () {
        throw TimeoutException(
          'Firebase function call timed out after 30 seconds',
        );
      });

      final result = await Future.any([resultFuture, timeoutFuture]);

      if (kDebugMode) {
        print('SalesforceConnectionService: Firebase Function call complete');
        print(
          'SalesforceConnectionService: Result data type: ${result.data.runtimeType}',
        );

        // Log existence of fields without exposing the actual token
        if (result.data != null && result.data is Map) {
          print('SalesforceConnectionService: Response contains:');
          print(
            '  - access_token exists: ${result.data['access_token'] != null}',
          );
          print(
            '  - instance_url exists: ${result.data['instance_url'] != null}',
          );
          if (result.data['access_token'] != null) {
            print(
              '  - access_token length: ${result.data['access_token'].toString().length}',
            );
          }
        } else {
          print(
            'SalesforceConnectionService: Result data is not a Map: ${result.data}',
          );
        }
      }

      if (result.data != null) {
        final data = result.data;

        if (data['access_token'] != null && data['instance_url'] != null) {
          _accessToken = data['access_token'];
          _instanceUrl = data['instance_url'];

          if (kDebugMode) {
            print('SalesforceConnectionService: Token received:');
            print('  - Token length: ${_accessToken?.length ?? 0}');
            print('  - Instance URL: $_instanceUrl');
          }

          // Store the new token
          await _storage.write(key: accessTokenKey, value: _accessToken);
          await _storage.write(key: instanceUrlKey, value: _instanceUrl);

          _isConnected = true;

          if (kDebugMode) {
            print(
              'SalesforceConnectionService: Successfully obtained Salesforce token',
            );
          }

          return true;
        } else {
          if (kDebugMode) {
            print(
              'SalesforceConnectionService: Function returned data but missing required fields',
            );
            print(
              'SalesforceConnectionService: Has access_token: ${data['access_token'] != null}',
            );
            print(
              'SalesforceConnectionService: Has instance_url: ${data['instance_url'] != null}',
            );
          }
        }
      } else {
        if (kDebugMode) {
          print('SalesforceConnectionService: Function returned null data');
        }
      }

      if (kDebugMode) {
        print('SalesforceConnectionService: Failed to obtain Salesforce token');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print(
          'SalesforceConnectionService: Error getting token via Firebase Function: $e',
        );

        if (e is FirebaseFunctionsException) {
          print(
            'SalesforceConnectionService: Firebase Function error code: ${e.code}',
          );
          print(
            'SalesforceConnectionService: Firebase Function error details: ${e.details}',
          );
          print(
            'SalesforceConnectionService: Firebase Function error message: ${e.message}',
          );
        } else if (e is TimeoutException) {
          print(
            'SalesforceConnectionService: Firebase Function call timed out',
          );
        }
      }
      return false;
    }
  }

  // Connect to Salesforce with username and password
  Future<bool> connect(
    String username,
    String password, {
    bool isSandbox = false,
  }) async {
    try {
      final loginEndpoint = isSandbox ? testLoginUrl : loginUrl;

      final response = await http.post(
        Uri.parse(loginEndpoint),
        body: {
          'grant_type': 'password',
          'client_id': clientId,
          'client_secret': clientSecret,
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _instanceUrl = data['instance_url'];
        _userId = data['id']?.toString();

        // Extract org ID from the ID URL
        if (_userId != null) {
          final parts = _userId!.split('/');
          if (parts.length > 7) {
            _orgId = parts[4];
          }
        }

        // Store credentials securely
        await _storage.write(key: accessTokenKey, value: _accessToken);
        if (_refreshToken != null) {
          await _storage.write(key: refreshTokenKey, value: _refreshToken);
        }
        await _storage.write(key: instanceUrlKey, value: _instanceUrl);
        if (_userId != null) {
          await _storage.write(key: userIdKey, value: _userId);
        }
        if (_orgId != null) {
          await _storage.write(key: orgIdKey, value: _orgId);
        }

        _isConnected = true;

        if (kDebugMode) {
          print('Connected to Salesforce: $_instanceUrl');
          print('User ID: $_userId');
          print('Org ID: $_orgId');
        }

        return true;
      } else {
        if (kDebugMode) {
          print('Failed to connect to Salesforce: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to Salesforce: $e');
      }
      return false;
    }
  }

  // Refresh the access token using the refresh token
  Future<bool> _refreshAccessToken() async {
    // Try using Firebase Function first (JWT flow)
    final success = await refreshTokenUsingFirebaseFunction();
    if (success) {
      return true;
    }

    // Fall back to refresh token flow if available
    if (_refreshToken == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        body: {
          'grant_type': 'refresh_token',
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': _refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _accessToken = data['access_token'];
        // Store the new access token
        await _storage.write(key: accessTokenKey, value: _accessToken);

        return true;
      } else {
        if (kDebugMode) {
          print('Failed to refresh token: ${response.body}');
        }
        // Clear the tokens as they're no longer valid
        await disconnect();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing token: $e');
      }
      return false;
    }
  }

  // Disconnect and clear stored credentials
  Future<void> disconnect() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
    await _storage.delete(key: instanceUrlKey);
    await _storage.delete(key: userIdKey);
    await _storage.delete(key: orgIdKey);

    _accessToken = null;
    _refreshToken = null;
    _instanceUrl = null;
    _userId = null;
    _orgId = null;
    _isConnected = false;
  }

  // Simple test connection
  Future<bool> testConnection() async {
    if (_accessToken == null || _instanceUrl == null) {
      return false;
    }

    try {
      // Simple API call to test the connection
      final response = await http.get(
        Uri.parse('$_instanceUrl/services/data/v58.0/'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error testing connection: $e');
      }
      return false;
    }
  }

  // Make a GET request to Salesforce API
  Future<Map<String, dynamic>?> get(String path) async {
    final token = await accessToken;
    if (token == null || _instanceUrl == null) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_instanceUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
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

  // Make a POST request to Salesforce API
  Future<Map<String, dynamic>?> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final token = await accessToken;
    if (token == null || _instanceUrl == null) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_instanceUrl$path'),
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

  // Make a PATCH request to Salesforce API
  Future<Map<String, dynamic>?> patch(
    String path,
    Map<String, dynamic> data,
  ) async {
    final token = await accessToken;
    if (token == null || _instanceUrl == null) {
      return null;
    }

    try {
      final response = await http.patch(
        Uri.parse('$_instanceUrl$path'),
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

  // Make a DELETE request to Salesforce API
  Future<bool> delete(String path) async {
    final token = await accessToken;
    if (token == null || _instanceUrl == null) {
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('$_instanceUrl$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
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
