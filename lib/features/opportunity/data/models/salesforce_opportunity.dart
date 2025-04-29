import 'package:flutter/foundation.dart';

/// Represents the summary data for an Opportunity fetched from Salesforce.
@immutable
class SalesforceOpportunity {
  final String id;
  final String name;
  final String? accountName; // Account.Name can be null
  final String? resellerName; // Agente_Retail__r.Name can be null
  final String? NIF__c; // Added
  final String? Fase__c; // Added
  final String?
  CreatedDate; // Added - Made nullable for safety, confirm if always present

  const SalesforceOpportunity({
    required this.id,
    required this.name,
    this.accountName,
    this.resellerName,
    this.NIF__c, // Added
    this.Fase__c, // Added
    this.CreatedDate, // Added
  });

  factory SalesforceOpportunity.fromJson(Map<String, dynamic> json) {
    // Check for required Salesforce fields (case-sensitive)
    if (json['Id'] == null || json['Name'] == null) {
      print(
        "Error parsing SalesforceOpportunity: Missing 'Id' or 'Name' in JSON: $json",
      );
      throw FormatException(
        "Missing required fields (Id, Name) in SalesforceOpportunity JSON",
      );
    }
    return SalesforceOpportunity(
      id: json['Id'] as String, // Read uppercase 'Id'
      name: json['Name'] as String, // Read uppercase 'Name'
      // Assuming Account Name is mapped from 'Nome_Entidade__c'
      accountName: json['Nome_Entidade__c'] as String?,
      // Assuming Reseller Name is mapped from 'Agente_Retail__r'?['Name'] to 'resellerName' by the function?
      // If the key is different, adjust here.
      resellerName: json['resellerName'] as String?,
      // Added fields - read from JSON, assuming these keys
      NIF__c: json['NIF__c'] as String?,
      Fase__c: json['Fase__c'] as String?,
      CreatedDate: json['CreatedDate'] as String?,
    );
  }

  // Optional: Add equality and hashCode for potential use in state management/testing
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceOpportunity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          accountName == other.accountName &&
          resellerName == other.resellerName &&
          NIF__c == other.NIF__c && // Added
          Fase__c == other.Fase__c && // Added
          CreatedDate == other.CreatedDate; // Added

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      accountName.hashCode ^
      resellerName.hashCode ^
      NIF__c.hashCode ^ // Added
      Fase__c.hashCode ^ // Added
      CreatedDate.hashCode; // Added

  // Optional: Add toString for easier debugging
  @override
  String toString() {
    return 'SalesforceOpportunity{id: $id, name: $name, accountName: $accountName, resellerName: $resellerName, NIF__c: $NIF__c, Fase__c: $Fase__c, CreatedDate: $CreatedDate}'; // Added
  }
}
