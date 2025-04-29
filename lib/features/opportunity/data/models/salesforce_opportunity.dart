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
    // Use null-coalescing to handle case variations for ID and Name.
    // Cast the result to String AFTER checking both keys.
    final String? idValue = json['Id'] ?? json['id'];
    final String? nameValue = json['Name'] ?? json['name'];

    // Throw if *still* null after checking both cases (defensive check)
    if (idValue == null || nameValue == null) {
      print(
        "Error parsing SalesforceOpportunity: Missing 'Id'/'id' or 'Name'/'name' in JSON after case-insensitive check: $json",
      );
      throw FormatException(
        "Missing required fields (Id/id, Name/name) in SalesforceOpportunity JSON",
      );
    }

    return SalesforceOpportunity(
      id: idValue, // Use the extracted value
      name: nameValue, // Use the extracted value
      accountName: json['Nome_Entidade__c'] as String?,
      resellerName:
          json['resellerName']
              as String?, // Ensure this key matches function output
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
