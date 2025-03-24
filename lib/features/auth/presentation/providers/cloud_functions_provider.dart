import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Indicates whether Cloud Functions are available and successfully connected
final cloudFunctionsAvailableProvider = Provider<bool>((ref) {
  // Default value, will be overridden in main.dart with actual availability
  return false;
});
