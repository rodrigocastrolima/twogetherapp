import 'package:flutter/foundation.dart';
import './salesforce_cpe_proposal_data.dart'; // Import needed for nested parsing

/// Represents the main Proposal data fetched for resellers.
@immutable
class SalesforceProposalData {
  final String id;
  final String name;
  final String? status; // Status__c
  final String? createdDate; // CreatedDate (String from SF)
  final String? expiryDate; // Data_de_Validade__c
  final List<SalesforceCPEProposalData> cpePropostas; // List for nested CPEs

  const SalesforceProposalData({
    required this.id,
    required this.name,
    this.status,
    this.createdDate,
    this.expiryDate,
    required this.cpePropostas, // Add to constructor
  });

  factory SalesforceProposalData.fromJson(Map<String, dynamic> json) {
    List<SalesforceCPEProposalData> parsedCpeList = [];
    // 1. Safely access the relationship object as a generic Map first
    final cpeRelationshipMap = json['CPE_Propostas__r'] as Map?;

    // 2. Check if it exists and contains a 'records' list
    if (cpeRelationshipMap != null && cpeRelationshipMap['records'] is List) {
      // 3. Cast the records to a List<dynamic> (safer than just List)
      final cpeRecords = cpeRelationshipMap['records'] as List<dynamic>;

      parsedCpeList =
          cpeRecords
              .map((item) {
                // 4. Ensure each item is a Map before casting and parsing
                if (item is Map) {
                  try {
                    // Explicit cast of the item Map
                    final Map<String, dynamic> typedItemMap =
                        Map<String, dynamic>.from(item);
                    return SalesforceCPEProposalData.fromJson(typedItemMap);
                  } catch (e) {
                    print(
                      'Error parsing nested CPE Proposal item: $e - Item: $item',
                    ); // Log item
                    return null;
                  }
                } else {
                  print(
                    'Skipping non-map item in CPE records: ${item?.runtimeType}',
                  );
                  return null;
                }
              })
              .whereType<SalesforceCPEProposalData>()
              .toList();
    } else if (cpeRelationshipMap != null) {
      // Log if CPE_Propostas__r exists but doesn't contain a valid records list
      print(
        'CPE_Propostas__r found but records are not a list or null: ${cpeRelationshipMap['records']}',
      );
    }

    return SalesforceProposalData(
      id: json['Id'] as String? ?? 'Unknown ID',
      name: json['Name'] as String? ?? 'Unknown Name',
      status: json['Status__c'] as String?,
      createdDate: json['Data_de_Cria_o_da_Proposta__c'] as String?,
      expiryDate: json['Data_de_Validade__c'] as String?,
      cpePropostas: parsedCpeList,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceProposalData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          status == other.status &&
          createdDate == other.createdDate &&
          expiryDate == other.expiryDate &&
          // Compare lists as well
          listEquals(cpePropostas, other.cpePropostas);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      status.hashCode ^
      createdDate.hashCode ^
      expiryDate.hashCode ^
      Object.hashAll(cpePropostas); // Hash list

  @override
  String toString() {
    // Add CPE count to toString
    return 'SalesforceProposalData{id: $id, name: $name, status: $status, createdDate: $createdDate, expiryDate: $expiryDate, cpeCount: ${cpePropostas.length}}';
  }
}
