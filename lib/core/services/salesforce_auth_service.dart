import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

// --- Configuration ---
const String _clientId =
    '3MVG9T46ZAw5GTfWlGzpUr1bL14rAr48fglmDfgf4oWyIBerrrJBQz21SWPWmYoRGJqBzULovmWZ2ROgCyixB';
// TODO: Verify this redirect URI matches the Salesforce Connected App configuration
const String _redirectUri = 'com.twogether.app://oauth-callback';
const String _authorizationEndpoint =
    'https://ldfgrupo.my.salesforce.com/services/oauth2/authorize';
const String _tokenEndpoint =
    'https://ldfgrupo.my.salesforce.com/services/oauth2/token';
const List<String> _scopes = ['api', 'refresh_token', 'openid'];

// --- Secure Storage Keys ---
const String _accessTokenKey = 'salesforce_access_token';
const String _refreshTokenKey = 'salesforce_refresh_token';
const String _instanceUrlKey = 'salesforce_instance_url';
const String _tokenExpiryKey = 'salesforce_token_expiry';

// --- State Definition ---
enum SalesforceAuthState {
  unknown, // Initial state
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class SalesforceAuthNotifier extends StateNotifier<SalesforceAuthState> {
  SalesforceAuthNotifier(this._storage) : super(SalesforceAuthState.unknown) {
    _loadInitialState();
  }

  final FlutterSecureStorage _storage;

  String? _accessToken;
  String? _refreshToken;
  String? _instanceUrl;
  DateTime? _tokenExpiry;
  String? _lastError;
  bool _initialSignInAttempted = false; // Flag to track initial sign-in attempt

  // --- Public Getters ---
  String? get currentAccessToken => _accessToken;
  String? get currentInstanceUrl => _instanceUrl;
  String? get lastError => _lastError;
  bool get initialSignInAttempted =>
      _initialSignInAttempted; // Getter for the flag

  // Method to mark that the initial attempt has been made
  void markInitialSignInAttempted() {
    _initialSignInAttempted = true;
    // No need to notify listeners as this doesn't change the auth *state*
  }

  // --- Private Helper Methods (to be implemented) ---
  Future<void> _loadInitialState() async {
    if (kDebugMode) {
      print('SalesforceAuthNotifier: Loading initial state...');
    }
    try {
      final storedAccessToken = await _storage.read(key: _accessTokenKey);
      final storedRefreshToken = await _storage.read(key: _refreshTokenKey);
      final storedInstanceUrl = await _storage.read(key: _instanceUrlKey);
      final storedExpiry = await _storage.read(key: _tokenExpiryKey);

      if (storedAccessToken == null ||
          storedRefreshToken == null ||
          storedInstanceUrl == null ||
          storedExpiry == null) {
        if (kDebugMode) {
          print(
            'SalesforceAuthNotifier: No complete token set found in storage.',
          );
        }
        state = SalesforceAuthState.unauthenticated;
        await _clearTokens(); // Ensure partial tokens are removed (also resets flag)
        return;
      }

      final expiryDate = DateTime.tryParse(storedExpiry);
      if (expiryDate == null) {
        if (kDebugMode) {
          print('SalesforceAuthNotifier: Failed to parse stored expiry date.');
        }
        state = SalesforceAuthState.unauthenticated;
        await _clearTokens();
        return;
      }

      // Load into internal state
      _accessToken = storedAccessToken;
      _refreshToken = storedRefreshToken;
      _instanceUrl = storedInstanceUrl;
      _tokenExpiry = expiryDate;
      _initialSignInAttempted =
          true; // Tokens were found, so consider initial attempt done

      // Check if the access token is expired
      if (expiryDate.isBefore(DateTime.now())) {
        if (kDebugMode) {
          print(
            'SalesforceAuthNotifier: Access token expired. Attempting refresh...',
          );
        }
        // Attempt to refresh the token
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          if (kDebugMode) {
            print(
              'SalesforceAuthNotifier: Token refresh successful during init.',
            );
          }
          state = SalesforceAuthState.authenticated;
        } else {
          if (kDebugMode) {
            print('SalesforceAuthNotifier: Token refresh failed during init.');
          }
          // Refresh failed, treat as unauthenticated
          state = SalesforceAuthState.unauthenticated;
          await _clearTokens(); // Clear expired/invalid tokens
        }
      } else {
        if (kDebugMode) {
          print(
            'SalesforceAuthNotifier: Valid tokens found. State set to authenticated.',
          );
        }
        // Token is still valid
        state = SalesforceAuthState.authenticated;
      }
    } catch (e) {
      if (kDebugMode) {
        print('SalesforceAuthNotifier: Error loading initial state: $e');
      }
      _lastError = 'Failed to load initial state: $e';
      state = SalesforceAuthState.error;
      await _clearTokens(); // Clear potentially corrupted state (also resets flag)
    }
  }

