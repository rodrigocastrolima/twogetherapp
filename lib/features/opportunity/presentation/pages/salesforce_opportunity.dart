import 'package:freezed_annotation/freezed_annotation.dart';

part 'salesforce_opportunity.freezed.dart';
part 'salesforce_opportunity.g.dart';

// Define the structure mirroring the TypeScript interface in the Cloud Function
@freezed
class SalesforceOpportunity with _$SalesforceOpportunity {
  const factory SalesforceOpportunity({
    required String Id,
    required String Name,
    String? AccountId,
    AccountInfo? Account, // Nested object for Account details
    String? Fase__c,
    String? Solu_o__c,
    String? Data_de_Previs_o_de_Fecho__c, // Salesforce date (YYYY-MM-DD)
    required String CreatedDate, // Salesforce dateTime (ISO 8601)
    // Add other fields from SOQL if needed
  }) = _SalesforceOpportunity;

  factory SalesforceOpportunity.fromJson(Map<String, dynamic> json) =>
      _$SalesforceOpportunityFromJson(json);
}

// Define the nested Account structure
@freezed
class AccountInfo with _$AccountInfo {
  const factory AccountInfo({
    String? Name,
    // Add other Account fields if queried
  }) = _AccountInfo;

  factory AccountInfo.fromJson(Map<String, dynamic> json) =>
      _$AccountInfoFromJson(json);
}
