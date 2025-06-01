
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';
import '../features/salesforce/data/services/salesforce_connection_service.dart';
import '../features/salesforce/data/services/salesforce_user_sync_service.dart';

/// Script to synchronize Salesforce user data to Firebase
///
/// Usage:
/// flutter run -d chrome -t lib/scripts/sync_salesforce_user_data.dart

void main() async {
  // Initialize Flutter binding and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app
  runApp(
    ProviderScope(
      // Wrap with ProviderScope to use Riverpod providers
      child: MaterialApp(
        home: SalesforceUserSyncScreen(), // Removed const
      debugShowCheckedModeBanner: false,
      ),
    ),
    );
}

class SalesforceUserSyncScreen extends ConsumerStatefulWidget {
  SalesforceUserSyncScreen({super.key}); // Removed const

  @override
  ConsumerState<SalesforceUserSyncScreen> createState() =>
      _SalesforceUserSyncScreenState();
}

class _SalesforceUserSyncScreenState extends ConsumerState<SalesforceUserSyncScreen> {
  late SalesforceConnectionService _connectionService;
  late SalesforceUserSyncService _syncService;
  final TextEditingController _salesforceIdController = TextEditingController();
  String _syncStatus = 'Not connected';
  bool _isLoading = false;
  final List<String> _logs = [];
  bool _isSuperAdmin = false;

  List<Map<String, dynamic>> _sfUsers = [];
  List<Map<String, dynamic>> _fbUsers = [];
  int _syncedCount = 0;
  int _errorCount = 0;

  Map<String, String> get _fieldMapping =>
      SalesforceUserSyncService.getDefaultFieldMapping();

  @override
  void initState() {
    super.initState();
    _connectionService = ref.read(salesforceConnectionServiceProvider);
    _syncService = ref.read(salesforceUserSyncServiceProvider);
    _checkSuperAdmin();
    _updateConnectionStatus();
  }

  @override
  void dispose() {
    _salesforceIdController.dispose();
    super.dispose();
  }

  void _updateConnectionStatus() {
    setState(() {
      if (_connectionService.isConnected) {
        _syncStatus = 'Connected to Salesforce: ${_connectionService.instanceUrl}';
        _addLog('Successfully connected to Salesforce.');
        _fetchSalesforceUsers();
        _fetchFirebaseUsers();
      } else {
        _syncStatus = 'Salesforce not connected. Please sign in via the main app.';
        _addLog(_syncStatus);
      }
    });
  }

  Future<void> _checkSuperAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['isSuperAdmin'] == true) {
      setState(() {
          _isSuperAdmin = true;
        });
      }
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
    setState(() {
      _logs.insert(0, '${DateTime.now().toIso8601String()}: $message');
    });
  }

  Future<void> _fetchSalesforceUsers() async {
    if (!_connectionService.isConnected) {
      _log('Cannot fetch Salesforce users: Not connected.');
      return;
    }
    _log('Fetching Salesforce users...');
    setState(() => _isLoading = true);
    try {
      final query =
          'SELECT ${SalesforceUserSyncService.getDefaultFieldMapping().keys.join(',')} FROM User WHERE IsActive = true';
      final encodedQuery = Uri.encodeComponent(query);
      final data = await _connectionService.get(
        '/services/data/v58.0/query/?q=$encodedQuery',
      );

      if (data != null && data['records'] != null) {
        _sfUsers = List<Map<String, dynamic>>.from(data['records']);
        _log('Found ${_sfUsers.length} Salesforce users');
      } else {
        _log('Failed to fetch Salesforce users or no users found.');
        _sfUsers = [];
      }
    } catch (e) {
      _log('Error fetching Salesforce users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFirebaseUsers() async {
    _log('Fetching Firebase users...');
    setState(() => _isLoading = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('users').get();
      _fbUsers = querySnapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
      _log('Found ${_fbUsers.length} Firebase users');
    } catch (e) {
      _log('Error fetching Firebase users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _syncSalesforceUser(String salesforceId) async {
    if (!_isSuperAdmin) {
      _log('Error: Only Super Admins can sync users.');
      return false;
    }
    _log('Attempting to sync Salesforce user ID: $salesforceId to Firebase...');
    setState(() => _isLoading = true);
    bool success = false;
    try {
      final sfUser = await _syncService.getSalesforceUserById(salesforceId);
      if (sfUser == null || sfUser['Email'] == null) {
        _log('Could not find Salesforce user or user has no email for ID: $salesforceId');
        setState(() => _isLoading = false);
        return false;
      }

      final email = sfUser['Email'] as String;
      final querySnapshot = await FirebaseFirestore.instance
                .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _log('No Firebase user found with email: $email to sync with Salesforce ID: $salesforceId');
        setState(() => _isLoading = false);
        return false;
      }
      
      final firebaseUserId = querySnapshot.docs.first.id;
      success = await _syncService.syncSalesforceUserToFirebase(firebaseUserId, salesforceId);
      
      if (success) {
        _log('Successfully synced Salesforce user ID: $salesforceId to Firebase user: $firebaseUserId');
      } else {
        _log('Failed to sync Salesforce user ID: $salesforceId');
      }
    } catch (e) {
      _log('Error syncing Salesforce user $salesforceId: $e');
      success = false;
    } finally {
      setState(() => _isLoading = false);
    }
    return success;
  }

  Future<void> _syncAllUsers() async {
    if (!_isSuperAdmin) {
      _log('Error: Only Super Admins can perform full sync.');
      return;
    }
    if (!_connectionService.isConnected) {
      _log('Cannot sync all users: Salesforce not connected.');
      return;
    }

    _log('Starting sync of all Salesforce users to Firebase...');
    setState(() {
      _isLoading = true;
      _syncedCount = 0;
      _errorCount = 0;
    });

    await _fetchSalesforceUsers(); 
    if (_sfUsers.isEmpty) {
      _log('No Salesforce users to sync.');
      setState(() => _isLoading = false);
      return;
    }

    for (final salesforceUser in _sfUsers) {
      final salesforceId = salesforceUser['Id'] as String?;
        if (salesforceId != null) {
          final success = await _syncSalesforceUser(salesforceId);
          if (success) {
          setState(() => _syncedCount++);
          } else {
          setState(() => _errorCount++);
          }
        }
      }
    _log('Sync all users completed. Success: $_syncedCount, Errors: $_errorCount');
    await _fetchFirebaseUsers(); 
    setState(() => _isLoading = false);
  }

  void _syncSingleUserFromInput() async {
    final salesforceId = _salesforceIdController.text.trim();
    if (salesforceId.isEmpty) {
      _log('Please enter a Salesforce ID to sync.');
      return;
    }
    if (!_isSuperAdmin) {
      _log('Error: Only Super Admins can sync users.');
      return;
    }
      final success = await _syncSalesforceUser(salesforceId);
      if (success) {
        await _fetchFirebaseUsers();
      }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salesforce User Sync Util'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _updateConnectionStatus,
            tooltip: 'Refresh Connection & Data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            color: Colors.green.shade100,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _syncStatus,
                    style: const TextStyle(color: Colors.green),
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
                          _isLoading ? null : _syncSingleUserFromInput,
                      child: const Text('Sync User'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Sync all users
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync All Users'),
                  onPressed:
                      _isLoading ? null : _syncAllUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
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
