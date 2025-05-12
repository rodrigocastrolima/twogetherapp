import 'package:flutter/foundation.dart';
import './salesforce_cpe_proposal_data.dart'; // Import needed for nested parsing

/// Represents the main Proposal data fetched for resellers.
@immutable
class SalesforceProposalData {
  final String id;
  final String name;
  final String? nifC;
  final String? status; // Status__c
  final String? createdDate; // CreatedDate (String from SF)
  final String? expiryDate; // Data_de_Validade__c
  final List<SalesforceCPEProposalData>? cpePropostas; // List for nested CPEs

  const SalesforceProposalData({
    required this.id,
    required this.name,
    this.nifC,
    this.status,
    this.createdDate,
    this.expiryDate,
    this.cpePropostas,
  });

  factory SalesforceProposalData.fromJson(Map<String, dynamic> json) {
    // +++ DEBUG: Log input JSON +++
    if (kDebugMode) {
      print(
        "[SalesforceProposalData.fromJson (in salesforce_proposal_data.dart)] Input JSON: $json",
      );
    }
    // +++ END DEBUG +++

    final cpeData = json['CPE_Propostas__r'] as Map<String, dynamic>?;
    List<SalesforceCPEProposalData>? parsedCpes;

    if (cpeData != null &&
        cpeData['records'] != null &&
        cpeData['records'] is List) {
      final recordsList = cpeData['records'] as List;
      parsedCpes =
          recordsList
              .map((item) {
                // Explicitly check if item is a Map before parsing
                if (item is Map<String, dynamic>) {
                  return SalesforceCPEProposalData.fromJson(item);
                } else {
                  // Log or handle the case where an item is not a Map
                  if (kDebugMode) {
                    print(
                      '[SalesforceProposalData.fromJson] Skipping non-map item in CPE list: $item',
                    );
                  }
                  return null; // Return null for invalid items
                }
              })
              .whereType<
                SalesforceCPEProposalData
              >() // Filter out any nulls resulting from invalid items
              .toList();
    } else {
      if (kDebugMode) {
        print(
          '[SalesforceProposalData.fromJson] CPE_Propostas__r or records field missing or not in expected format: ${json['CPE_Propostas__r']}',
        );
      }
    }

    final proposal = SalesforceProposalData(
      id: json['Id'] as String? ?? 'Unknown ID',
      name: json['Name'] as String? ?? 'Unknown Name',
      nifC: json['NIF__c'] as String?, // <-- PARSE NIF FIELD
      status: json['Status__c'] as String?,
      // Use correct field names based on your actual JSON response
      createdDate: json['Data_de_Cria_o_da_Proposta__c'] as String?,
      expiryDate: json['Data_de_Validade__c'] as String?,
      cpePropostas: parsedCpes, // Assign the correctly parsed list
    );

    // +++ DEBUG: Log created object +++
    if (kDebugMode) {
      print(
        "[SalesforceProposalData.fromJson (in salesforce_proposal_data.dart)] Created Object: ${proposal.toString()}",
      );
      print(
        "[SalesforceProposalData.fromJson (in salesforce_proposal_data.dart)] Parsed nifC: ${proposal.nifC}",
      );
    }
    // +++ END DEBUG +++

    return proposal;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceProposalData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          nifC == other.nifC &&
          status == other.status &&
          createdDate == other.createdDate &&
          expiryDate == other.expiryDate &&
          listEquals(cpePropostas, other.cpePropostas);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      nifC.hashCode ^
      status.hashCode ^
      createdDate.hashCode ^
      expiryDate.hashCode ^
      Object.hashAll(cpePropostas ?? []);

  @override
  String toString() {
    return 'SalesforceProposalData{id: $id, name: $name, nifC: $nifC, status: $status, createdDate: $createdDate, expiryDate: $expiryDate, cpePropostas: ${cpePropostas?.length}}';
  }
}
