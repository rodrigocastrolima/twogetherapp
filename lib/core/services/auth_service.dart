import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Authentication state provider
final authStateProvider = StateProvider<bool>((ref) {
  return false; // Default to not authenticated
});

class AuthService {
  static const String _isAuthenticatedKey = 'is_authenticated';

  // Login the user and save to SharedPreferences
  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAuthenticatedKey, true);
  }

  // Logout the user and clear from SharedPreferences
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAuthenticatedKey, false);
  }

  // Check if the user is logged in
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAuthenticatedKey) ?? false;
  }
}
