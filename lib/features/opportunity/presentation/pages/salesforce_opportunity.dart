import 'package:freezed_annotation/freezed_annotation.dart';

part 'salesforce_opportunity.freezed.dart';
part 'salesforce_opportunity.g.dart';

// Define the structure mirroring the TypeScript interface in the Cloud Function
@freezed
class SalesforceOpportunity with _$SalesforceOpportunity {
  const factory SalesforceOpportunity({
    required String Id,
    required String Name,
    String? NIF__c,
    String? Fase__c,
    required String CreatedDate,
    // Add other fields from SOQL if needed
  }) = _SalesforceOpportunity;

  factory SalesforceOpportunity.fromJson(Map<String, dynamic> json) =>
      _$SalesforceOpportunityFromJson(json);
}
