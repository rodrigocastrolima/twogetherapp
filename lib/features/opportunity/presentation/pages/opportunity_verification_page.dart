import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../../../../../core/models/service_submission.dart'; // Adjust path if needed
import './opportunity_detail_page.dart'; // Import the new detail page

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

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Opportunities')),
      body: pendingOpportunitiesAsync.when(
        data: (submissions) {
          if (submissions.isEmpty) {
            return const Center(child: Text('No pending opportunities found.'));
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
                          (context) =>
                              OpportunityDetailFormView(submission: submission),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) =>
                Center(child: Text('Error loading submissions: $error')),
      ),
    );
  }
}
