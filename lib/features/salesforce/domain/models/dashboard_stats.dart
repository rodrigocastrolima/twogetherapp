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
    return DashboardStats(
      totalCommission: (json['totalCommission'] as num).toDouble(),
      totalOpportunities: json['totalOpportunities'] as int,
      proposals: (json['proposals'] as List<dynamic>)
          .map((p) => ProposalCommission.fromJson(p as Map<String, dynamic>))
          .toList(),
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
      proposalId: json['proposalId'] as String,
      opportunityName: json['opportunityName'] as String,
      commission: (json['commission'] as num).toDouble(),
    );
  }
} 