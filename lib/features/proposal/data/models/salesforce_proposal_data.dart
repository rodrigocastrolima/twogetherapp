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

    List<SalesforceCPEProposalData> cpes = [];
    // Handle potential null or incorrect type for nested records
    final cpeRecords = json['CPE_Propostas__r']?['records'];
    if (cpeRecords != null && cpeRecords is List) {
      cpes =
          cpeRecords
              .map((cpeJson) {
                try {
                  // Ensure each item is a map before parsing
                  if (cpeJson is Map<String, dynamic>) {
                    return SalesforceCPEProposalData.fromJson(cpeJson);
                  } else {
                    print(
                      '[SalesforceProposalData.fromJson] Skipping non-map item in CPE list: $cpeJson',
                    );
                    return null;
                  }
                } catch (e) {
                  print(
                    '[SalesforceProposalData.fromJson] Error parsing CPE item: $e - Item: $cpeJson',
                  );
                  return null;
                }
              })
              .whereType<
                SalesforceCPEProposalData
              >() // Filter out nulls from errors/skips
              .toList();
    }

    final proposal = SalesforceProposalData(
      id: json['Id'] as String? ?? 'Unknown ID',
      name: json['Name'] as String? ?? 'Unknown Name',
      nifC: json['NIF__c'] as String?, // <-- PARSE NIF FIELD
      status: json['Status__c'] as String?,
      // Use correct field names based on your actual JSON response
      createdDate: json['Data_de_Cria_o_da_Proposta__c'] as String?,
      expiryDate: json['Data_de_Validade__c'] as String?,
      cpePropostas: cpes.isNotEmpty ? cpes : null,
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
