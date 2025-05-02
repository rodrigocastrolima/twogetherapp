import 'dart:ui'; // For ImageFilter.blur
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twogether/core/models/notification.dart'; // Adjusted import

class RejectionDetailDialog extends StatelessWidget {
  final UserNotification notification;

  const RejectionDetailDialog({super.key, required this.notification});

  String _formatDate(DateTime date, BuildContext context) {
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Extract data safely from metadata
    final String clientName =
        notification.metadata['clientName']?.toString() ??
        'Desconhecido'; // Hardcoded Portuguese fallback
    final String? rejectionReason =
        notification.metadata['rejectionReason']?.toString();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        // Use ClipRRect and Container for background and clipping
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              // Use theme surface color with alpha for slight transparency
              color: colorScheme.surface.withAlpha((255 * 0.95).round()),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Header Row with Title and Close Button ---
                Stack(
                  alignment: Alignment.center, // Center the title
                  children: [
                    // Title and Icon (centered)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4.0, // Adjust top padding slightly
                        bottom: 15.0,
                      ), // Add vertical padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons
                                .warning_amber_rounded, // CHANGED: Use Material warning icon
                            color: colorScheme.error, // Keep theme error color
                            size:
                                24, // Slightly larger standard Material icon size
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Oportunidade Rejeitada', // Hardcoded Portuguese
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Close button (top-right)
                    Positioned(
                      top: -8, // Adjust position to align visually
                      right: -8, // Adjust position
                      child: IconButton(
                        icon: Icon(
                          Icons.close, // Standard close icon
                          color: colorScheme.onSurfaceVariant, // Subtle color
                          size: 20, // Smaller size for close button
                        ),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Fechar', // Hardcoded Portuguese
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(), // Remove default padding
                      ),
                    ),
                  ],
                ),

                // --- Details ---
                _buildDetailRow(
                  context,
                  label: 'Cliente:', // Hardcoded Portuguese
                  value: clientName,
                ),
                const SizedBox(height: 8), // Add some space instead of divider
                _buildDetailRow(
                  context,
                  label: 'Data:', // Hardcoded Portuguese
                  value: _formatDate(notification.createdAt, context),
                ),
                const SizedBox(height: 8), // Add some space instead of divider
                // --- Rejection Reason ---
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
                  child: Text(
                    'Motivo da Rejeição:', // Hardcoded Portuguese
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  rejectionReason ??
                      'Nenhuma razão fornecida.', // Hardcoded Portuguese
                  style: textTheme.bodyMedium?.copyWith(
                    // Use bodyMedium from theme
                    color: colorScheme.onSurface,
                  ),
                ),

                // --- Removed Close Button ---
                // const SizedBox(height: 25),
                // CupertinoButton(...)
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for detail rows using theme styles
  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              // Use bodyMedium from theme
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(
                // Use bodyMedium from theme
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500, // Keep slight emphasis on value
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple divider widget using theme color - NO LONGER USED
  // Widget _buildDivider(BuildContext context) {
  //   return Divider(
  //     height: 1,
  //     thickness: 0.5,
  //     color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
  //   );
  // }
}

// TODO: Add necessary l10n keys for dialog titles/labels/buttons
