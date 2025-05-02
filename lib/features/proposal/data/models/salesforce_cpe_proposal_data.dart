import 'package:flutter/foundation.dart';

/// Represents the data for a CPE_Proposta__c record fetched for resellers.
@immutable
class SalesforceCPEProposalData {
  final String id;
  final double? consumptionOrPower; // Consumo_ou_Potencia_Pico__c
  final double?
  loyaltyYears; // Fidelizacao_Anos__c (assuming years can be decimal? adjust if int)
  final double? commissionRetail; // Comissao_Retail__c

  const SalesforceCPEProposalData({
    required this.id,
    this.consumptionOrPower,
    this.loyaltyYears,
    this.commissionRetail,
  });

  factory SalesforceCPEProposalData.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numbers (double or int)
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return SalesforceCPEProposalData(
      id: json['Id'] as String? ?? 'Unknown ID',
      consumptionOrPower: parseDouble(json['Consumo_ou_Pot_ncia_Pico__c']),
      loyaltyYears: parseDouble(json['Fideliza_o_Anos__c']),
      commissionRetail: parseDouble(json['Comiss_o_Retail__c']),
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
          commissionRetail == other.commissionRetail;

  @override
  int get hashCode =>
      id.hashCode ^
      consumptionOrPower.hashCode ^
      loyaltyYears.hashCode ^
      commissionRetail.hashCode;

  @override
  String toString() {
    return 'SalesforceCPEProposalData{id: $id, consumptionOrPower: $consumptionOrPower, loyaltyYears: $loyaltyYears, commissionRetail: $commissionRetail}';
  }
}
