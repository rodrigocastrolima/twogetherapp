import 'package:freezed_annotation/freezed_annotation.dart';

part 'salesforce_proposal.freezed.dart';
part 'salesforce_proposal.g.dart';

// Represents the data structure returned by the getOpportunityProposals Cloud Function
@freezed
class SalesforceProposal with _$SalesforceProposal {
  const factory SalesforceProposal({
    @JsonKey(name: 'Id') // Map Dart 'id' to JSON 'Id'
    required String id,
    @JsonKey(name: 'Name') // Map Dart 'name' to JSON 'Name'
    required String name,
    @JsonKey(name: 'Valor_Investimento_Solar__c')
    double? valorInvestimentoSolar,
    @JsonKey(name: 'Data_de_Criacao__c')
    required String dataDeCriacao, // Keep as String for initial parsing
    @JsonKey(name: 'Data_de_Validade__c')
    required String dataDeValidade, // Keep as String for initial parsing
    @JsonKey(name: 'Status__c') required String status,
    // Matches the aggregated commission field from the Cloud Function
    double? totalComissaoRetail,
  }) = _SalesforceProposal;

  // REMOVED GETTERS TO AVOID BUILD ERRORS
  // const SalesforceProposal._(); // No longer needed if no custom getters/methods

  factory SalesforceProposal.fromJson(Map<String, dynamic> json) =>
      _$SalesforceProposalFromJson(json);
}
