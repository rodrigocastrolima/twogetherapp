// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'salesforce_opportunity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SalesforceOpportunityImpl _$$SalesforceOpportunityImplFromJson(
  Map<String, dynamic> json,
) => _$SalesforceOpportunityImpl(
  Id: json['Id'] as String,
  Name: json['Name'] as String,
  AccountId: json['AccountId'] as String?,
  Account:
      json['Account'] == null
          ? null
          : AccountInfo.fromJson(json['Account'] as Map<String, dynamic>),
  Fase__c: json['Fase__c'] as String?,
  Solu_o__c: json['Solu_o__c'] as String?,
  Data_de_Previs_o_de_Fecho__c: json['Data_de_Previs_o_de_Fecho__c'] as String?,
  CreatedDate: json['CreatedDate'] as String,
);

Map<String, dynamic> _$$SalesforceOpportunityImplToJson(
  _$SalesforceOpportunityImpl instance,
) => <String, dynamic>{
  'Id': instance.Id,
  'Name': instance.Name,
  'AccountId': instance.AccountId,
  'Account': instance.Account,
  'Fase__c': instance.Fase__c,
  'Solu_o__c': instance.Solu_o__c,
  'Data_de_Previs_o_de_Fecho__c': instance.Data_de_Previs_o_de_Fecho__c,
  'CreatedDate': instance.CreatedDate,
};

_$AccountInfoImpl _$$AccountInfoImplFromJson(Map<String, dynamic> json) =>
    _$AccountInfoImpl(Name: json['Name'] as String?);

Map<String, dynamic> _$$AccountInfoImplToJson(_$AccountInfoImpl instance) =>
    <String, dynamic>{'Name': instance.Name};
