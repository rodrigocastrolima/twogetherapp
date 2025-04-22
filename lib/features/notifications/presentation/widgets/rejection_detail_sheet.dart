import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/notification.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RejectionDetailSheet extends StatelessWidget {
  final UserNotification notification;

  const RejectionDetailSheet({super.key, required this.notification});

  String _formatDate(DateTime date, BuildContext context) {
    // Use locale-aware formatting
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    // Extract data safely from metadata
    final String clientName =
        notification.metadata['clientName']?.toString() ?? 'Unknown';
    final String? rejectionReason =
        notification.metadata['rejectionReason']?.toString();
    final String submissionId = notification.metadata['submissionId'] ?? '-';

    return Container(
      // Use constraints for better web/large screen adaptability
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: isDarkMode ? colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        // SafeArea at the bottom inside the sheet
        top: false, // No top padding needed as it's inside modal
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Make column height fit content
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: colorScheme.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Opportunity Rejected',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  // Close button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Details Section
              _buildDetailRow(context, label: 'Client:', value: clientName),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                label: 'Submission ID:',
                value: submissionId,
                isId: true,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                label: 'Date:',
                value: _formatDate(notification.createdAt, context),
              ),
              const SizedBox(height: 16),
              Text(
                'Rejection Reason:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  rejectionReason ?? 'No reason provided.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for detail rows
  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isId = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100, // Consistent label width
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFamily: isId ? 'monospace' : null, // Style ID differently
            ),
          ),
        ),
      ],
    );
  }
}

// TODO: Add necessary l10n keys to .arb files:
// notificationOpportunityRejectedTitle, commonUnknown, rejectionDetailClientLabel,
// rejectionDetailSubmissionIdLabel, rejectionDetailTimestampLabel,
// rejectionDetailReasonLabel, rejectionDetailNoReasonProvided
