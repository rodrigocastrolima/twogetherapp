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
    if (kDebugMode) {
      print('SalesforceRepository: Initializing connection...');
    }
    return _connectionService.initialize();
  }

  /// Query for accounts
  Future<List<Account>> getAccounts({String? filter, int limit = 10}) async {
    if (!_connectionService.isConnected) {
      if (kDebugMode) {
        print(
          'SalesforceRepository: Not connected to Salesforce, cannot get accounts',
        );
      }
      return [];
    }

    try {
      if (kDebugMode) {
        print('SalesforceRepository: Building accounts query...');
      }

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

      if (kDebugMode) {
        print('SalesforceRepository: Executing accounts query...');
      }

      final data = await _connectionService.get(
        '/services/data/v58.0/query/?q=${Uri.encodeComponent(query)}',
      );

      if (data == null || !data.containsKey('records')) {
        if (kDebugMode) {
          print(
            'SalesforceRepository: Error querying accounts or no records found',
          );
          print('SalesforceRepository: Response data: $data');
        }
        return [];
      }

      final List<Account> accounts = [];
      for (final record in data['records']) {
        accounts.add(Account.fromJson(record));
      }

      if (kDebugMode) {
        print(
          'SalesforceRepository: Successfully fetched ${accounts.length} accounts',
        );
      }

      return accounts;
    } catch (e) {
      if (kDebugMode) {
        print('SalesforceRepository: Error getting accounts: $e');
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
        print(
          'SalesforceRepository: Not connected to Salesforce, cannot fetch users',
        );
      }
      // Attempt to connect/refresh token if not connected
      bool connected = await _connectionService.initialize();
      if (!connected) {
        if (kDebugMode) {
          print(
            'SalesforceRepository: Failed to connect to Salesforce after attempt',
          );
        }
        return [];
      } else {
        if (kDebugMode) {
          print(
            'SalesforceRepository: Successfully connected to Salesforce after attempt',
          );
        }
      }
    }

    try {
      if (kDebugMode) {
        print(
          'SalesforceRepository: Building users query for department: $departmentName',
        );
      }

      // Note: User object fields might vary. Common fields are included.
      // Adjust based on your Salesforce User object configuration.
      String query = 'SELECT Id, Name, Username, Email, Department, IsActive ';
      query += 'FROM User ';
      query +=
          'WHERE Department = \'${departmentName.replaceAll("'", "\\'")}\' ';
      query += 'AND IsActive = true '; // Optionally filter for active users
      query += 'ORDER BY Name ';
      query += 'LIMIT $limit';

      if (kDebugMode) {
        print('SalesforceRepository: Executing users query...');
        print('SalesforceRepository: Query: $query');
      }

      final data = await _connectionService.get(
        '/services/data/v58.0/query/?q=${Uri.encodeComponent(query)}',
      );

      if (data == null) {
        if (kDebugMode) {
          print('SalesforceRepository: Query returned null data');
        }
        return [];
      }

      if (!data.containsKey('records')) {
        if (kDebugMode) {
          print('SalesforceRepository: No records found in response');
          print('SalesforceRepository: Response data: $data');
        }
        return [];
      }

      // Return the list of user records as maps
      final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(
        data['records'],
      );

      if (kDebugMode) {
        print(
          'SalesforceRepository: Successfully fetched ${users.length} users',
        );
      }

      return users;
    } catch (e) {
      if (kDebugMode) {
        print(
          'SalesforceRepository: Error getting users by department ($departmentName): $e',
        );
      }
      return [];
    }
  }

  /// Fetch opportunities from Salesforce Oportunidade__c object
  /// Optionally filter by Record Type name
  Future<List<Map<String, dynamic>>> getOpportunities({
    String? recordType,
  }) async {
    if (kDebugMode) {
      print(
        'SalesforceRepository: Attempting to query Oportunidade__c object...',
      );
      if (recordType != null) {
        print('SalesforceRepository: Filtering by Record Type: $recordType');
      }
    }

    try {
      if (!isConnected) {
        if (kDebugMode) {
          print('SalesforceRepository: Not connected to Salesforce');
        }
        return [];
      }

      if (kDebugMode) {
        print('SalesforceRepository: Building opportunities query...');
      }

      // Use the correct field names from metadata we discovered
      String query = '''
        SELECT Id, Name, CreatedDate, LastModifiedDate,
               Data_de_Previs_o_de_Fecho__c,
               Receita_Total__c,
               Fase__c,
               Tipo_de_Oportunidade__c,
               Prospect_Cliente__c,
               RecordType.Name
        FROM Oportunidade__c 
      ''';

      // Add record type filter if provided
      if (recordType != null && recordType.isNotEmpty) {
        query += ' WHERE RecordType.Name = \'$recordType\'';
      }

      // Always order by name and limit results
      query += ' ORDER BY Name LIMIT 50';

      if (kDebugMode) {
        print('SalesforceRepository: Executing opportunities query: $query');
      }

      final result = await _connectionService.get(
        '/services/data/v58.0/query/?q=${Uri.encodeComponent(query)}',
      );

      if (result == null) {
        if (kDebugMode) {
          print('SalesforceRepository: Query returned null data');
        }
        return [];
      }

      if (result['records'] == null) {
        if (kDebugMode) {
          print('SalesforceRepository: No records found in query result');
        }
        return [];
      }

      final List<dynamic> records = result['records'];
      final List<Map<String, dynamic>> opportunities =
          records.map((record) => record as Map<String, dynamic>).toList();

      if (kDebugMode) {
        print(
          'SalesforceRepository: Found ${opportunities.length} opportunities with record type ${recordType ?? "any"}',
        );
      }

      return opportunities;
    } catch (e) {
      if (kDebugMode) {
        print('SalesforceRepository: Error fetching opportunities: $e');
      }
      return [];
    }
  }

  /// Get metadata for a specific object, including all available fields
  Future<Map<String, dynamic>?> getObjectMetadata(String objectName) async {
    if (!_connectionService.isConnected) {
      if (kDebugMode) {
        print(
          'SalesforceRepository: Not connected to Salesforce, cannot get metadata',
        );
      }
      return null;
    }

    try {
      if (kDebugMode) {
        print(
          'SalesforceRepository: Fetching metadata for object: $objectName',
        );
      }

      final data = await _connectionService.get(
        '/services/data/v58.0/sobjects/$objectName/describe',
      );

      if (data == null) {
        if (kDebugMode) {
          print('SalesforceRepository: No metadata returned for $objectName');
        }
        return null;
      }

      if (kDebugMode) {
        print(
          'SalesforceRepository: Successfully retrieved metadata for $objectName',
        );
        if (data.containsKey('fields')) {
          final fields = data['fields'] as List<dynamic>;
          print('SalesforceRepository: Object has ${fields.length} fields');

          // Print the first few field names for debugging
          final fieldNames = fields
              .take(10)
              .map((field) => field['name'])
              .join(', ');
          print('SalesforceRepository: Sample fields: $fieldNames');
        }
      }

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('SalesforceRepository: Error getting object metadata: $e');
      }
      return null;
    }
  }

  /// Get field names for a specific object
  Future<List<String>> getObjectFields(String objectName) async {
    final metadata = await getObjectMetadata(objectName);
    if (metadata == null || !metadata.containsKey('fields')) {
      return [];
    }

    final fields = metadata['fields'] as List<dynamic>;
    return fields.map((field) => field['name'] as String).toList();
  }
}
