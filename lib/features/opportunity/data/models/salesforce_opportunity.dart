import 'package:flutter/foundation.dart';

/// Represents information about a single Proposal related to an Opportunity.
@immutable
class SalesforceProposalInfo {
  final String id;
  final String? statusC; // Status__c
  final String? dataDeCriacaoDaPropostaC; // Data_de_Cria_o_da_Proposta__c

  const SalesforceProposalInfo({
    required this.id,
    this.statusC,
    this.dataDeCriacaoDaPropostaC,
  });

  factory SalesforceProposalInfo.fromJson(Map<String, dynamic> json) {
    return SalesforceProposalInfo(
      id: json['Id'] as String, // Assume ID is always present
      statusC: json['Status__c'] as String?,
      dataDeCriacaoDaPropostaC:
          json['Data_de_Cria_o_da_Proposta__c'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceProposalInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          statusC == other.statusC &&
          dataDeCriacaoDaPropostaC == other.dataDeCriacaoDaPropostaC;

  @override
  int get hashCode =>
      id.hashCode ^ statusC.hashCode ^ dataDeCriacaoDaPropostaC.hashCode;

  @override
  String toString() {
    return 'SalesforceProposalInfo{id: $id, statusC: $statusC, dataDeCriacaoDaPropostaC: $dataDeCriacaoDaPropostaC}';
  }
}

/// Represents the structure returned by Salesforce for a subquery relationship.
@immutable
class RelatedProposals {
  final int totalSize;
  final bool done;
  final List<SalesforceProposalInfo> records;

  const RelatedProposals({
    required this.totalSize,
    required this.done,
    required this.records,
  });

  factory RelatedProposals.fromJson(Map<String, dynamic> json) {
    var recordsList = <SalesforceProposalInfo>[];
    if (json['records'] != null && json['records'] is List) {
      try {
        recordsList =
            (json['records'] as List)
                // Check if item is a Map, not strictly Map<String, dynamic>
                .where((item) => item is Map)
                .map((item) {
                  // Still cast to Map<String, dynamic> for SalesforceProposalInfo.fromJson
                  return SalesforceProposalInfo.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  );
                })
                .toList();
      } catch (e, s) {
        if (kDebugMode) {
          print(
            'Error parsing individual proposal info within RelatedProposals: $e\n$s\nRecord JSON: $json',
          );
        }
        recordsList = [];
      }
    }
    return RelatedProposals(
      totalSize: json['totalSize'] as int? ?? 0,
      done: json['done'] as bool? ?? true,
      records: recordsList,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelatedProposals &&
          runtimeType == other.runtimeType &&
          totalSize == other.totalSize &&
          done == other.done &&
          listEquals(records, other.records);

  @override
  int get hashCode => totalSize.hashCode ^ done.hashCode ^ records.hashCode;

  @override
  String toString() {
    return 'RelatedProposals{totalSize: $totalSize, done: $done, records: ${records.length} items}';
  }
}

/// Represents the summary data for an Opportunity fetched from Salesforce.
@immutable
class SalesforceOpportunity {
  final String id;
  final String name;
  final String? accountName; // From Nome_Entidade__c
  final String? resellerName; // Not currently fetched/used in list?
  final String? nifC; // NIF__c
  final String? faseC; // Fase__c
  final String? createdDate; // CreatedDate
  final String? segmentoDeClienteC; // Segmento_de_Cliente__c
  final RelatedProposals?
  propostasR; // Propostas__r - Added for nested proposals

  const SalesforceOpportunity({
    required this.id,
    required this.name,
    this.accountName,
    this.resellerName, // Keep for potential future use
    this.nifC, // Renamed for Dart convention
    this.faseC, // Renamed for Dart convention
    this.createdDate, // Renamed for Dart convention
    this.segmentoDeClienteC, // <<< NEW PARAM
    this.propostasR, // Added
  });

  factory SalesforceOpportunity.fromJson(Map<String, dynamic> json) {
    // Use null-coalescing to handle case variations for ID and Name.
    final String? idValue = json['Id'] ?? json['id'];
    final String? nameValue = json['Name'] ?? json['name'];

    if (idValue == null || nameValue == null) {
      if (kDebugMode) {
        print(
          "Error parsing SalesforceOpportunity: Missing 'Id'/'id' or 'Name'/'name' in JSON: $json",
        );
      }
      throw FormatException(
        "Missing required fields (Id/id, Name/name) in SalesforceOpportunity JSON",
      );
    }

    // Parse the nested Propostas__r structure if present
    RelatedProposals? relatedProposals;
    if (json['Propostas__r'] != null && json['Propostas__r'] is Map) {
      try {
        final propostasMap = Map<String, dynamic>.from(
          json['Propostas__r'] as Map,
        );
        relatedProposals = RelatedProposals.fromJson(propostasMap);
      } catch (e, s) {
        if (kDebugMode) {
          print(
            'Error occurred during RelatedProposals.fromJson: $e\n$s\nInput JSON for Propostas__r: ${json['Propostas__r']}',
          );
        }
        relatedProposals = null;
      }
    } else if (json['Propostas__r'] != null) {
      if (kDebugMode) {
        print(
          'Warning: Propostas__r field was present but not a Map<String, dynamic>. Type: ${json['Propostas__r'].runtimeType}, Value: ${json['Propostas__r']}',
        );
      }
    }

    return SalesforceOpportunity(
      id: idValue,
      name: nameValue,
      accountName:
          json['Nome_Entidade__c'] as String?, // Map from correct SF field
      // resellerName is not included in the getResellerOpportunities query currently
      resellerName: null, // Explicitly null as it's not fetched
      nifC: json['NIF__c'] as String?,
      faseC: json['Fase__c'] as String?,
      createdDate: json['CreatedDate'] as String?,
      segmentoDeClienteC:
          json['Segmento_de_Cliente__c'] as String?, // <<< NEW MAPPING
      propostasR: relatedProposals, // Assign parsed proposals
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
          nifC == other.nifC &&
          faseC == other.faseC &&
          createdDate == other.createdDate &&
          segmentoDeClienteC ==
              other.segmentoDeClienteC && // <<< NEW COMPARISON
          propostasR == other.propostasR; // Added

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      accountName.hashCode ^
      resellerName.hashCode ^
      nifC.hashCode ^
      faseC.hashCode ^
      createdDate.hashCode ^
      segmentoDeClienteC.hashCode ^ // <<< NEW HASHCODE PART
      propostasR.hashCode; // Added

  // Optional: Add toString for easier debugging
  @override
  String toString() {
    return 'SalesforceOpportunity{id: $id, name: $name, accountName: $accountName, nifC: $nifC, faseC: $faseC, createdDate: $createdDate, segmentoDeClienteC: $segmentoDeClienteC, propostasR: $propostasR}'; // Updated
  }
}
