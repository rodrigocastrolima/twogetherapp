import 'package:flutter/foundation.dart';

/// Represents the summary data for an Opportunity fetched from Salesforce.
@immutable
class SalesforceOpportunity {
  final String id;
  final String name;
  final String? accountName; // Account.Name can be null
  final String? resellerName; // Agente_Retail__r.Name can be null

  const SalesforceOpportunity({
    required this.id,
    required this.name,
    this.accountName,
    this.resellerName,
  });

  factory SalesforceOpportunity.fromJson(Map<String, dynamic> json) {
    // Basic error checking/logging can be added here if needed
    if (json['id'] == null || json['name'] == null) {
      // Handle cases where essential data is missing from the function result
      // This shouldn't happen with the current query, but good for robustness
      print(
        "Error parsing SalesforceOpportunity: Missing 'id' or 'name' in JSON: $json",
      );
      // Return a default/error state or throw?
      // Throwing might be better to signal data issues upstream.
      throw FormatException(
        "Missing required fields (id, name) in SalesforceOpportunity JSON",
      );
    }
    return SalesforceOpportunity(
      id: json['id'] as String,
      name: json['name'] as String,
      accountName:
          json['accountName'] as String?, // Directly cast, handles null
      resellerName:
          json['resellerName'] as String?, // Directly cast, handles null
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
          resellerName == other.resellerName;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      accountName.hashCode ^
      resellerName.hashCode;

  // Optional: Add toString for easier debugging
  @override
  String toString() {
    return 'SalesforceOpportunity{id: $id, name: $name, accountName: $accountName, resellerName: $resellerName}';
  }
}
