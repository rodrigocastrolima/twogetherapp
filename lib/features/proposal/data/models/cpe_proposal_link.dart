import 'package:flutter/foundation.dart';

@immutable
class CpeProposalLink {
  final String id; // Salesforce ID of CPE_Proposta__c
  final String? name; // CPE-Proposta__c Name (the junction object's name)
  final String? cpeName; // Name of the related CPE__c (CPE_Proposta__r.Name)
  final String? cpeRecordId; // ID of the related CPE__c (CPE_Proposta__r.Id)

  const CpeProposalLink({
    required this.id,
    this.name,
    this.cpeName, // Allow null
    this.cpeRecordId, // Allow null
  });

  factory CpeProposalLink.fromJson(Map<String, dynamic> json) {
    final relatedCpe = json['CPE_Proposta__r'] as Map<String, dynamic>?;
    return CpeProposalLink(
      id: json['Id'] as String? ?? '', // CPE_Proposta__c ID
      name: json['Name'] as String?, // CPE-Proposta__c Name
      cpeName: relatedCpe?['Name'] as String?,
      cpeRecordId: relatedCpe?['Id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cpeName': cpeName,
      'cpeRecordId': cpeRecordId,
    };
  }

  CpeProposalLink copyWith({String? id, String? name, String? cpeName, String? cpeRecordId}) {
    // TODO: Implement copyWith logic
    throw UnimplementedError('copyWith has not been implemented.');
  }

  @override
  bool operator ==(Object other) {
    // TODO: Implement equality comparison
    throw UnimplementedError('operator == has not been implemented.');
  }

  @override
  int get hashCode {
    // TODO: Implement hashCode
    throw UnimplementedError('hashCode has not been implemented.');
  }

  @override
  String toString() {
    // TODO: Implement toString for debugging
    return 'CpeProposalLink(id: $id, name: $name, cpeName: $cpeName, cpeRecordId: $cpeRecordId)';
  }
}