  Future<void> _storeTokens({
    required String accessToken,
    required String refreshToken,
    required String instanceUrl,
    required int expiresInSeconds,
  }) async {
    final now = DateTime.now();
    // Add a small buffer (e.g., 5 minutes) to the expiry time
    final expiryDate = now.add(Duration(seconds: expiresInSeconds - 300));

    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      await _storage.write(key: _instanceUrlKey, value: instanceUrl);
      await _storage.write(
        key: _tokenExpiryKey,
        value: expiryDate.toIso8601String(),
      );

      // Update internal state
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _instanceUrl = instanceUrl;
      _tokenExpiry = expiryDate;

      if (kDebugMode) {
        print('Salesforce tokens stored successfully.');
        print('Access Token expires at: $expiryDate');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error storing Salesforce tokens: $e');
      }
      // Optionally handle storage error, maybe set state to error?
      _lastError = 'Failed to store tokens: $e';
      state = SalesforceAuthState.error;
    }
  }

  Future<void> _clearTokens() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _instanceUrlKey);
      await _storage.delete(key: _tokenExpiryKey);

      // Clear internal state
      _accessToken = null;
      _refreshToken = null;
      _instanceUrl = null;
      _tokenExpiry = null;
      _lastError = null;
      _initialSignInAttempted = false; // Reset flag on clear/logout

      state = SalesforceAuthState.unauthenticated;
      if (kDebugMode) {
        print('Salesforce tokens cleared.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing Salesforce tokens: $e');
      }
      _lastError = 'Failed to clear tokens: $e';
      // Don't necessarily set state to error here, maybe just log?
    }
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // --- Public Methods (to be implemented) ---
  Future<void> signIn() async {
    // Ensure we don't start multiple sign-ins
    if (state == SalesforceAuthState.authenticating) return;

    state = SalesforceAuthState.authenticating;
    _lastError = null; // Clear previous errors

    // 1. Generate PKCE codes
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // 2. Construct Authorization URL
    final authorizationUrl = Uri.parse(_authorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': _scopes.join(' '), // Scopes must be space-separated
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        // Optional: 'state' parameter for security (consider adding later if needed)
      },
    );

    if (kDebugMode) {
      print('SalesforceAuthNotifier: Launching auth URL: $authorizationUrl');
    }

    try {
      // 3. Launch Web Auth Flow
      final result = await FlutterWebAuth2.authenticate(
        url: authorizationUrl.toString(),
        callbackUrlScheme:
            Uri.parse(_redirectUri).scheme, // Extract scheme from redirect URI
        // Optional: preferEphemeral for iOS private session
        // preferEphemeral: true,
      );

      if (kDebugMode) {
        print('SalesforceAuthNotifier: Web auth result: $result');
      }

      // 4. Extract Authorization Code from the result (which is the full callback URL)
      final uri = Uri.parse(result);
      final authorizationCode = uri.queryParameters['code'];

      if (authorizationCode == null || authorizationCode.isEmpty) {
        throw Exception('Authorization code not found in callback URL.');
      }

      if (kDebugMode) {
        print('SalesforceAuthNotifier: Received authorization code.');
      }

      // 5. Exchange Authorization Code for Tokens
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': authorizationCode,
          'client_id': _clientId,
          'redirect_uri': _redirectUri,
          'code_verifier': codeVerifier, // Send the original verifier
        },
      );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final accessToken = responseBody['access_token'] as String?;
        final refreshToken = responseBody['refresh_token'] as String?;
        final instanceUrl = responseBody['instance_url'] as String?;
        final expiresIn = responseBody['expires_in']; // Usually int

        if (accessToken == null ||
            refreshToken == null ||
            instanceUrl == null ||
            expiresIn == null ||
            expiresIn is! int) {
          throw Exception('Incomplete token data received from Salesforce.');
        }

        if (kDebugMode) {
          print('SalesforceAuthNotifier: Token exchange successful.');
        }

        // 6. Store Tokens
        await _storeTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          instanceUrl: instanceUrl,
          expiresInSeconds: expiresIn,
        );

        // 7. Update State
        state = SalesforceAuthState.authenticated;
      } else {
        // Handle token exchange error
        final error = responseBody['error'] as String? ?? 'unknown_error';
        final errorDescription =
            responseBody['error_description'] as String? ?? 'No description.';
        throw Exception('Token exchange failed: $error ($errorDescription)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SalesforceAuthNotifier: Sign in failed: $e');
      }
      _lastError = 'Sign in failed: $e';
      state = SalesforceAuthState.error;
      // Don't clear tokens here, as they might not have been set or might be from a previous session
    }
  }

  Future<void> signOut() async {
    if (kDebugMode) {
      print('SalesforceAuthNotifier: Signing out...');
    }
    // Clear local tokens and update internal state/notifier state
    await _clearTokens();
    // State is set to unauthenticated within _clearTokens()
  }

  /// Returns a valid access token, attempting to refresh if expired.
  /// Returns null if not authenticated or refresh fails.
  Future<String?> getValidAccessToken() async {
    // If we don't have token info or expiry, we can't proceed.
    if (_accessToken == null || _tokenExpiry == null) {
      if (kDebugMode) {
        print('getValidAccessToken: No token or expiry available.');
      }
      return null;
    }

    // Check if the current token is expired
    if (_tokenExpiry!.isBefore(DateTime.now())) {
      if (kDebugMode) {
        print('getValidAccessToken: Token expired, attempting refresh...');
      }
      // Attempt to refresh
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        if (kDebugMode) {
          print(
            'getValidAccessToken: Refresh successful, returning new token.',
          );
        }
        // If refresh was successful, _accessToken is updated internally
        return _accessToken;
      } else {
        if (kDebugMode) {
          print('getValidAccessToken: Refresh failed.');
        }
        // Refresh failed
        return null;
      }
    } else {
      // Token is still valid
      if (kDebugMode) {
        print('getValidAccessToken: Current token is valid.');
      }
      return _accessToken;
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) {
      if (kDebugMode) {
        print('SalesforceAuthNotifier: No refresh token available to refresh.');
      }
      _lastError = 'Refresh failed: No refresh token available.';
      return false;
    }

    if (kDebugMode) {
      print('SalesforceAuthNotifier: Attempting to refresh access token...');
    }

    try {
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
          'client_id': _clientId,
          // No client_secret needed for refresh token grant if Connected App doesn't require it
        },
      );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final newAccessToken = responseBody['access_token'] as String?;
        final newInstanceUrl = responseBody['instance_url'] as String?;
        // Salesforce often doesn't return expires_in or a new refresh token on refresh.
        // Use a default expiry (e.g., 2 hours) and reuse the existing refresh token.
        const defaultExpiresIn = 7200; // 2 hours in seconds

        if (newAccessToken == null || newInstanceUrl == null) {
          if (kDebugMode) {
            print(
              'SalesforceAuthNotifier: Refresh response missing access_token or instance_url.',
            );
          }
          _lastError = 'Refresh failed: Incomplete token data received.';
          // Don't clear tokens here, maybe the old refresh token is still valid?
          return false;
        }

        if (kDebugMode) {
          print('SalesforceAuthNotifier: Token refresh successful.');
        }
        // Store the new access token, reusing the existing refresh token
        await _storeTokens(
          accessToken: newAccessToken,
          refreshToken: _refreshToken!, // Reuse existing refresh token
          instanceUrl: newInstanceUrl,
          expiresInSeconds: defaultExpiresIn,
        );
        _lastError = null; // Clear previous errors
        return true;
      } else {
        // Handle refresh error (e.g., refresh token revoked)
        final error = responseBody['error'] as String? ?? 'unknown_error';
        final errorDescription =
            responseBody['error_description'] as String? ?? 'No description.';
        _lastError = 'Refresh failed: $error ($errorDescription)';
        if (kDebugMode) {
          print(
            'SalesforceAuthNotifier: Token refresh failed. Status: ${response.statusCode}, Error: $error, Desc: $errorDescription',
          );
        }
        // If the grant is invalid (e.g., revoked token), clear everything
        if (error == 'invalid_grant') {
          await _clearTokens();
          // State is set to unauthenticated within _clearTokens
        } else {
          // For other errors, maybe don't clear tokens automatically?
          // Set state to error to indicate a problem
          state = SalesforceAuthState.error;
        }
        return false;
      }
    } catch (e) {
      _lastError = 'Refresh failed: Exception occurred: $e';
      if (kDebugMode) {
        print('SalesforceAuthNotifier: Exception during token refresh: $e');
      }
      state = SalesforceAuthState.error;
      return false;
    }
  }
}

// --- Riverpod Provider ---
final salesforceAuthProvider = StateNotifierProvider<
  SalesforceAuthNotifier,
  SalesforceAuthState
>((ref) {
  // TODO: Consider how to best provide FlutterSecureStorage instance if needed elsewhere
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return SalesforceAuthNotifier(storage);
});
