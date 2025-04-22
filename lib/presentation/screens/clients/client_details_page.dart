// This file is kept as a redirect to prevent build errors.
// The actual implementation has been moved to opportunity_details_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// This class is not used anymore
@Deprecated('Use OpportunityDetailsPage instead')
class ClientDetailsPage extends StatelessWidget {
  final Map<String, dynamic> clientData;

  const ClientDetailsPage({super.key, required this.clientData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moved'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Text('This page has been replaced by OpportunityDetailsPage'),
      ),
    );
  }
}
