import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../domain/models/account.dart';
import '../services/salesforce_connection_service.dart';

class SalesforceRepository {
  final SalesforceConnectionService _connectionService;

  SalesforceRepository({SalesforceConnectionService? connectionService})
    : _connectionService = connectionService ?? SalesforceConnectionService();

  /// Check if we're connected to Salesforce
  bool get isConnected => _connectionService.isConnected;

  /// Connect to Salesforce with username and password
  Future<bool> connect(
    String username,
    String password, {
    bool isSandbox = false,
  }) {
    return _connectionService.connect(username, password, isSandbox: isSandbox);
  }

  /// Disconnect from Salesforce
  Future<void> disconnect() {
    return _connectionService.disconnect();
  }

  /// Initialize the connection
  Future<bool> initialize() {
    return _connectionService.initialize();
  }

  /// Query for accounts
  Future<List<Account>> getAccounts({String? filter, int limit = 10}) async {
    if (!_connectionService.isConnected) {
      if (kDebugMode) {
        print('Not connected to Salesforce');
      }
      return [];
    }

    try {
      String query =
          'SELECT Id, Name, AccountNumber, Industry, Type, AnnualRevenue, Phone, Website, ';
      query +=
          'BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, ';
      query +=
          'Description, NumberOfEmployees, OwnerId, CreatedDate, LastModifiedDate, ';
      query += 'CreatedById, LastModifiedById ';
      query += 'FROM Account';

      if (filter != null && filter.isNotEmpty) {
        query += ' WHERE Name LIKE \'%$filter%\'';
      }

      query += ' ORDER BY Name LIMIT $limit';

      final data = await _connectionService.get(
        '/services/data/v58.0/query/?q=${Uri.encodeComponent(query)}',
      );

      if (data == null || !data.containsKey('records')) {
        if (kDebugMode) {
          print('Error querying accounts or no records found');
        }
        return [];
      }

      final List<Account> accounts = [];
      for (final record in data['records']) {
        accounts.add(Account.fromJson(record));
      }

      return accounts;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting accounts: $e');
      }
      return [];
    }
  }

  /// Get account by ID
  Future<Account?> getAccountById(String accountId) async {
    if (!_connectionService.isConnected) {
      return null;
    }

    try {
      final data = await _connectionService.get(
        '/services/data/v58.0/sobjects/Account/$accountId',
      );

      if (data == null) {
        return null;
      }

      return Account.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting account by ID: $e');
      }
      return null;
    }
  }

  /// Create a new account
  Future<Account?> createAccount(Account account) async {
    if (!_connectionService.isConnected) {
      return null;
    }

    try {
      // Prepare the data by removing the ID and metadata fields
      final requestData = account.toJson();
      requestData.remove('Id');
      requestData.remove('attributes');
      requestData.remove('CreatedDate');
      requestData.remove('LastModifiedDate');
      requestData.remove('CreatedById');
      requestData.remove('LastModifiedById');

      final responseData = await _connectionService.post(
        '/services/data/v58.0/sobjects/Account',
        requestData,
      );

      if (responseData == null) {
        if (kDebugMode) {
          print('Error creating account: No response data');
        }
        return null;
      }

      if (responseData['success'] == true && responseData['id'] != null) {
        // Fetch the newly created account to get all fields
        return getAccountById(responseData['id']);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating account: $e');
      }
      return null;
    }
  }

  /// Update an existing account
  Future<bool> updateAccount(Account account) async {
    if (!_connectionService.isConnected || account.id.isEmpty) {
      return false;
    }

    try {
      // Prepare the data by removing the ID and metadata fields
      final requestData = account.toJson();
      requestData.remove('Id');
      requestData.remove('attributes');
      requestData.remove('CreatedDate');
      requestData.remove('LastModifiedDate');
      requestData.remove('CreatedById');
      requestData.remove('LastModifiedById');

      // Use the patch method
      final responseData = await _connectionService.patch(
        '/services/data/v58.0/sobjects/Account/${account.id}',
        requestData,
      );

      // Success is typically indicated by an empty response
      return responseData != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating account: $e');
      }
      return false;
    }
  }

  /// Delete an account
  Future<bool> deleteAccount(String accountId) async {
    if (!_connectionService.isConnected) {
      return false;
    }

    try {
      // Use the delete method
      return await _connectionService.delete(
        '/services/data/v58.0/sobjects/Account/$accountId',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting account: $e');
      }
      return false;
    }
  }

  /// Fetch the list of available SObjects (standard and custom)
  Future<List<String>> listAvailableObjects() async {
    if (!_connectionService.isConnected) {
      if (kDebugMode) {
        print('Not connected to Salesforce. Cannot list objects.');
      }
      return [];
    }

    try {
      final data = await _connectionService.get(
        '/services/data/v58.0/sobjects/',
      );

      if (data == null || !data.containsKey('sobjects')) {
        if (kDebugMode) {
          print('Error fetching SObject list or no objects found.');
        }
        return [];
      }

      final List<String> objectNames = [];
      for (final sobject in data['sobjects']) {
        if (sobject is Map<String, dynamic> && sobject.containsKey('name')) {
          objectNames.add(sobject['name'] as String);
        }
      }

      objectNames.sort(); // Sort alphabetically for easier viewing
      return objectNames;
    } catch (e) {
      if (kDebugMode) {
        print('Error listing available SObjects: $e');
      }
      return [];
    }
  }

  /// Fetch users by department
  Future<List<Map<String, dynamic>>> getUsersByDepartment(
    String departmentName, {
    int limit = 100,
  }) async {
    if (!_connectionService.isConnected) {
      if (kDebugMode) {
        print('Not connected to Salesforce. Cannot fetch users.');
      }
      // Attempt to connect/refresh token if not connected
      bool connected = await _connectionService.initialize();
      if (!connected) {
        print('Failed to connect to Salesforce.');
        return [];
      }
    }

    try {
      // Note: User object fields might vary. Common fields are included.
      // Adjust based on your Salesforce User object configuration.
      String query =
          'SELECT Id, Name, Username, Email, Department, Profile.Name, UserRole.Name, IsActive ';
      query += 'FROM User ';
      query +=
          'WHERE Department = \'${departmentName.replaceAll("'", "\\'")}\' ';
      query += 'AND IsActive = true '; // Optionally filter for active users
      query += 'ORDER BY Name ';
      query += 'LIMIT $limit';

      final data = await _connectionService.get(
        '/services/data/v58.0/query/?q=${Uri.encodeComponent(query)}',
      );

      if (data == null || !data.containsKey('records')) {
        if (kDebugMode) {
          print(
            'Error querying users or no records found for department: $departmentName',
          );
        }
        return [];
      }

      // Return the list of user records as maps
      // We use Map<String, dynamic> as we don't have a strict User model defined yet
      final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(
        data['records'],
      );

      return users;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting users by department ($departmentName): $e');
      }
      return [];
    }
  }
}
