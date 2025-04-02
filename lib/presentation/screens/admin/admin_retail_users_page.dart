import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../features/salesforce/data/repositories/salesforce_repository.dart';

class AdminRetailUsersPage extends StatefulWidget {
  const AdminRetailUsersPage({Key? key}) : super(key: key);

  @override
  State<AdminRetailUsersPage> createState() => _AdminRetailUsersPageState();
}

class _AdminRetailUsersPageState extends State<AdminRetailUsersPage> {
  final SalesforceRepository _repository = SalesforceRepository();
  bool _isLoading = true;
  bool _isConnected = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _retailUsers = [];
  bool _isTestingFirebaseFunction = false;

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
      if (kDebugMode) {
        print('AdminRetailUsersPage: Starting Salesforce initialization...');
      }

      // Initialize the Salesforce connection (handles token)
      _isConnected = await _repository.initialize();

      if (kDebugMode) {
        print(
          'AdminRetailUsersPage: Salesforce initialization result: $_isConnected',
        );
      }

      if (!_isConnected) {
        setState(() {
          _errorMessage =
              'Failed to connect to Salesforce. Please check your credentials.';
          _isLoading = false;
        });
        return;
      }

      // Fetch retail users
      await _fetchRetailUsers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('AdminRetailUsersPage: Salesforce initialization error: $e');
      }
    }
  }

  Future<void> _fetchRetailUsers() async {
    try {
      if (kDebugMode) {
        print('AdminRetailUsersPage: Fetching retail users...');
      }

      final retailUsers = await _repository.getUsersByDepartment('Retail');

      if (kDebugMode) {
        print(
          'AdminRetailUsersPage: Fetched ${retailUsers.length} retail users',
        );
      }

      setState(() {
        _retailUsers = retailUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching retail users: ${e.toString()}';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('AdminRetailUsersPage: Error fetching retail users: $e');
      }
    }
  }

  // Direct Firebase Function Test
  Future<void> _testDirectFirebaseFunction() async {
    setState(() {
      _isTestingFirebaseFunction = true;
      _errorMessage = 'Testing Firebase function directly...';
    });

    try {
      if (kDebugMode) {
        print('AdminRetailUsersPage: Testing Firebase function directly...');
      }

      // Try US-Central1 region explicitly
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('getSalesforceAccessToken');

      if (kDebugMode) {
        print(
          'AdminRetailUsersPage: Firebase callable created, calling function...',
        );
      }

      final result = await callable.call();

      if (kDebugMode) {
        print('AdminRetailUsersPage: Firebase function result: $result');
        print('AdminRetailUsersPage: Result data: ${result.data}');
      }

      if (result.data != null) {
        final data = result.data;

        if (data['access_token'] != null && data['instance_url'] != null) {
          setState(() {
            _errorMessage =
                'Firebase function SUCCESS!\nGot token: ${data['access_token'].toString().substring(0, 10)}...\nInstance: ${data['instance_url']}';
            _isTestingFirebaseFunction = false;
          });

          // Now that we have a token, try to reinitialize
          await Future.delayed(const Duration(seconds: 2));
          _initializeSalesforce();
        } else {
          setState(() {
            _errorMessage =
                'Firebase function returned invalid data structure:\n${result.data}';
            _isTestingFirebaseFunction = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Firebase function returned null data';
          _isTestingFirebaseFunction = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Firebase function error: ${e.toString()}';
        _isTestingFirebaseFunction = false;
      });
      if (kDebugMode) {
        print(
          'AdminRetailUsersPage: Error calling Firebase function directly: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retail Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeSalesforce,
            tooltip: 'Refresh connection and data',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeSalesforce,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            // New debug button
            ElevatedButton(
              onPressed:
                  _isTestingFirebaseFunction
                      ? null
                      : _testDirectFirebaseFunction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                disabledBackgroundColor: Colors.grey,
              ),
              child:
                  _isTestingFirebaseFunction
                      ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Testing...'),
                        ],
                      )
                      : const Text('Test Firebase Function Directly'),
            ),
          ],
        ),
      );
    }

    if (_retailUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No retail users found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeSalesforce,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRetailUsers,
      child: ListView.builder(
        itemCount: _retailUsers.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final user = _retailUsers[index];

          // Handle possible nested objects in the Salesforce response
          final String roleName =
              user['UserRole'] != null
                  ? user['UserRole']['Name'] ?? 'No Role'
                  : 'No Role';

          final String profileName =
              user['Profile'] != null
                  ? user['Profile']['Name'] ?? 'No Profile'
                  : 'No Profile';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          (user['Name'] as String?)?.isNotEmpty == true
                              ? (user['Name'] as String)
                                  .substring(0, 1)
                                  .toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['Name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user['Email'] ?? 'No email provided',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user['IsActive'] == true)
                        const Chip(
                          label: Text('Active'),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(color: Colors.white),
                        )
                      else
                        const Chip(
                          label: Text('Inactive'),
                          backgroundColor: Colors.grey,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    'Username',
                    user['Username'] ?? 'Not available',
                  ),
                  _buildInfoRow(
                    'Department',
                    user['Department'] ?? 'Not available',
                  ),
                  _buildInfoRow('Role', roleName),
                  _buildInfoRow('Profile', profileName),
                  _buildInfoRow('ID', user['Id'] ?? 'Not available'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
