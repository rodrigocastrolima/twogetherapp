import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../layout/main_layout.dart';

class RejectionExamplesPage extends StatelessWidget {
  const RejectionExamplesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentIndex: -1,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                context.go('/notifications/SUB12345');
              },
              child: const Text('View Regular Rejection'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.go('/notifications/SUB67890');
              },
              child: const Text('View Permanent Rejection'),
            ),
          ],
        ),
      ),
    );
  }
}
