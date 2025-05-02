import 'package:flutter/foundation.dart';

/// Represents the data for a CPE_Proposta__c record fetched for resellers.
@immutable
class SalesforceCPEProposalData {
  final String id;
  final double? consumptionOrPower; // Consumo_ou_Potencia_Pico__c
  final double?
  loyaltyYears; // Fidelizacao_Anos__c (assuming years can be decimal? adjust if int)
  final double? commissionRetail; // Comissao_Retail__c
  final List<SalesforceFileInfo> attachedFiles;

  const SalesforceCPEProposalData({
    required this.id,
    this.consumptionOrPower,
    this.loyaltyYears,
    this.commissionRetail,
    this.attachedFiles = const [],
  });

  factory SalesforceCPEProposalData.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numbers (double or int)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value.replaceFirst(',', '.'));
      return null;
    }

    // Parse attached files
    List<SalesforceFileInfo> files = [];
    if (json['attachedFiles'] is List) {
      final fileList = json['attachedFiles'] as List<dynamic>;
      files =
          fileList
              .map((fileJson) {
                // --- ADDED: Defensive check and cast for each file map --- //
                if (fileJson is Map) {
                  try {
                    final Map<String, dynamic> typedFileMap =
                        Map<String, dynamic>.from(fileJson);
                    return SalesforceFileInfo.fromJson(typedFileMap);
                  } catch (e) {
                    print(
                      'Error parsing attached file item: $e - Item: $fileJson',
                    );
                    return null;
                  }
                } else {
                  print(
                    'Skipping non-map item in attachedFiles: ${fileJson?.runtimeType}',
                  );
                  return null;
                }
                // --- END ADDED --- //
              })
              .whereType<SalesforceFileInfo>()
              .toList();
    }

    return SalesforceCPEProposalData(
      id: json['Id'] as String? ?? 'Unknown ID',
      consumptionOrPower: parseDouble(json['Consumo_ou_Pot_ncia_Pico__c']),
      loyaltyYears: parseDouble(json['Fideliza_o_Anos__c']),
      commissionRetail: parseDouble(json['Comiss_o_Retail__c']),
      attachedFiles: files,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceCPEProposalData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          consumptionOrPower == other.consumptionOrPower &&
          loyaltyYears == other.loyaltyYears &&
          commissionRetail == other.commissionRetail &&
          listEquals(attachedFiles, other.attachedFiles);

  @override
  int get hashCode =>
      id.hashCode ^
      consumptionOrPower.hashCode ^
      loyaltyYears.hashCode ^
      commissionRetail.hashCode ^
      Object.hashAll(attachedFiles);

  @override
  String toString() {
    return 'SalesforceCPEProposalData{id: $id, consumptionOrPower: $consumptionOrPower, loyaltyYears: $loyaltyYears, commissionRetail: $commissionRetail, attachedFiles: ${attachedFiles.length}}';
  }
}

/// Represents the data for a Salesforce File Info record.
@immutable
class SalesforceFileInfo {
  final String id; // ContentVersion ID
  final String title; // File name

  const SalesforceFileInfo({required this.id, required this.title});

  factory SalesforceFileInfo.fromJson(Map<String, dynamic> json) {
    return SalesforceFileInfo(
      id: json['id'] as String? ?? 'Unknown ID',
      title: json['title'] as String? ?? 'Unknown Title',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesforceFileInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;

  @override
  String toString() {
    return 'SalesforceFileInfo{id: $id, title: $title}';
  }
}
