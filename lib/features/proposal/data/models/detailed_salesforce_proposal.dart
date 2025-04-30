import 'package:flutter/foundation.dart'; // For listEquals

import 'proposal_file.dart'; // Use the new proposal-specific file model
import 'cpe_proposal_link.dart'; // Import the CPE link model

// Helper function to safely parse double
double? _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

// Using Manual Immutable Class Pattern

@immutable
class DetailedSalesforceProposal {
  final String id; // Salesforce ID of Proposta__c
  final String name; // Proposta Name (Name)

  // --- Informação da Entidade ---
  final String? entidadeId; // Entidade__c (Lookup Account ID)
  final String? entidadeName; // Entidade__r.Name (Fetched)
  final String? nifC; // NIF__c
  final String?
  oportunidadeId; // Oportunidade__c (Master-Detail Opportunity ID)
  final String? oportunidadeName; // Oportunidade__r.Name (Fetched)
  final String? agenteRetailId; // Agente_Retail__c (Lookup User ID)
  final String? agenteRetailName; // Agente_Retail__r.Name (Fetched)
  final String? responsavelNegocioRetailC; // Responsavel_de_Negocio_Retail__c
  final String?
  responsavelNegocioExclusivoC; // Responsavel_de_Negocio_Exclusivo__c

  // --- Informação da Proposta ---
  final String? statusC; // Status__c (Picklist)
  final String? soluOC; // Solu_o__c (Picklist)
  final double?
  consumoPeriodoContratoKwhC; // Consumo_para_o_per_odo_do_contrato_KWh__c
  final bool? energiaC; // Energia__c (Checkbox)
  final bool? solarC; // Solar__c (Checkbox)
  final double?
  valorInvestimentoSolarC; // Valor_de_Investimento_Solar__c (Currency)
  final String? dataCriacaoPropostaC; // Data_de_Cria_o_da_Proposta__c (Date)
  final String? dataInicioContratoC; // Data_de_In_o_do_Contrato__c (Date)
  final String? dataValidadeC; // Data_de_Validade__c (Date)
  final String? dataFimContratoC; // Data_de_fim_do_Contrato__c (Date)
  final String? bundleC; // Bundle__c (Picklist)
  final bool? contratoInseridoC; // Contrato_inserido__c (Checkbox)

  // --- Related Lists ---
  final List<CpeProposalLink> cpeLinks;
  final List<ProposalFile> files; // Changed to use ProposalFile

  const DetailedSalesforceProposal({
    required this.id,
    required this.name,
    this.entidadeId,
    this.entidadeName,
    this.nifC,
    this.oportunidadeId,
    this.oportunidadeName,
    this.agenteRetailId,
    this.agenteRetailName,
    this.responsavelNegocioRetailC,
    this.responsavelNegocioExclusivoC,
    this.statusC,
    this.soluOC,
    this.consumoPeriodoContratoKwhC,
    this.energiaC,
    this.solarC,
    this.valorInvestimentoSolarC,
    this.dataCriacaoPropostaC,
    this.dataInicioContratoC,
    this.dataValidadeC,
    this.dataFimContratoC,
    this.bundleC,
    this.contratoInseridoC,
    required this.cpeLinks,
    required this.files, // Updated constructor parameter type
  });

  factory DetailedSalesforceProposal.fromJson(Map<String, dynamic> json) {
    // Parse related CPE Links
    List<CpeProposalLink> parsedCpeLinks = [];
    final cpeLinksJson = json['CPE_Propostas__r'] as Map<String, dynamic>?;
    if (cpeLinksJson != null && cpeLinksJson['records'] is List) {
      parsedCpeLinks =
          (cpeLinksJson['records'] as List)
              .map(
                (cpeLinkJson) => CpeProposalLink.fromJson(
                  cpeLinkJson as Map<String, dynamic>,
                ),
              )
              .toList();
    }

    // Parse related Files (ContentDocumentLinks -> ContentDocument)
    List<ProposalFile> parsedFiles = []; // Changed list type
    final filesJson = json['ContentDocumentLinks'] as Map<String, dynamic>?;
    if (filesJson != null && filesJson['records'] is List) {
      parsedFiles =
          (filesJson['records'] as List).map((linkJson) {
            // Use ProposalFile.fromJson which expects the linkJson structure
            return ProposalFile.fromJson(linkJson as Map<String, dynamic>);
          }).toList();
    }

    return DetailedSalesforceProposal(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      // Related object names
      entidadeId: json['Entidade__c'] as String?,
      entidadeName: json['Entidade__r']?['Name'] as String?,
      oportunidadeId: json['Oportunidade__c'] as String?,
      oportunidadeName: json['Oportunidade__r']?['Name'] as String?,
      agenteRetailId: json['Agente_Retail__c'] as String?,
      agenteRetailName: json['Agente_Retail__r']?['Name'] as String?,
      // Direct fields
      nifC: json['NIF__c'] as String?,
      responsavelNegocioRetailC:
          json['Responsavel_de_Negocio_Retail__c'] as String?,
      responsavelNegocioExclusivoC:
          json['Responsavel_de_Negocio_Exclusivo__c'] as String?,
      statusC: json['Status__c'] as String?,
      soluOC: json['Solu_o__c'] as String?,
      consumoPeriodoContratoKwhC: _parseDouble(
        json['Consumo_para_o_per_odo_do_contrato_KWh__c'],
      ),
      energiaC: json['Energia__c'] as bool?,
      solarC: json['Solar__c'] as bool?,
      valorInvestimentoSolarC: _parseDouble(
        json['Valor_de_Investimento_Solar__c'],
      ),
      dataCriacaoPropostaC: json['Data_de_Cria_o_da_Proposta__c'] as String?,
      dataInicioContratoC: json['Data_de_In_o_do_Contrato__c'] as String?,
      dataValidadeC: json['Data_de_Validade__c'] as String?,
      dataFimContratoC: json['Data_de_fim_do_Contrato__c'] as String?,
      bundleC: json['Bundle__c'] as String?,
      contratoInseridoC: json['Contrato_inserido__c'] as bool?,
      // Related lists
      cpeLinks: parsedCpeLinks,
      files: parsedFiles, // Assign the list of ProposalFile
    );
  }

