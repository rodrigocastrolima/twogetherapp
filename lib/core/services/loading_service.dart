import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/loading_overlay.dart';

/// Service to manage loading state across the app
class LoadingService {
  BuildContext? _overlayContext;
  bool _isLoading = false;

  /// Shows a loading overlay with the given message
  void show(
    BuildContext context, {
    String? message,
    bool showLogo = true,
    Color? backgroundColor,
    Color? progressColor,
  }) {
    if (_isLoading) return;

    _isLoading = true;
    LoadingOverlay.show(
      context,
      message: message,
      showLogo: showLogo,
      backgroundColor: backgroundColor,
      progressColor: progressColor,
    );
    _overlayContext = context;
  }

  /// Hides the currently displayed loading overlay
  void hide() {
    if (!_isLoading || _overlayContext == null) return;

    LoadingOverlay.hide(_overlayContext!);
    _isLoading = false;
    _overlayContext = null;
  }

  /// Runs the given async function while showing a loading overlay
  /// Returns the result of the function
  Future<T> runWithLoading<T>(
    BuildContext context,
    Future<T> Function() asyncFunction, {
    String? message,
    bool showLogo = true,
    Color? backgroundColor,
    Color? progressColor,
  }) async {
    show(
      context,
      message: message,
      showLogo: showLogo,
      backgroundColor: backgroundColor,
      progressColor: progressColor,
    );

    try {
      final result = await asyncFunction();
      hide();
      return result;
    } catch (e) {
      hide();
      rethrow;
    }
  }

  /// Whether a loading overlay is currently being displayed
  bool get isLoading => _isLoading;
}

/// Provider for the loading service
final loadingServiceProvider = Provider<LoadingService>((ref) {
  return LoadingService();
});

/// Example extension methods for WidgetRef to easily access the loading service
extension LoadingServiceRefExtension on WidgetRef {
  /// Shows a loading overlay
  void showLoading(
    BuildContext context, {
    String? message,
    bool showLogo = true,
    Color? backgroundColor,
    Color? progressColor,
  }) {
    read(loadingServiceProvider).show(
      context,
      message: message,
      showLogo: showLogo,
      backgroundColor: backgroundColor,
      progressColor: progressColor,
    );
  }

  /// Hides the currently displayed loading overlay
  void hideLoading() {
    read(loadingServiceProvider).hide();
  }

  /// Runs the given async function while showing a loading overlay
  Future<T> runWithLoading<T>(
    BuildContext context,
    Future<T> Function() asyncFunction, {
    String? message,
    bool showLogo = true,
    Color? backgroundColor,
    Color? progressColor,
  }) {
    return read(loadingServiceProvider).runWithLoading(
      context,
      asyncFunction,
      message: message,
      showLogo: showLogo,
      backgroundColor: backgroundColor,
      progressColor: progressColor,
    );
  }
}
