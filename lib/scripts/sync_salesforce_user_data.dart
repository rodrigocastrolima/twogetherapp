import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../features/salesforce/data/services/salesforce_connection_service.dart';

/// Script to synchronize Salesforce user data to Firebase
///
/// Usage:
/// flutter run -d chrome -t lib/scripts/sync_salesforce_user_data.dart

// Configuration for field mapping between Salesforce and Firebase
const Map<String, String> DEFAULT_FIELD_MAPPING = {
  'Id': 'salesforceId',
  'Name': 'displayName',
  'Email': 'email',
  'IsActive': 'isActive',
  'Phone': 'phoneNumber',
  'MobilePhone': 'mobilePhone',
  'Department': 'department',
  'Title': 'title',
  'CompanyName': 'companyName',
  'ManagerId': 'managerId',
  'UserRoleId': 'userRoleId',
  'ProfileId': 'profileId',
};

void main() async {
  // Initialize Flutter binding and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app
  runApp(const SalesforceUserSyncApp());
}

class SalesforceUserSyncApp extends StatelessWidget {
  const SalesforceUserSyncApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SalesforceUserSyncScreen(),
    );
  }
}

class SalesforceUserSyncScreen extends StatefulWidget {
  const SalesforceUserSyncScreen({Key? key}) : super(key: key);

  @override
  State<SalesforceUserSyncScreen> createState() =>
      _SalesforceUserSyncScreenState();
}

class _SalesforceUserSyncScreenState extends State<SalesforceUserSyncScreen> {
  final SalesforceConnectionService _salesforceService =
      SalesforceConnectionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isConnected = false;
  String _statusMessage = 'Not connected to Salesforce';
  List<Map<String, dynamic>> _salesforceUsers = [];
  List<Map<String, dynamic>> _firebaseUsers = [];
  Map<String, String> _fieldMapping = DEFAULT_FIELD_MAPPING;
  TextEditingController _salesforceIdController = TextEditingController();