  // --- Implement copyWith ---
  DetailedSalesforceProposal copyWith({
    String? id,
    String? name,
    // Use helper for nullable fields to distinguish between no change and setting to null
    // Or simply allow direct null setting if that's acceptable behavior
    String? entidadeId,
    String? entidadeName,
    String? nifC,
    String? oportunidadeId,
    String? oportunidadeName,
    String? agenteRetailId,
    String? agenteRetailName,
    String? responsavelNegocioRetailC,
    String? responsavelNegocioExclusivoC,
    String? statusC,
    String? soluOC,
    double? consumoPeriodoContratoKwhC,
    bool? energiaC,
    bool? solarC,
    double? valorInvestimentoSolarC,
    String? dataCriacaoPropostaC,
    String? dataInicioContratoC,
    String? dataValidadeC,
    String? dataFimContratoC,
    String? bundleC,
    bool? contratoInseridoC,
    List<CpeProposalLink>? cpeLinks,
    List<ProposalFile>? files,
  }) {
    return DetailedSalesforceProposal(
      id: id ?? this.id,
      name: name ?? this.name,
      entidadeId: entidadeId ?? this.entidadeId,
      entidadeName: entidadeName ?? this.entidadeName,
      nifC: nifC ?? this.nifC,
      oportunidadeId: oportunidadeId ?? this.oportunidadeId,
      oportunidadeName: oportunidadeName ?? this.oportunidadeName,
      agenteRetailId: agenteRetailId ?? this.agenteRetailId,
      agenteRetailName: agenteRetailName ?? this.agenteRetailName,
      responsavelNegocioRetailC:
          responsavelNegocioRetailC ?? this.responsavelNegocioRetailC,
      responsavelNegocioExclusivoC:
          responsavelNegocioExclusivoC ?? this.responsavelNegocioExclusivoC,
      statusC: statusC ?? this.statusC,
      soluOC: soluOC ?? this.soluOC,
      consumoPeriodoContratoKwhC:
          consumoPeriodoContratoKwhC ?? this.consumoPeriodoContratoKwhC,
      energiaC: energiaC ?? this.energiaC,
      solarC: solarC ?? this.solarC,
      valorInvestimentoSolarC:
          valorInvestimentoSolarC ?? this.valorInvestimentoSolarC,
      dataCriacaoPropostaC: dataCriacaoPropostaC ?? this.dataCriacaoPropostaC,
      dataInicioContratoC: dataInicioContratoC ?? this.dataInicioContratoC,
      dataValidadeC: dataValidadeC ?? this.dataValidadeC,
      dataFimContratoC: dataFimContratoC ?? this.dataFimContratoC,
      bundleC: bundleC ?? this.bundleC,
      contratoInseridoC: contratoInseridoC ?? this.contratoInseridoC,
      cpeLinks: cpeLinks ?? this.cpeLinks,
      files: files ?? this.files,
    );
  }

  // --- Placeholder Methods --- (Implement ==, hashCode, toJson, toString later)
  Map<String, dynamic> toJson() {
    // TODO: Implement for comparison or other needs
    // Needs to return a map representation of the object
    return {
      'id': id,
      'name': name,
      'entidadeId': entidadeId,
      'entidadeName': entidadeName,
      'nifC': nifC,
      'oportunidadeId': oportunidadeId,
      'oportunidadeName': oportunidadeName,
      'agenteRetailId': agenteRetailId,
      'agenteRetailName': agenteRetailName,
      'responsavelNegocioRetailC': responsavelNegocioRetailC,
      'responsavelNegocioExclusivoC': responsavelNegocioExclusivoC,
      'statusC': statusC,
      'soluOC': soluOC,
      'consumoPeriodoContratoKwhC': consumoPeriodoContratoKwhC,
      'energiaC': energiaC,
      'solarC': solarC,
      'valorInvestimentoSolarC': valorInvestimentoSolarC,
      'dataCriacaoPropostaC': dataCriacaoPropostaC,
      'dataInicioContratoC': dataInicioContratoC,
      'dataValidadeC': dataValidadeC,
      'dataFimContratoC': dataFimContratoC,
      'bundleC': bundleC,
      'contratoInseridoC': contratoInseridoC,
      // Note: toJson for related lists might be needed if comparing them
      'cpeLinks':
          cpeLinks
              .map((e) => e.toJson())
              .toList(), // Requires toJson in CpeProposalLink
      'files':
          files
              .map((e) => e.toJson())
              .toList(), // Requires toJson in ProposalFile
    };
    // throw UnimplementedError('toJson has not been implemented.');
  }

  @override
  bool operator ==(Object other) {
    // TODO: Implement equality comparison based on all fields
    throw UnimplementedError('operator == has not been implemented.');
  }

  @override
  int get hashCode {
    // TODO: Implement hashCode based on all fields
    throw UnimplementedError('hashCode has not been implemented.');
  }

  @override
  String toString() {
    // TODO: Implement toString for debugging
    return 'DetailedSalesforceProposal(id: $id, name: $name, ...)';
  }
}
