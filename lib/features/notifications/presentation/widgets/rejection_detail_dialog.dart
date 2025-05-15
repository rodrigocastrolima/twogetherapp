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
        'Desconhecido';
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            padding: const EdgeInsets.all(28.0),
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: colorScheme.surface.withAlpha((255 * 0.97).round()),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row with Icon, Title, and Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Oportunidade Rejeitada',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Fechar',
                      splashRadius: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Two-column layout for Client and Date
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailColumn(
                        context,
                        label: 'Cliente:',
                        value: clientName,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailColumn(
                        context,
                        label: 'Data:',
                        value: _formatDate(notification.createdAt, context),
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Rejection Reason
                Text(
                  'Motivo da Rejeição:',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rejectionReason ?? 'Nenhuma razão fornecida.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for detail columns (for two-column layout)
  Widget _buildDetailColumn(
    BuildContext context, {
    required String label,
    required String value,
    bool alignRight = false,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
