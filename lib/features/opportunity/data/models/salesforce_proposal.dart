import 'package:flutter/foundation.dart';

@immutable
class SalesforceProposal {
  final String id;
  final String name;
  // Add other fields like status, amount later if needed

  const SalesforceProposal({required this.id, required this.name});

  factory SalesforceProposal.fromJson(Map<String, dynamic> json) {
    return SalesforceProposal(
      id: json['Id'] ?? (throw FormatException('Missing Id in proposal data')),
      name:
          json['Name'] ??
          (throw FormatException('Missing Name in proposal data')),
      // Parse other fields here when added
    );
  }

  // Basic toString for debugging
  @override
  String toString() {
    return 'SalesforceProposal{id: $id, name: $name}';
  }

  // Basic equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceProposal &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      // Add other fields here when they exist in the model
    };
  }
}
