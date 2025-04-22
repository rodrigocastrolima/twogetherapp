// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'salesforce_opportunity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SalesforceOpportunityImpl _$$SalesforceOpportunityImplFromJson(
        Map<String, dynamic> json) =>
    _$SalesforceOpportunityImpl(
      id: json['Id'] as String,
      name: json['Name'] as String,
      NIF__c: json['NIF__c'] as String?,
      Fase__c: json['Fase__c'] as String?,
      CreatedDate: json['CreatedDate'] as String,
      Nome_Entidade__c: json['Nome_Entidade__c'] as String?,
    );

Map<String, dynamic> _$$SalesforceOpportunityImplToJson(
        _$SalesforceOpportunityImpl instance) =>
    <String, dynamic>{
      'Id': instance.id,
      'Name': instance.name,
      'NIF__c': instance.NIF__c,
      'Fase__c': instance.Fase__c,
      'CreatedDate': instance.CreatedDate,
      'Nome_Entidade__c': instance.Nome_Entidade__c,
    };
