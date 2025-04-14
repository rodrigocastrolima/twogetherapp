import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../../../../../core/models/service_submission.dart'; // Adjust path if needed
import './opportunity_detail_page.dart'; // Import the new detail page
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import AppLocalizations
import '../../../../core/theme/theme.dart'; // Import theme for styling

// Provider to stream pending opportunity submissions
final pendingOpportunitiesProvider = StreamProvider<List<ServiceSubmission>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('serviceSubmissions')
      .where('status', isEqualTo: 'pending_review')
      .orderBy('submissionTimestamp', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => ServiceSubmission.fromFirestore(doc))
                .toList(),
      );
});

class OpportunityVerificationPage extends ConsumerWidget {
  const OpportunityVerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);
    final l10n = AppLocalizations.of(context)!; // Get localizations
    final theme = Theme.of(context); // Get theme
    final textColor = theme.colorScheme.onSurface; // Get text color

    return Scaffold(
      body: Padding(
        // Add padding around the main content
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // Wrap content in a Column to add the title
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Add Title Here ---
            Text(
              'Opportunity Verification', // Fallback text
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24), // Spacing below title
            // --- Existing Content ---
            Expanded(
              // Ensure the list takes remaining space
              child: pendingOpportunitiesAsync.when(
                data: (submissions) {
                  if (submissions.isEmpty) {
                    return Center(
                      child: Column(
                        // Center content vertically and horizontally
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_off_outlined,
                            size: 60,
                            color: AppTheme.mutedForeground,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending opportunities found.', // Fallback text
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: submissions.length,
                    itemBuilder: (context, index) {
                      final submission = submissions[index];
                      return ListTile(
                        title: Text(
                          submission.companyName ?? submission.responsibleName,
                        ),
                        subtitle: Text(
                          'NIF: ${submission.nif} \nReseller: ${submission.resellerName} \nSubmitted: ${DateFormat.yMd().add_jms().format(submission.submissionDate.toLocal())} \nStatus: ${submission.status}',
                        ), // Using submissionDate getter
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Navigate to Detail View, passing the submission
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => OpportunityDetailFormView(
                                    submission: submission,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stack) => Center(
                      child: Padding(
                        // Add padding to error message
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading submissions: $error', // Fallback text
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.destructive),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
