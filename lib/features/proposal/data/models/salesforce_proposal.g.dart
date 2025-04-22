// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'salesforce_proposal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SalesforceProposalImpl _$$SalesforceProposalImplFromJson(
        Map<String, dynamic> json) =>
    _$SalesforceProposalImpl(
      id: json['Id'] as String,
      name: json['Name'] as String,
      valorInvestimentoSolar:
          (json['Valor_Investimento_Solar__c'] as num?)?.toDouble(),
      dataDeCriacao: json['Data_de_Criacao__c'] as String,
      dataDeValidade: json['Data_de_Validade__c'] as String,
      status: json['Status__c'] as String,
      totalComissaoRetail: (json['totalComissaoRetail'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$SalesforceProposalImplToJson(
        _$SalesforceProposalImpl instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Name': instance.name,
      'Valor_Investimento_Solar__c': instance.valorInvestimentoSolar,
      'Data_de_Criacao__c': instance.dataDeCriacao,
      'Data_de_Validade__c': instance.dataDeValidade,
      'Status__c': instance.status,
      'totalComissaoRetail': instance.totalComissaoRetail,
    };
