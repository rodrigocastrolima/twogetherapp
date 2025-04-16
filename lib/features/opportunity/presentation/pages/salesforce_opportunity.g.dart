// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'salesforce_opportunity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SalesforceOpportunityImpl _$$SalesforceOpportunityImplFromJson(
        Map<String, dynamic> json) =>
    _$SalesforceOpportunityImpl(
      Id: json['Id'] as String,
      Name: json['Name'] as String,
      NIF__c: json['NIF__c'] as String?,
      Fase__c: json['Fase__c'] as String?,
      CreatedDate: json['CreatedDate'] as String,
    );

Map<String, dynamic> _$$SalesforceOpportunityImplToJson(
        _$SalesforceOpportunityImpl instance) =>
    <String, dynamic>{
      'Id': instance.Id,
      'Name': instance.Name,
      'NIF__c': instance.NIF__c,
      'Fase__c': instance.Fase__c,
      'CreatedDate': instance.CreatedDate,
    };
