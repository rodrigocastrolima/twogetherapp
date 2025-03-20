import 'package:flutter/material.dart';
import 'rejection_details_page.dart';

class RejectionExamplesPage extends StatelessWidget {
  const RejectionExamplesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejection Examples')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RejectionDetailsPage(
                      submissionId: 'SUB12345',
                      rejectionReason: 'Missing required documentation. Please upload your ID and proof of address.',
                      rejectionDate: DateTime.now(),
                      isPermanentRejection: false,
                    ),
                  ),
                );
              },
              child: const Text('View Regular Rejection'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RejectionDetailsPage(
                      submissionId: 'SUB67890',
                      rejectionReason: 'Invalid business registration number. This submission has been permanently rejected.',
                      rejectionDate: DateTime.now(),
                      isPermanentRejection: true,
                    ),
                  ),
                );
              },
              child: const Text('View Permanent Rejection'),
            ),
          ],
        ),
      ),
    );
  }
} 