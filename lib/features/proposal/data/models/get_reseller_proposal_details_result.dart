import 'package:flutter/foundation.dart';
import './salesforce_cpe_proposal_data.dart';
import './salesforce_proposal_data.dart';

// --- THIS ENTIRE CLASS IS NO LONGER NEEDED ---
// The Cloud Function now returns SalesforceProposalData directly,
// which includes the nested CPE list.
/*
@immutable
class GetResellerProposalDetailsResult {
  final SalesforceProposalData proposal;
  final List<SalesforceCPEProposalData> cpePropostas;

  const GetResellerProposalDetailsResult({
    required this.proposal,
    required this.cpePropostas,
  });

  /// Creates an instance from the JSON map returned by the Cloud Function.
  /// Assumes the function returns { success: true, proposal: {...}, cpePropostas: [...] }.
  factory GetResellerProposalDetailsResult.fromJson(Map<String, dynamic> json) {
    // Explicitly cast the nested proposal map
    final proposalMap = json['proposal'] as Map?;
    final cpeListData = json['cpePropostas'] as List<dynamic>?;

    if (proposalMap == null) {
      throw const FormatException(
        "Missing or invalid 'proposal' field in GetResellerProposalDetailsResult JSON",
      );
    }
    // Ensure it's converted to the correct type before passing to nested fromJson
    final Map<String, dynamic> typedProposalMap = Map<String, dynamic>.from(
      proposalMap,
    );

    final List<SalesforceCPEProposalData> cpeList =
        (cpeListData ?? [])
            .map((item) {
              // Explicitly cast each item in the list
              if (item is Map) {
                // Check if it's a Map
                try {
                  // Convert to the correct type before passing to nested fromJson
                  final Map<String, dynamic> typedItemMap =
                      Map<String, dynamic>.from(item);
                  return SalesforceCPEProposalData.fromJson(typedItemMap);
                } catch (e) {
                  print('Error parsing CPE Proposal item: $e');
                  return null;
                }
              } else {
                return null;
              }
            })
            .whereType<SalesforceCPEProposalData>()
            .toList();

    return GetResellerProposalDetailsResult(
      // Pass the correctly typed map
      proposal: SalesforceProposalData.fromJson(typedProposalMap),
      cpePropostas: cpeList,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetResellerProposalDetailsResult &&
          runtimeType == other.runtimeType &&
          proposal == other.proposal &&
          // Use collection equality for the list
          listEquals(cpePropostas, other.cpePropostas);

  @override
  int get hashCode => proposal.hashCode ^ Object.hashAll(cpePropostas);

  @override
  String toString() {
    return 'GetResellerProposalDetailsResult{proposal: $proposal, cpePropostas count: ${cpePropostas.length}}';
  }
}
*/
