import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';


/// A widget that displays a success indicator (green checkmark) and a message.
class SuccessIndicator extends StatelessWidget {
  final String message;

  const SuccessIndicator({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.check_mark_circled_solid,
          color: Colors.green.shade400, // Consistent success green
          size: 64.0,
        ),
        const SizedBox(height: 20.0),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Shows a success dialog with a green checkmark and a message.
///
/// The dialog automatically dismisses after a short duration and calls [onDismissed].
Future<void> showSuccessDialog({
  required BuildContext context,
  required String message,
  required VoidCallback onDismissed,
  Duration duration = const Duration(
    milliseconds: 1800,
  ), // Auto-dismiss duration
}) async {
  // Use a Completer to know when the dialog is actually closed
  final completer = Completer<void>();

  unawaited(
    // Don't need to wait for the dialog Future itself
    showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        // Start a timer to auto-close the dialog
        final timer = Timer(duration, () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        // Use WillPopScope to ensure the timer is cancelled if manually closed (though unlikely here)
        return WillPopScope(
          onWillPop: () async {
            timer.cancel();
            return true; // Allow popping
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 32,
              horizontal: 24,
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            content: SuccessIndicator(message: message),
          ),
        );
      },
    ).then((_) {
      // This runs *after* the dialog is popped
      if (!completer.isCompleted) {
        completer.complete();
      }
    }),
  );

  // Wait for the dialog to be closed before calling the callback
  await completer.future;
  onDismissed();
}
