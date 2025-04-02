import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../features/salesforce/data/repositories/salesforce_repository.dart';
import '../../../core/theme/theme.dart';
import '../../../presentation/layout/admin_layout.dart';

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
      await _fetchRetailUsers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRetailUsers() async {
    try {
      final retailUsers = await _repository.getUsersByDepartment('Retail');
      setState(() {
        _retailUsers = retailUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching retail users: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdminLayout(
      pageTitle: l10n.adminRetailUsers,
      child: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: _initializeSalesforce,
              child: Text(l10n.tryAgain),
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
            Text(l10n.noRetailUsersFound, style: const TextStyle(fontSize: 18)),
            ElevatedButton(
              onPressed: _initializeSalesforce,
              child: Text(l10n.refresh),
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
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Text(user['Name']?.substring(0, 1) ?? '?'),
              ),
              title: Text(user['Name'] ?? l10n.unknownUser),
              subtitle: Text(user['Email'] ?? l10n.noEmailProvided),
              trailing: Chip(
                label: Text(user['IsActive'] == true ? l10n.active : l10n.inactive),
                backgroundColor: user['IsActive'] == true ? Colors.green : Colors.grey,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}

