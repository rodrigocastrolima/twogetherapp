import 'package:flutter/foundation.dart';
import 'salesforce_proposal.dart'; // Import the proposal model

@immutable
class DetailedSalesforceOpportunity {
  final String id;
  final String name;
  final String? accountName;
  final String? accountId;
  final String? resellerName;
  final String? resellerSalesforceId;
  final String? nifC;
  final String? faseC;
  final String? createdDate;
  final String? tipoDeOportunidadeC;
  final String? segmentoDeClienteC;
  final String? soluOC;
  final String? dataDePrevisaoDeFechoC;
  final String? dataDeCriacaoDaOportunidadeC;
  final List<SalesforceProposal> proposals; // List of related proposals

  const DetailedSalesforceOpportunity({
    required this.id,
    required this.name,
    this.accountName,
    this.accountId,
    this.resellerName,
    this.resellerSalesforceId,
    this.nifC,
    this.faseC,
    this.createdDate,
    this.tipoDeOportunidadeC,
    this.segmentoDeClienteC,
    this.soluOC,
    this.dataDePrevisaoDeFechoC,
    this.dataDeCriacaoDaOportunidadeC,
    required this.proposals,
  });

  factory DetailedSalesforceOpportunity.fromJson(Map<String, dynamic> json) {
    // Parse the opportunity details
    final Map<String, dynamic>? oppData = json['opportunity'];
    if (oppData == null) {
      throw FormatException(
        "Missing 'opportunity' data in JSON for DetailedSalesforceOpportunity",
      );
    }

    // Parse the proposals list
    final List<dynamic> proposalListJson = json['proposals'] ?? [];
    final List<SalesforceProposal> parsedProposals =
        proposalListJson
            .map(
              (proposalJson) => SalesforceProposal.fromJson(
                proposalJson as Map<String, dynamic>,
              ),
            )
            .toList();

    return DetailedSalesforceOpportunity(
      id:
          oppData['Id'] ??
          (throw FormatException('Missing Id in opportunity data')),
      name:
          oppData['Name'] ??
          (throw FormatException('Missing Name in opportunity data')),
      accountName: oppData['AccountName'] as String?,
      accountId: oppData['AccountId'] as String?,
      resellerName: oppData['ResellerName'] as String?,
      resellerSalesforceId: oppData['ResellerSalesforceId'] as String?,
      nifC: oppData['NIF__c'] as String?,
      faseC: oppData['Fase__c'] as String?,
      createdDate:
          oppData['CreatedDate']
              as String?, // Consider DateTime parsing if needed later
      tipoDeOportunidadeC: oppData['Tipo_de_Oportunidade__c'] as String?,
      segmentoDeClienteC: oppData['Segmento_de_Cliente__c'] as String?,
      soluOC: oppData['Solu_o__c'] as String?,
      dataDePrevisaoDeFechoC:
          oppData['Data_de_Previs_o_de_Fecho__c'] as String?,
      dataDeCriacaoDaOportunidadeC:
          oppData['Data_de_Cria_o_da_Oportunidade__c'] as String?,
      proposals: parsedProposals,
    );
  }

  // Basic toString for debugging
  @override
  String toString() {
    return 'DetailedSalesforceOpportunity{id: $id, name: $name, accountId: $accountId, resellerSalesforceId: $resellerSalesforceId, proposals: ${proposals.length}}';
  }

  // Basic equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetailedSalesforceOpportunity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
