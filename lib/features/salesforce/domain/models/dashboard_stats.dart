class DashboardStats {
  final double totalCommission;
  final int totalOpportunities;
  final List<ProposalCommission> proposals;

  DashboardStats({
    required this.totalCommission,
    required this.totalOpportunities,
    required this.proposals,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    List<dynamic> proposalsJson = json['proposals'] as List<dynamic>? ?? [];
    List<ProposalCommission> parsedProposals = proposalsJson
        .map((p) => ProposalCommission.fromJson(p as Map<String, dynamic>))
        .toList();

    double calculatedTotalCommission = parsedProposals.fold(
      0.0,
      (sum, item) => sum + item.commission,
    );

    return DashboardStats(
      totalCommission: calculatedTotalCommission,
      totalOpportunities: json['opportunityCount'] as int? ?? 0,
      proposals: parsedProposals,
    );
  }
}

class ProposalCommission {
  final String proposalId;
  final String opportunityName;
  final double commission;

  ProposalCommission({
    required this.proposalId,
    required this.opportunityName,
    required this.commission,
  });

  factory ProposalCommission.fromJson(Map<String, dynamic> json) {
    return ProposalCommission(
      proposalId: json['id'] as String? ?? '',
      opportunityName: json['opportunityName'] as String? ?? '',
      commission: (json['totalCommission'] as num? ?? 0).toDouble(),
    );
  }
} 