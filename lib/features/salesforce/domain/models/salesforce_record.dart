import 'package:json_annotation/json_annotation.dart';

/// Base class for all Salesforce records
class SalesforceRecord {
  /// The Salesforce record ID
  final String id;

  /// The object type/name (e.g., Account, Contact, Opportunity)
  final String type;

  /// URL to access this record in Salesforce
  final String? url;

  /// When the record was created
  final DateTime createdDate;

  /// Last modified date
  final DateTime lastModifiedDate;

  /// User who created the record
  final String? createdById;

  /// User who last modified the record
  final String? lastModifiedById;

  SalesforceRecord({
    required this.id,
    required this.type,
    this.url,
    required this.createdDate,
    required this.lastModifiedDate,
    this.createdById,
    this.lastModifiedById,
  });

  /// Create from JSON map
  factory SalesforceRecord.fromJson(Map<String, dynamic> json) {
    return SalesforceRecord(
      id: json['Id'] as String,
      type: json['attributes']?['type'] as String? ?? 'Unknown',
      url: json['attributes']?['url'] as String?,
      createdDate:
          json['CreatedDate'] != null
              ? DateTime.parse(json['CreatedDate'] as String)
              : DateTime.now(),
      lastModifiedDate:
          json['LastModifiedDate'] != null
              ? DateTime.parse(json['LastModifiedDate'] as String)
              : DateTime.now(),
      createdById: json['CreatedById'] as String?,
      lastModifiedById: json['LastModifiedById'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'attributes': {'type': type, if (url != null) 'url': url},
      'CreatedDate': createdDate.toIso8601String(),
      'LastModifiedDate': lastModifiedDate.toIso8601String(),
      if (createdById != null) 'CreatedById': createdById,
      if (lastModifiedById != null) 'LastModifiedById': lastModifiedById,
    };
  }

  @override
  String toString() {
    return '$type: $id';
  }
}
