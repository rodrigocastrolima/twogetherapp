import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../features/salesforce/data/services/salesforce_connection_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// This script explores Salesforce User metadata to discover all available fields
/// It helps determine which fields should be synchronized with Firebase
///
/// Usage:
/// flutter run -d chrome -t lib/scripts/explore_salesforce_user_metadata.dart

void main() async {
  // Initialize Flutter binding and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app
  runApp(const SalesforceExplorerApp());
}

class SalesforceExplorerApp extends StatelessWidget {
  const SalesforceExplorerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SalesforceUserExplorerScreen(),
    );
  }
}

class SalesforceUserExplorerScreen extends ConsumerStatefulWidget {
  const SalesforceUserExplorerScreen({super.key});

  @override
  ConsumerState<SalesforceUserExplorerScreen> createState() =>
      _SalesforceUserExplorerScreenState();
}

class _SalesforceUserExplorerScreenState
    extends ConsumerState<SalesforceUserExplorerScreen> {
  late final SalesforceConnectionService _connectionService;
  List<Map<String, dynamic>> _fields = [];
  bool _isLoading = false;
  String? _error;
  String _filter = '';
  static const List<String> _recommendedFieldsData = [
    'Id',
    'Username',
    'Name',
    'Email',
    'IsActive',
    'Department',
    'Phone',
    'MobilePhone',
    'CompanyName',
    'Title',
    'UserType',
    'ProfileId',
    'UserRoleId',
    'ManagerId',
  ];

  @override
  void initState() {
    super.initState();
    _connectionService = ref.read(salesforceConnectionServiceProvider);
    _fetchFieldMetadata();
  }

  Future<void> _fetchFieldMetadata() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!_connectionService.isConnected) {
        setState(() {
          _error = 'Salesforce not connected. Please ensure you are logged in via the app.';
          _isLoading = false;
        });
        return;
      }

      final describeResult = await _connectionService.get('/services/data/v58.0/sobjects/User/describe');

      if (describeResult != null && describeResult.containsKey('fields')) {
        final rawFields = describeResult['fields'] as List<dynamic>;
        setState(() {
          _fields =
              rawFields.map((f) => f as Map<String, dynamic>).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch User metadata';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching User metadata: $e';
        _isLoading = false;
      });
    }
  }

  // Filter fields based on search query
  List<Map<String, dynamic>> _getFilteredFields() {
    if (_filter.isEmpty) {
      return _fields;
    }
    return _fields.where((field) {
      final name = field['name'] as String? ?? '';
      final label = field['label'] as String? ?? '';
      final searchLower = _filter.toLowerCase();
      return name.toLowerCase().contains(searchLower) ||
          label.toLowerCase().contains(searchLower);
    }).toList();
  }

  // Export fields to JSON file
  Future<void> _exportToJson() async {
    if (_fields.isEmpty) return;

    try {
      // Create a map with only essential field information
      final exportData = {
        'objectName': 'User',
        'fields':
            _fields
                .map(
                  (field) => {
                    'name': field['name'],
                    'label': field['label'],
                    'type': field['type'],
                    'length': field['length'],
                    'nillable': field['nillable'],
                    'updateable': field['updateable'],
                    'recommended': _recommendedFieldsData.contains(field['name']),
                    'description': field['description'] ?? '',
                  },
                )
                .toList(),
        'recommendedFields': _recommendedFieldsData,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

      // In a web context, offer the file for download
      // This would need to be adjusted for desktop apps
      final blob = jsonStr;

      // Show a dialog with the JSON content that can be copied
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Export Result'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(child: SelectableText(blob)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting data: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFields = _getFilteredFields();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salesforce User Metadata Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchFieldMetadata,
            tooltip: 'Refresh metadata',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _fields.isEmpty || _isLoading ? null : _exportToJson,
            tooltip: 'Export field data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            color:
                _connectionService.isConnected ? Colors.green.shade100 : Colors.orange.shade100,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  _connectionService.isConnected ? Icons.check_circle : Icons.warning,
                  color: _connectionService.isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ??
                        (_connectionService.isConnected
                            ? 'Connected to Salesforce: ${_connectionService.instanceUrl}'
                            : 'Failed to connect to Salesforce'),
                    style: TextStyle(
                      color:
                          _connectionService.isConnected
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search fields',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
          ),

          // Field count summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Displaying ${filteredFields.length} of ${_fields.length} fields',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text('Show Recommended'),
                  onPressed: () {
                    setState(() {
                      _filter = '';
                      // Filter to show only recommended fields
                      _fields =
                          _fields
                              .where(
                                (field) =>
                                    _recommendedFieldsData.contains(field['name']),
                              )
                              .toList();
                    });
                  },
                ),
              ],
            ),
          ),

          // Fields list
          Expanded(
            child:
                _isLoading && _fields.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filteredFields.isEmpty
                    ? const Center(
                      child: Text('No fields found matching the search'),
                    )
                    : ListView.builder(
                      itemCount: filteredFields.length,
                      itemBuilder: (context, index) {
                        final field = filteredFields[index];
                        final isRecommended = _recommendedFieldsData.contains(
                          field['name'],
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    field['name'] as String? ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isRecommended)
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Label: ${field['label'] ?? 'N/A'}'),
                                Text(
                                  'Type: ${field['type'] ?? 'N/A'}, Length: ${field['length'] ?? 'N/A'}',
                                ),
                                Text(
                                  'Nillable: ${field['nillable'] ?? false}, Updateable: ${field['updateable'] ?? false}',
                                ),
                                if (field['description'] != null &&
                                    field['description'] != '')
                                  Text(
                                    'Description: ${field['description']}',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: Text(
                                        field['name'] as String? ??
                                            'Unknown Field',
                                      ),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildFieldDetailItem(
                                                'API Name',
                                                field['name'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Label',
                                                field['label'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Type',
                                                field['type'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Length',
                                                field['length'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Precision',
                                                field['precision'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Scale',
                                                field['scale'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Nillable',
                                                field['nillable'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Updateable',
                                                field['updateable'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Createable',
                                                field['createable'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Custom',
                                                field['custom'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Calculated',
                                                field['calculated'],
                                              ),
                                              _buildFieldDetailItem(
                                                'Description',
                                                field['description'],
                                              ),
                                              if (field['picklistValues'] !=
                                                      null &&
                                                  (field['picklistValues']
                                                          as List)
                                                      .isNotEmpty)
                                                ..._buildPicklistValues(
                                                  field['picklistValues']
                                                      as List,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(context).pop(),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _fetchFieldMetadata,
        tooltip: 'Reconnect to Salesforce',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildFieldDetailItem(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }

  List<Widget> _buildPicklistValues(List picklistValues) {
    return [
      const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text(
          'Picklist Values:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      ...picklistValues.map(
        (value) => Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0),
          child: Text(
            '${value['value']} ${value['active'] == false ? '(inactive)' : ''}',
          ),
        ),
      ),
    ];
  }
}
