import 'package:flutter/foundation.dart';

/// Simplified model for Salesforce Proposal containing only the Name.
/// Used when fetching proposals via the reseller-specific JWT flow.
@immutable
class SalesforceProposalNameOnly {
  final String name;

  const SalesforceProposalNameOnly({required this.name});

  /// Creates an instance from a JSON map, expecting a 'Name' key.
  factory SalesforceProposalNameOnly.fromJson(Map<String, dynamic> json) {
    final nameValue = json['Name'] as String?;
    if (nameValue == null) {
      throw const FormatException(
        "Missing required field: 'Name' in SalesforceProposalNameOnly JSON",
      );
    }
    return SalesforceProposalNameOnly(name: nameValue);
  }

  // Optional: Add equality and hashCode
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceProposalNameOnly &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  // Optional: Add toString for debugging
  @override
  String toString() {
    return 'SalesforceProposalNameOnly{name: $name}';
  }
}
