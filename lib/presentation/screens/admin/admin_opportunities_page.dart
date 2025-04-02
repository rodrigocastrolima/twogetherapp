import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../../features/salesforce/data/repositories/salesforce_repository.dart';

class AdminOpportunitiesPage extends StatefulWidget {
  const AdminOpportunitiesPage({Key? key}) : super(key: key);

  @override
  State<AdminOpportunitiesPage> createState() => _AdminOpportunitiesPageState();
}

class _AdminOpportunitiesPageState extends State<AdminOpportunitiesPage> {
  final SalesforceRepository _repository = SalesforceRepository();
  bool _isLoading = true;
  bool _isConnected = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _opportunities = [];
  Map<String, dynamic>? _selectedOpportunity;
  List<String> _availableFields = [];
  final String _objectName = 'Oportunidade__c';

  // Default record type filter
  String _selectedRecordType = 'Retail';

  // Available record types (can be expanded based on actual data)
  final List<String> _recordTypes = ['All', 'Retail'];

  @override
  void initState() {
    super.initState();
    _initializeSalesforce();
  }

  Future<void> _initializeSalesforce() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      _isConnected = await _repository.initialize();
      if (!_isConnected) {
        setState(() {
          _errorMessage = 'Failed to connect to Salesforce.';
          _isLoading = false;
        });
        return;
      }

      // First try to get the metadata to understand the object schema
      await _fetchObjectMetadata();

      // Then fetch the actual opportunities
      await _fetchOpportunities();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchObjectMetadata() async {
    try {
      if (kDebugMode) {
        print(
          'AdminOpportunitiesPage: Fetching object metadata for $_objectName...',
        );
      }

      final fields = await _repository.getObjectFields(_objectName);

      setState(() {
        _availableFields = fields;
      });

      if (kDebugMode) {
        print(
          'AdminOpportunitiesPage: Found ${fields.length} fields on $_objectName',
        );
        if (fields.isNotEmpty) {
          print('AdminOpportunitiesPage: Field names: ${fields.join(', ')}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AdminOpportunitiesPage: Error fetching object metadata: $e');
      }
      // Don't fail the whole page load if metadata can't be fetched
    }
  }

  Future<void> _fetchOpportunities() async {
    try {
      if (kDebugMode) {
        print('AdminOpportunitiesPage: Fetching opportunities...');
        print(
          'AdminOpportunitiesPage: Using record type filter: $_selectedRecordType',
        );
      }

      // Pass the record type filter if not "All"
      final opportunities = await _repository.getOpportunities(
        recordType: _selectedRecordType == 'All' ? null : _selectedRecordType,
      );

      setState(() {
        _opportunities = opportunities;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
          'AdminOpportunitiesPage: Fetched ${opportunities.length} opportunities',
        );
        if (opportunities.isNotEmpty) {
          print(
            'AdminOpportunitiesPage: First opportunity sample: ${opportunities.first}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AdminOpportunitiesPage: Error fetching opportunities: $e');
      }

      setState(() {
        _errorMessage = 'Error fetching opportunities: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Salesforce Opportunities'),
        actions: [
          // Add filter dropdown
          DropdownButton<String>(
            value: _selectedRecordType,
            icon: const Icon(Icons.filter_list, color: Colors.white),
            underline: Container(), // No underline
            dropdownColor: Theme.of(context).primaryColor,
            style: const TextStyle(color: Colors.white),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedRecordType) {
                setState(() {
                  _selectedRecordType = newValue;
                });
                _fetchOpportunities();
              }
            },
            items:
                _recordTypes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
          ),
          const SizedBox(width: 8),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOpportunities,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
              child: Text(l10n.tryAgain),
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
            Text('Not connected to Salesforce', textAlign: TextAlign.center),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No opportunities found', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchOpportunities,
              child: Text(l10n.refresh),
            ),
            const SizedBox(height: 32),
            if (_availableFields.isNotEmpty) ...[
              Text(
                'Available fields: ${_availableFields.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children:
                      _availableFields
                          .map(
                            (field) =>
                                ListTile(title: Text(field), dense: true),
                          )
                          .toList(),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Display opportunities in a list or data table
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_opportunities.length} Opportunities Found',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildOpportunitiesTable()),
      ],
    );
  }

  Widget _buildOpportunitiesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Fase')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('Data Previsão')),
            DataColumn(label: Text('Receita')),
            DataColumn(label: Text('Record Type')),
          ],
          rows:
              _opportunities.map((opportunity) {
                // Extract record type from the nested object
                String recordType = 'N/A';
                if (opportunity.containsKey('RecordType') &&
                    opportunity['RecordType'] is Map<String, dynamic>) {
                  recordType =
                      opportunity['RecordType']['Name']?.toString() ?? 'N/A';
                }

                return DataRow(
                  cells: [
                    DataCell(Text(opportunity['Name'] ?? 'N/A')),
                    DataCell(Text(opportunity['Fase__c']?.toString() ?? 'N/A')),
                    DataCell(
                      Text(
                        opportunity['Tipo_de_Oportunidade__c']?.toString() ??
                            'N/A',
                      ),
                    ),
                    DataCell(
                      Text(
                        opportunity['Data_de_Previs_o_de_Fecho__c']
                                ?.toString() ??
                            'N/A',
                      ),
                    ),
                    DataCell(
                      Text(
                        opportunity['Receita_Total__c']?.toString() ?? 'N/A',
                      ),
                    ),
                    DataCell(Text(recordType)),
                  ],
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedOpportunity = opportunity;
                    });
                    _showOpportunityDetails(opportunity);
                  },
                );
              }).toList(),
        ),
      ),
    );
  }

  void _showOpportunityDetails(Map<String, dynamic> opportunity) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(opportunity['Name'] ?? 'Opportunity Details'),
            content: SingleChildScrollView(
              child: ListBody(
                children:
                    opportunity.entries
                        .where((entry) => entry.key != 'attributes')
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${entry.key}:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: _formatFieldValue(entry.value),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  /// Helper method to format different field value types for display
  Widget _formatFieldValue(dynamic value) {
    if (value == null) {
      return const Text('N/A');
    } else if (value is bool) {
      return value
          ? const Text('Yes', style: TextStyle(color: Colors.green))
          : const Text('No', style: TextStyle(color: Colors.red));
    } else if (value is Map) {
      // Handle nested objects/maps
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            value.entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
      );
    } else {
      return Text(value.toString());
    }
  }
}
