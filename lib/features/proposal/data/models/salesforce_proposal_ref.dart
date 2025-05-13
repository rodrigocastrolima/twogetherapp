import 'package:flutter/foundation.dart';

/// Represents a reference to a Salesforce Proposal (Id and Name).
/// Used when fetching proposals via the reseller-specific JWT flow.
@immutable
class SalesforceProposalRef {
  final String id;
  final String name;
  final String? statusC;
  final String? dataDeCriacaoDaPropostaC;

  const SalesforceProposalRef({
    required this.id,
    required this.name,
    this.statusC,
    this.dataDeCriacaoDaPropostaC,
  });

  /// Creates an instance from a JSON map, expecting 'Id' and 'Name' keys.
  factory SalesforceProposalRef.fromJson(Map<String, dynamic> json) {
    return SalesforceProposalRef(
      id: json['Id'] as String,
      name: json['Name'] as String,
      statusC: json['Status__c'] as String?,
      dataDeCriacaoDaPropostaC:
          json['Data_de_Cria_o_da_Proposta__c'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceProposalRef &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          statusC == other.statusC &&
          dataDeCriacaoDaPropostaC == other.dataDeCriacaoDaPropostaC;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      statusC.hashCode ^
      dataDeCriacaoDaPropostaC.hashCode;

  @override
  String toString() {
    return 'SalesforceProposalRef{id: $id, name: $name, statusC: $statusC, dataDeCriacaoDaPropostaC: $dataDeCriacaoDaPropostaC}';
  }
}