  // Status tracking
  int _syncedCount = 0;
  int _errorCount = 0;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _connectToSalesforce();
  }

  @override
  void dispose() {
    _salesforceIdController.dispose();
    super.dispose();
  }

  // Connect to Salesforce
  Future<void> _connectToSalesforce() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to Salesforce...';
      _addLog('Connecting to Salesforce...');
    });

    try {
      final success = await _salesforceService.initialize();

      setState(() {
        _isConnected = success;
        _isLoading = false;
        _statusMessage =
            success
                ? 'Connected to Salesforce: ${_salesforceService.instanceUrl}'
                : 'Failed to connect to Salesforce';
        _addLog(_statusMessage);
      });

      if (success) {
        await _fetchSalesforceUsers();
        await _fetchFirebaseUsers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
        _statusMessage = 'Error connecting to Salesforce: $e';
        _addLog('Error: $_statusMessage');
      });
    }
  }

  // Fetch users from Salesforce
  Future<void> _fetchSalesforceUsers() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching Salesforce users...';
      _addLog(_statusMessage);
    });

    try {
      // Build the fields to query based on the field mapping
      final fieldList = _fieldMapping.keys.join(', ');

      // Query to get users with selected fields
      final query = 'SELECT $fieldList FROM User WHERE IsActive = true';
      final encodedQuery = Uri.encodeComponent(query);

      final data = await _salesforceService.get(
        '/services/data/v58.0/query/?q=$encodedQuery',
      );

      if (data == null || !data.containsKey('records')) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to fetch Salesforce users';
          _addLog('Error: $_statusMessage');
        });
        return;
      }

      final records = data['records'] as List<dynamic>;
      _salesforceUsers =
          records.map((record) => record as Map<String, dynamic>).toList();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Found ${_salesforceUsers.length} Salesforce users';
        _addLog(_statusMessage);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error fetching Salesforce users: $e';
        _addLog('Error: $_statusMessage');
      });
    }
  }

  // Fetch users from Firebase
  Future<void> _fetchFirebaseUsers() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching Firebase users...';
      _addLog(_statusMessage);
    });

    try {
      final querySnapshot = await _firestore.collection('users').get();

      _firebaseUsers =
          querySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Found ${_firebaseUsers.length} Firebase users';
        _addLog(_statusMessage);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error fetching Firebase users: $e';
        _addLog('Error: $_statusMessage');
      });
    }
  }

  // Sync a specific Salesforce user to Firebase
  Future<bool> _syncSalesforceUser(String salesforceId) async {
    try {
      _addLog('Syncing user with Salesforce ID: $salesforceId');

      // Find user in Salesforce
      final salesforceUser = _salesforceUsers.firstWhere(
        (user) => user['Id'] == salesforceId,
        orElse: () => <String, dynamic>{},
      );

      if (salesforceUser.isEmpty) {
        _addLog('Error: Salesforce user not found with ID: $salesforceId');
        return false;
      }

      // Find matching Firebase user
      final firebaseUser = _firebaseUsers.firstWhere(
        (user) => user['salesforceId'] == salesforceId,
        orElse: () => <String, dynamic>{},
      );

      // Map Salesforce data to Firebase format
      final firebaseData = _mapSalesforceToFirebase(salesforceUser);

      // Add timestamp for the sync
      firebaseData['salesforceSyncedAt'] = FieldValue.serverTimestamp();

      if (firebaseUser.isNotEmpty) {
        // Update existing user
        final userId = firebaseUser['id'];
        _addLog('Updating existing Firebase user: $userId');

        await _firestore.collection('users').doc(userId).update(firebaseData);

        _addLog('Successfully updated user: $userId with Salesforce data');
        return true;
      } else {
        // Check if there's a Firebase user with matching email
        final email = salesforceUser['Email'];
        if (email != null) {
          final userByEmail = _firebaseUsers.firstWhere(
            (user) => user['email'] == email,
            orElse: () => <String, dynamic>{},
          );

          if (userByEmail.isNotEmpty) {
            // Update existing user with email match
            final userId = userByEmail['id'];
            _addLog('Found Firebase user by email: $userId');

            await _firestore
                .collection('users')
                .doc(userId)
                .update(firebaseData);

            _addLog('Successfully updated user: $userId with Salesforce data');
            return true;
          }
        }

        _addLog(
          'No matching Firebase user found for Salesforce ID: $salesforceId',
        );
        return false;
      }
    } catch (e) {
      _addLog('Error syncing user: $e');
      return false;
    }
  }

  // Sync all Salesforce users to Firebase
  Future<void> _syncAllUsers() async {
    setState(() {
      _isLoading = true;
      _syncedCount = 0;
      _errorCount = 0;
      _statusMessage = 'Starting sync of all users...';
      _addLog(_statusMessage);
    });

    try {
      for (final salesforceUser in _salesforceUsers) {
        final salesforceId = salesforceUser['Id'];
        if (salesforceId != null) {
          final success = await _syncSalesforceUser(salesforceId);
          if (success) {
            _syncedCount++;
          } else {
            _errorCount++;
          }
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage =
            'Sync completed. Success: $_syncedCount, Errors: $_errorCount';
        _addLog(_statusMessage);
      });

      // Refresh Firebase users to show updated data
      await _fetchFirebaseUsers();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error syncing users: $e';
        _addLog('Error: $_statusMessage');
      });
    }
  }

  // Sync a single user by Salesforce ID
  Future<void> _syncSingleUser() async {
    final salesforceId = _salesforceIdController.text.trim();
    if (salesforceId.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a Salesforce ID';
        _addLog('Error: $_statusMessage');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Syncing user with ID: $salesforceId';
      _addLog(_statusMessage);
    });

    try {
      final success = await _syncSalesforceUser(salesforceId);

      setState(() {
        _isLoading = false;
        _statusMessage =
            success
                ? 'Successfully synced user with ID: $salesforceId'
                : 'Failed to sync user with ID: $salesforceId';
        _addLog(_statusMessage);
      });

      // Refresh Firebase users list
      if (success) {
        await _fetchFirebaseUsers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error syncing user: $e';
        _addLog('Error: $_statusMessage');
      });
    }
  }

  // Map Salesforce data to Firebase format using field mapping
  Map<String, dynamic> _mapSalesforceToFirebase(
    Map<String, dynamic> salesforceUser,
  ) {
    final Map<String, dynamic> result = {};

    _fieldMapping.forEach((salesforceField, firebaseField) {
      if (salesforceUser.containsKey(salesforceField)) {
        result[firebaseField] = salesforceUser[salesforceField];
      }
    });

    return result;
  }

  // Add a log entry
  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salesforce User Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                _isLoading
                    ? null
                    : () async {
                      await _connectToSalesforce();
                    },
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            color:
                _isConnected ? Colors.green.shade100 : Colors.orange.shade100,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.warning,
                  color: _isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color:
                          _isConnected
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

          // Sync controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sync Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Sync specific user
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _salesforceIdController,
                        decoration: const InputDecoration(
                          labelText: 'Salesforce User ID',
                          hintText: 'Enter Salesforce ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed:
                          _isLoading || !_isConnected ? null : _syncSingleUser,
                      child: const Text('Sync User'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Sync all users
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: Text('Sync All Users (${_salesforceUsers.length})'),
                  onPressed:
                      _isLoading || !_isConnected || _salesforceUsers.isEmpty
                          ? null
                          : _syncAllUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Status summary
          if (_syncedCount > 0 || _errorCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text('Synced: $_syncedCount'),
                  const SizedBox(width: 16),
                  Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text('Errors: $_errorCount'),
                ],
              ),
            ),

          // Log output
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Activity Log',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                        onPressed: () {
                          setState(() {
                            _logs.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.builder(
                        itemCount: _logs.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final log = _logs[_logs.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    log.contains('Error') ? Colors.red : null,
                                fontWeight:
                                    log.contains('Error')
                                        ? FontWeight.bold
                                        : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
