import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/salesforce/data/repositories/salesforce_repository.dart';
import '../../../features/opportunity/presentation/pages/salesforce_opportunity.dart';

class OpportunityVerificationPage extends ConsumerStatefulWidget {
  const OpportunityVerificationPage({super.key});

  @override
  ConsumerState<OpportunityVerificationPage> createState() =>
      _OpportunityVerificationPageState();
}

class _OpportunityVerificationPageState
    extends ConsumerState<OpportunityVerificationPage> {
  late final SalesforceRepository _repository;
  bool _isLoading = true;
  bool _isConnected = false;
  String _errorMessage = '';
  List<SalesforceOpportunity> _opportunities = [];

  @override
  void initState() {
    super.initState();
    _repository = ref.read(salesforceRepositoryProvider);
    _initializeSalesforce();
  }

  Future<void> _initializeSalesforce() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final isConnected = await _repository.initialize();

      setState(() {
        _isConnected = isConnected;
        _isLoading = false;
      });

      if (isConnected) {
        await _fetchOpportunities();
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _errorMessage = 'Error connecting to Salesforce: ${e.toString()}';
      });

      if (kDebugMode) {
        print('OpportunityVerificationPage: Error initializing Salesforce: $e');
      }
    }
  }

  Future<void> _fetchOpportunities() async {
    try {
      if (kDebugMode) {
        print('OpportunityVerificationPage: Fetching opportunities...');
      }

      final opportunities = await _repository.getOpportunities();

      setState(() {
        _opportunities = opportunities;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
          'OpportunityVerificationPage: Fetched ${opportunities.length} opportunities',
        );
        if (opportunities.isNotEmpty) {
          print(
            'OpportunityVerificationPage: First opportunity sample: ${opportunities.first}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('OpportunityVerificationPage: Error fetching opportunities: $e');
      }

      setState(() {
        _errorMessage = 'Error fetching opportunities: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salesforce Opportunities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOpportunities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeSalesforce,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (!_isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Not connected to Salesforce',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeSalesforce,
              child: const Text('Connect'),
            ),
          ],
        ),
      );
    }

    if (_opportunities.isEmpty) {
      return const Center(
        child: Text('No opportunities found', textAlign: TextAlign.center),
      );
    }

    // Display opportunities
    return ListView.builder(
      itemCount: _opportunities.length,
      itemBuilder: (context, index) {
        final opportunity = _opportunities[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(opportunity.Name),
            subtitle: Text(
              opportunity.AccountId != null
                  ? 'Account: ${opportunity.Account?.Name ?? 'Unknown'}'
                  : 'No Account',
            ),
            trailing: Text(opportunity.Fase__c ?? 'Unknown'),
          ),
        );
      },
    );
  }
}
