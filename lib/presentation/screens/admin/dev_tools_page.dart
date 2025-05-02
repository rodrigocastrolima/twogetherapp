import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/theme.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../core/services/loading_service.dart';

class DevToolsPage extends ConsumerStatefulWidget {
  const DevToolsPage({super.key});

  @override
  ConsumerState<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends ConsumerState<DevToolsPage> {
  // --- Function to call the Cloud Function ---
  Future<void> _runConversationReset(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final loadingService = ref.read(loadingServiceProvider);
    final navigator = GoRouter.of(
      context,
    ); // Use GoRouter for navigation if needed

    // --- Confirmation Dialog ---
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
            title: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Confirm Reset',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
            content: Text(
              'This will delete ALL non-default messages and reset conversations for ALL resellers. This action cannot be undone. It is strongly recommended to back up your Firestore data first. Proceed?',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancelar'),
                onPressed:
                    () =>
                        Navigator.of(dialogContext).pop(false), // Return false
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                child: const Text('Reset Conversations'),
                onPressed:
                    () => Navigator.of(dialogContext).pop(true), // Return true
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return; // User cancelled
    }

    // --- Show Loading ---
    loadingService.show(context, message: 'Resetting conversations...');

    // *** ADDED: Verify auth state before calling ***
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode)
        print('DevTools Error: User is null, cannot call function.');
      loadingService.hide();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Error: User is not authenticated. Please log in again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    // *** END Added Check ***

    try {
      // --- Call Cloud Function ---
      HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('resetAndVerifyConversations');
      final result = await callable.call();

      // --- Hide Loading & Show Success ---
      // Check if widget is still mounted before interacting with context
      if (!mounted) return;
      loadingService.hide(); // Hide loading before showing snackbar

      final data = result.data as Map<String, dynamic>?; // Cast result data
      final message = data?['message'] ?? 'Operation completed.';
      final created = data?['created'] ?? 0;
      final kept = data?['kept'] ?? 0;
      final deleted = data?['deleted'] ?? 0;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            '$message Created: $created, Kept: $kept, Deleted: $deleted',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode)
        print('Cloud Functions Exception: ${e.code} - ${e.message}');
      if (!mounted) return;
      loadingService.hide();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.message ?? "Failed to reset conversations."}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Generic Error calling function: $e');
      if (!mounted) return;
      loadingService.hide();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final l10n = AppLocalizations.of(context)!; // Ensure this is removed or commented out

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Tools'), // TODO: Localize
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Reset Conversations Button ---
            _buildDevActionCard(
              title: 'Reset Conversations', // TODO: Localize
              description:
                  'Deletes all non-default messages and ensures one conversation per reseller. Recommended to backup first.', // TODO: Localize
              icon: CupertinoIcons.trash_fill,
              buttonText: 'Run Reset', // TODO: Localize
              onPressed: () => _runConversationReset(context, ref),
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            // --- Add other dev action cards here ---
            // Example:
            // _buildDevActionCard(
            //   title: 'Another Dev Action',
            //   description: 'Description of what this does.',
            //   icon: CupertinoIcons.gear_alt_fill,
            //   buttonText: 'Run Action',
            //   onPressed: () { /* Call another function */ },
            // ),
          ],
        ),
      ),
    );
  }

  // Helper widget for styling the action cards on this page
  Widget _buildDevActionCard({
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final actionColor = color ?? theme.colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: actionColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: actionColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: Icon(CupertinoIcons.play_arrow_solid, size: 16),
                label: Text(buttonText),
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
