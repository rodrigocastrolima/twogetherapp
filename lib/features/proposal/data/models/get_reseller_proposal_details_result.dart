import 'package:flutter/foundation.dart';
import './salesforce_cpe_proposal_data.dart';
import './salesforce_proposal_data.dart';

// --- THIS ENTIRE CLASS IS NO LONGER NEEDED ---
// The Cloud Function now returns SalesforceProposalData directly,
// which includes the nested CPE list.
/*
@immutable
class GetResellerProposalDetailsResult {
  final SalesforceProposalData proposal;
  final List<SalesforceCPEProposalData> cpePropostas;

  const GetResellerProposalDetailsResult({
    required this.proposal,
    required this.cpePropostas,
  });

  /// Creates an instance from the JSON map returned by the Cloud Function.
  /// Assumes the function returns { success: true, proposal: {...}, cpePropostas: [...] }.
  factory GetResellerProposalDetailsResult.fromJson(Map<String, dynamic> json) {
    // Explicitly cast the nested proposal map
    final proposalMap = json['proposal'] as Map?;
    final cpeListData = json['cpePropostas'] as List<dynamic>?;

    if (proposalMap == null) {
      throw const FormatException(
        "Missing or invalid 'proposal' field in GetResellerProposalDetailsResult JSON",
      );
    }
    // Ensure it's converted to the correct type before passing to nested fromJson
    final Map<String, dynamic> typedProposalMap = Map<String, dynamic>.from(
      proposalMap,
    );

    final List<SalesforceCPEProposalData> cpeList =
        (cpeListData ?? [])
            .map((item) {
              // Explicitly cast each item in the list
              if (item is Map) {
                // Check if it's a Map
                try {
                  // Convert to the correct type before passing to nested fromJson
                  final Map<String, dynamic> typedItemMap =
                      Map<String, dynamic>.from(item);
                  return SalesforceCPEProposalData.fromJson(typedItemMap);
                } catch (e) {
                  print('Error parsing CPE Proposal item: $e');
                  return null;
                }
              } else {
                return null;
              }
            })
            .whereType<SalesforceCPEProposalData>()
            .toList();

    return GetResellerProposalDetailsResult(
      // Pass the correctly typed map
      proposal: SalesforceProposalData.fromJson(typedProposalMap),
      cpePropostas: cpeList,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetResellerProposalDetailsResult &&
          runtimeType == other.runtimeType &&
          proposal == other.proposal &&
          // Use collection equality for the list
          listEquals(cpePropostas, other.cpePropostas);

  @override
  int get hashCode => proposal.hashCode ^ Object.hashAll(cpePropostas);

  @override
  String toString() {
    return 'GetResellerProposalDetailsResult{proposal: $proposal, cpePropostas count: ${cpePropostas.length}}';
  }
}
*/

/// Represents the main proposal data from Salesforce.
@immutable
class SalesforceProposalData {
  final String id;
  final String name;
  final String? nifC;
  final String? status;
  final String? createdDate;
  final String? expiryDate;
  final List<SalesforceCPEProposalData>? cpePropostas;

  const SalesforceProposalData({
    required this.id,
    required this.name,
    this.nifC,
    this.status,
    this.createdDate,
    this.expiryDate,
    this.cpePropostas,
  });

  // Factory constructor from JSON
  factory SalesforceProposalData.fromJson(Map<String, dynamic> json) {
    // +++ DEBUG: Log input JSON +++
    if (kDebugMode) {
      print("[SalesforceProposalData.fromJson] Input JSON: $json");
    }
    // +++ END DEBUG +++

    List<SalesforceCPEProposalData> cpes = [];
    if (json['CPE_Propostas__r'] != null &&
        json['CPE_Propostas__r']['records'] is List) {
      cpes =
          (json['CPE_Propostas__r']['records'] as List)
              .map(
                (cpeJson) => SalesforceCPEProposalData.fromJson(
                  cpeJson as Map<String, dynamic>,
                ),
              )
              .toList();
    }

    final proposal = SalesforceProposalData(
      id: json['Id'] as String? ?? 'Unknown ID',
      name: json['Name'] as String? ?? 'Unknown Name',
      nifC: json['NIF__c'] as String?,
      status: json['Status__c'] as String?,
      createdDate: json['Data_de_Cria_o_da_Proposta__c'] as String?,
      expiryDate: json['Data_de_Validade__c'] as String?,
      cpePropostas: cpes.isNotEmpty ? cpes : null,
    );

    // +++ DEBUG: Log created object +++
    if (kDebugMode) {
      print(
        "[SalesforceProposalData.fromJson] Created Object: ${proposal.toString()}",
      );
      print("[SalesforceProposalData.fromJson] Parsed nifC: ${proposal.nifC}");
    }
    // +++ END DEBUG +++

    return proposal;
  }

  // CopyWith method for immutability (if needed)
  SalesforceProposalData copyWith({
    String? id,
    String? name,
    String? nifC,
    String? status,
    String? createdDate,
    String? expiryDate,
    List<SalesforceCPEProposalData>? cpePropostas,
  }) {
    return SalesforceProposalData(
      id: id ?? this.id,
      name: name ?? this.name,
      nifC: nifC ?? this.nifC,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
      expiryDate: expiryDate ?? this.expiryDate,
      cpePropostas: cpePropostas ?? this.cpePropostas,
    );
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
