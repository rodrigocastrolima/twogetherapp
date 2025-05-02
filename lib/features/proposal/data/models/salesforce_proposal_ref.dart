import 'package:flutter/foundation.dart';

/// Represents a reference to a Salesforce Proposal (Id and Name).
/// Used when fetching proposals via the reseller-specific JWT flow.
@immutable
class SalesforceProposalRef {
  final String id;
  final String name;

  const SalesforceProposalRef({required this.id, required this.name});

  /// Creates an instance from a JSON map, expecting 'Id' and 'Name' keys.
  factory SalesforceProposalRef.fromJson(Map<String, dynamic> json) {
    final idValue = json['Id'] as String?;
    final nameValue = json['Name'] as String?;

    if (idValue == null) {
      throw const FormatException(
        "Missing required field: 'Id' in SalesforceProposalRef JSON",
      );
    }
    if (nameValue == null) {
      throw const FormatException(
        "Missing required field: 'Name' in SalesforceProposalRef JSON",
      );
    }
    return SalesforceProposalRef(id: idValue, name: nameValue);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceProposalRef &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() {
    return 'SalesforceProposalRef{id: $id, name: $name}';
  }
}
