import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Conditional import for dart:html
import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;

// --- Configuration ---
const String _clientId =
    '3MVG9T46ZAw5GTfWlGzpUr1bL14rAr48fglmDfgf4oWyIBerrrJBQz21SWPWmYoRGJqBzULovmWZ2ROgCyixB';

// Define platform-specific redirect URIs
const String _mobileRedirectUri = 'com.twogether.app://oauth-callback';
// !! IMPORTANT: Using hash-based redirect for web !!
// !! IMPORTANT: Ensure this exact URI is added to Salesforce Connected App Callback URLs !!
const String _webRedirectUri =
    'http://localhost:5000/#/callback'; // Changed path to hash fragment

// Select the correct redirect URI based on the platform
final String _redirectUri = kIsWeb ? _webRedirectUri : _mobileRedirectUri;
// Define the callback scheme needed by flutter_web_auth_2 (null for web)
final String? _callbackUrlScheme =
    kIsWeb ? null : _mobileRedirectUri.split('://').first;

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
// Key for storing the PKCE code verifier temporarily during web redirect
const String _codeVerifierSessionKey = 'salesforce_pkce_verifier';

// Define keys used in main.dart for temporary storage
const String _tempSalesforceCodeKey = 'temp_sf_code';
const String _tempSalesforceVerifierKey = 'temp_sf_verifier';

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
      String? storedAccessToken;
      String? storedRefreshToken;
      String? storedInstanceUrl;
      String? storedExpiry;

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        storedAccessToken = prefs.getString(_accessTokenKey);
        storedRefreshToken = prefs.getString(_refreshTokenKey);
        storedInstanceUrl = prefs.getString(_instanceUrlKey);
        storedExpiry = prefs.getString(_tokenExpiryKey);
      } else {
        storedAccessToken = await _storage.read(key: _accessTokenKey);
        storedRefreshToken = await _storage.read(key: _refreshTokenKey);
        storedInstanceUrl = await _storage.read(key: _instanceUrlKey);
        storedExpiry = await _storage.read(key: _tokenExpiryKey);
      }

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
    final expiryString = expiryDate.toIso8601String();

    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, accessToken);
        await prefs.setString(_refreshTokenKey, refreshToken);
        await prefs.setString(_instanceUrlKey, instanceUrl);
        await prefs.setString(_tokenExpiryKey, expiryString);
      } else {
        await _storage.write(key: _accessTokenKey, value: accessToken);
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
        await _storage.write(key: _instanceUrlKey, value: instanceUrl);
        await _storage.write(key: _tokenExpiryKey, value: expiryString);
      }

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
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_accessTokenKey);
        await prefs.remove(_refreshTokenKey);
        await prefs.remove(_instanceUrlKey);
        await prefs.remove(_tokenExpiryKey);
      } else {
        await _storage.delete(key: _accessTokenKey);
        await _storage.delete(key: _refreshTokenKey);
        await _storage.delete(key: _instanceUrlKey);
        await _storage.delete(key: _tokenExpiryKey);
      }

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

    if (kIsWeb) {
      // --- WEB: Same-Tab Redirect Flow ---
      try {
        // Store the code verifier in sessionStorage before redirecting
        html.window.sessionStorage[_codeVerifierSessionKey] = codeVerifier;

        // Redirect the current browser tab to Salesforce
        html.window.location.href = authorizationUrl.toString();

        // Important: Code execution stops here for web as the page navigates away.
        // The rest of the flow (token exchange) happens after redirect back.
      } catch (e) {
        if (kDebugMode) {
          print('SalesforceAuthNotifier: Web redirect failed: $e');
        }
        _lastError = 'Web redirect failed: $e';
        state = SalesforceAuthState.error;
      }
    } else {
      // --- MOBILE: Use flutter_web_auth_2 (Popup/External Flow) ---
      try {
        final result = await FlutterWebAuth2.authenticate(
          url: authorizationUrl.toString(),
          callbackUrlScheme: _callbackUrlScheme!,
        );

        if (kDebugMode) {
          print('SalesforceAuthNotifier: Mobile auth result: $result');
        }

        final uri = Uri.parse(result);
        final authorizationCode = uri.queryParameters['code'];

        if (authorizationCode == null || authorizationCode.isEmpty) {
          throw Exception('Authorization code not found in callback URL.');
        }

        if (kDebugMode) {
          print('SalesforceAuthNotifier: Received authorization code.');
        }

        // Exchange code for tokens (passing the original verifier)
        await _exchangeCodeForTokens(authorizationCode, codeVerifier);
      } catch (e) {
        if (kDebugMode) {
          print('SalesforceAuthNotifier: Mobile sign in failed: $e');
        }
        _lastError = 'Mobile sign in failed: $e';
        // Avoid setting error state if user cancelled
        if (!e.toString().toLowerCase().contains('canceled') &&
            !e.toString().toLowerCase().contains('cancelled')) {
          state = SalesforceAuthState.error;
        } else {
          state =
              SalesforceAuthState
                  .unauthenticated; // Back to unauthenticated if cancelled
        }
      }
    }
  }

  /// Checks sessionStorage for temporary code/verifier from web callback
  /// and calls the Cloud Function to complete the login process.
  /// Should be called AFTER Firebase Auth state is confirmed.
  Future<void> checkAndCompleteWebLogin() async {
    if (!kIsWeb || state == SalesforceAuthState.authenticated) {
      // Only run on web, and only if not already authenticated
      return;
    }

    if (kDebugMode) {
      print('SalesforceAuthNotifier: Checking for pending web login...');
    }

    // Check sessionStorage for the temporary code and verifier
    final String? tempCode = html.window.sessionStorage[_tempSalesforceCodeKey];
    html.window.sessionStorage.remove(
      _tempSalesforceCodeKey,
    ); // Remove after getting

    final String? tempVerifier =
        html.window.sessionStorage[_tempSalesforceVerifierKey];
    html.window.sessionStorage.remove(
      _tempSalesforceVerifierKey,
    ); // Remove after getting

    if (tempCode != null &&
        tempVerifier != null &&
        tempCode.isNotEmpty &&
        tempVerifier.isNotEmpty) {
      // Found pending login data
      if (kDebugMode) {
        print(
          'SalesforceAuthNotifier: Found pending code and verifier. Calling Cloud Function...',
        );
      }
      // Set state to authenticating while calling function
      state = SalesforceAuthState.authenticating;
      _lastError = null;

      try {
        // Call the Cloud Function
        final HttpsCallable callable = FirebaseFunctions.instance
        // .useFunctionsEmulator('localhost', 5001) // Uncomment for emulator
        .httpsCallable('exchangeSalesforceCode');

        final result = await callable.call<Map<String, dynamic>>({
          'code': tempCode,
          'verifier': tempVerifier,
        });

        // Process successful result
        final data = result.data;
        final String? accessToken = data['accessToken'] as String?;
        final String? instanceUrl = data['instanceUrl'] as String?;
        final String? refreshToken = data['refreshToken'] as String?;
        final int? expiresInSeconds = data['expiresInSeconds'] as int?;

        if (accessToken != null &&
            instanceUrl != null &&
            refreshToken != null &&
            expiresInSeconds != null) {
          if (kDebugMode) {
            print(
              'SalesforceAuthNotifier: Cloud Function successful. Storing tokens...',
            );
          }
          // Call _storeTokens with all required parameters
          await _storeTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            instanceUrl: instanceUrl,
            expiresInSeconds: expiresInSeconds,
          );
          state = SalesforceAuthState.authenticated;
          _initialSignInAttempted = true; // Mark sign-in as done
        } else {
          // Handle case where function succeeded but returned invalid data
          _lastError = 'Cloud Function returned incomplete token data.';
          if (kDebugMode) {
            print('SalesforceAuthNotifier: Error - $_lastError');
            print('Received data: $data');
          }
          state = SalesforceAuthState.error;
        }
      } on FirebaseFunctionsException catch (e) {
        // Handle Cloud Function specific errors
        _lastError =
            'Cloud Function call failed: Code [${e.code}] Message [${e.message}] Details [${e.details}]';
        if (kDebugMode) {
          print('SalesforceAuthNotifier: $_lastError');
        }
        state = SalesforceAuthState.error;
      } catch (e) {
        // Handle other errors
        _lastError = 'Error during web login completion: $e';
        if (kDebugMode) {
          print('SalesforceAuthNotifier: $_lastError');
        }
        state = SalesforceAuthState.error;
      }
    } else {
      if (kDebugMode) {
        // This case is normal if the app loads without a pending callback
        // print('SalesforceAuthNotifier: No pending web login found in session storage.');
      }
      // If state was unknown/authenticating, set to unauthenticated if no code found
      if (state == SalesforceAuthState.unknown ||
          state == SalesforceAuthState.authenticating) {
        state = SalesforceAuthState.unauthenticated;
      }
    }
    // Always notify at the end to reflect final state
  }

  /// Exchanges mobile auth code for tokens directly (no cloud function)
  Future<void> _exchangeCodeForTokens(
    String authorizationCode,
    String codeVerifier,
  ) async {
    try {
      // 5. Exchange Authorization Code for Tokens
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': authorizationCode,
          'client_id': _clientId,
          'redirect_uri':
              _redirectUri, // Must match the URI used in the auth request
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
      // Re-throw the exception to be caught by the calling method (signIn or handleWebCallback)
      rethrow;
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
        print(
          'SalesforceAuthNotifier: No refresh token available. Cannot refresh.',
        );
      }
      // If we have no refresh token, we can't refresh anywhere.
      // Consider clearing tokens if state suggests we should have one.
      // await _clearTokens(); // Optional: Force logout if refresh is needed but impossible
      state =
          SalesforceAuthState.unauthenticated; // Ensure state reflects reality
      return false;
    }

    if (kIsWeb) {
      // --- WEB: Use Cloud Function for Refresh ---
      if (kDebugMode) {
        print(
          'SalesforceAuthNotifier: Attempting web token refresh via Cloud Function...',
        );
      }
      state =
          SalesforceAuthState.authenticating; // Indicate refresh is in progress
      _lastError = null;

      try {
        final HttpsCallable callable = FirebaseFunctions.instance
        // .useFunctionsEmulator('localhost', 5001) // Uncomment for emulator
        .httpsCallable('refreshSalesforceToken');

        final result = await callable.call<Map<String, dynamic>>({
          'refreshToken': _refreshToken!,
        });

        final data = result.data;
        final String? newAccessToken = data['accessToken'] as String?;
        final String? newInstanceUrl = data['instanceUrl'] as String?;
        final int? expiresInFromCloud = data['expiresInSeconds'] as int?;

        final int effectiveExpiresIn = expiresInFromCloud ?? 7200; // Default to 2 hours

        if (newAccessToken != null && newInstanceUrl != null) {
          if (kDebugMode) {
            print(
              'SalesforceAuthNotifier: Web token refresh via Cloud Function successful.',
            );
          }
          await _storeTokens(
            accessToken: newAccessToken,
            refreshToken: _refreshToken!, // Reuse existing refresh token
            instanceUrl: newInstanceUrl,
            expiresInSeconds: effectiveExpiresIn,
          );
          state = SalesforceAuthState.authenticated;
          return true;
        } else {
          _lastError =
              'Web refresh failed: Cloud Function returned incomplete data.';
          if (kDebugMode) {
            print('SalesforceAuthNotifier: Error - $_lastError');
            print('Received data: $data');
          }
          // Decide on state: could be error, or unauthenticated if token is likely invalid
          state = SalesforceAuthState.error;
          // Potentially clear tokens if the refresh grant seems invalid
          // await _clearTokens();
          return false;
        }
      } on FirebaseFunctionsException catch (e) {
        _lastError =
            'Web refresh Cloud Function failed: Code [${e.code}] Message [${e.message}] Details [${e.details}]';
        if (kDebugMode) {
          print('SalesforceAuthNotifier: $_lastError');
        }
        // Check if the error indicates an invalid refresh token
        if (e.code == 'functions-error' &&
            e.message != null &&
            (e.message!.contains('invalid_grant') ||
                e.message!.contains('refresh_token validity expired'))) {
          if (kDebugMode) {
            print(
              'SalesforceAuthNotifier: Invalid grant detected during web refresh. Clearing tokens.',
            );
          }
          await _clearTokens(); // Clear tokens and set state to unauthenticated
        } else {
          state = SalesforceAuthState.error; // Other function error
        }
        return false;
      } catch (e) {
        _lastError = 'Web refresh failed: Exception occurred: $e';
        if (kDebugMode) {
          print('SalesforceAuthNotifier: $_lastError');
        }
        state = SalesforceAuthState.error;
        return false;
      }
    } else {
      // --- MOBILE: Use Cloud Function for Refresh (now same as web) ---
      if (kDebugMode) {
        print(
          'SalesforceAuthNotifier: Attempting mobile token refresh via Cloud Function...',
        );
      }
      state =
          SalesforceAuthState.authenticating; // Indicate refresh is in progress
      _lastError = null;

      try {
        final HttpsCallable callable = FirebaseFunctions.instance
        // .useFunctionsEmulator('localhost', 5001) // Uncomment for emulator
        .httpsCallable('refreshSalesforceToken');

        final result = await callable.call<Map<String, dynamic>>({
          'refreshToken': _refreshToken!,
        });

        final data = result.data;
        final String? newAccessToken = data['accessToken'] as String?;
        final String? newInstanceUrl = data['instanceUrl'] as String?;
        final int? expiresInFromCloud = data['expiresInSeconds'] as int?;

        final int effectiveExpiresIn = expiresInFromCloud ?? 7200; // Default to 2 hours

        if (newAccessToken != null && newInstanceUrl != null) {
          if (kDebugMode) {
            print(
              'SalesforceAuthNotifier: Mobile token refresh via Cloud Function successful.',
            );
          }
          await _storeTokens(
            accessToken: newAccessToken,
            refreshToken: _refreshToken!, // Reuse existing refresh token
            instanceUrl: newInstanceUrl,
            expiresInSeconds: effectiveExpiresIn,
          );
          state = SalesforceAuthState.authenticated;
          return true;
        } else {
          _lastError =
              'Mobile refresh failed: Cloud Function returned incomplete data.';
          if (kDebugMode) {
            print('SalesforceAuthNotifier: Error - $_lastError');
            print('Received data: $data');
          }
          state = SalesforceAuthState.error;
          return false;
        }
      } on FirebaseFunctionsException catch (e) {
        _lastError =
            'Mobile refresh Cloud Function failed: Code [${e.code}] Message [${e.message}] Details [${e.details}]';
        if (kDebugMode) {
          print('SalesforceAuthNotifier: $_lastError');
        }
        if (e.code == 'functions-error' &&
            e.message != null &&
            (e.message!.contains('invalid_grant') ||
                e.message!.contains('refresh_token validity expired'))) {
          if (kDebugMode) {
            print(
              'SalesforceAuthNotifier: Invalid grant detected during mobile refresh (CF). Clearing tokens.',
            );
          }
          await _clearTokens();
        } else {
          state = SalesforceAuthState.error;
        }
        return false;
      } catch (e) {
        _lastError = 'Mobile refresh via CF failed: Exception: $e';
        if (kDebugMode) {
          print('SalesforceAuthNotifier: $_lastError');
        }
        state = SalesforceAuthState.error;
        return false;
      }
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
