import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/salesforce/presentation/providers/salesforce_providers.dart';
import '../../../features/salesforce/domain/models/dashboard_stats.dart';
import '../../../features/opportunity/presentation/providers/opportunity_providers.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/logo.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/simple_list_item.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _selectedPeriod = 'month'; // 'month' or 'all'
  bool _showProposalsList = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    // Watch both providers
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: dashboardStatsAsync.isLoading
          ? null // No AppBar when loading
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(CupertinoIcons.chevron_back, color: theme.colorScheme.onSurface),
                onPressed: () => context.pop(),
                tooltip: '',
              ),
              title: LogoWidget(height: 60, darkMode: theme.brightness == Brightness.dark),
              centerTitle: true,
            ),
      body: dashboardStatsAsync.when(
        data: (stats) => opportunitiesAsync.when(
          data: (opportunities) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Dashboard',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Expanded(
                    child: _buildDashboardContent(context, stats, opportunities),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Center(child: AppLoadingIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Erro ao carregar oportunidades: ${error.toString()}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ),
        ),
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Ocorreu um erro ao carregar o dashboard: \n${error.toString()}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardStats stats, List<SalesforceOpportunity> opportunities) {
    final theme = Theme.of(context);
    final proposalsWithCommission = stats.proposals.where((p) => p.commission > 0).toList();
    
    // Calculate status counts
    final statusCounts = _calculateStatusCounts(opportunities);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // --- Centered Stats Display ---
          Row(
            children: [
              Expanded(
                child: _buildCenteredStat(
                  context,
                  label: 'Comissões',
                  value: '€ ${stats.totalCommission.toStringAsFixed(2)}',
                  icon: Icons.euro,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: _buildCenteredStat(
                  context,
                  label: 'Oportunidades',
                  value: stats.totalOpportunities.toString(),
                  icon: CupertinoIcons.group_solid,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          // --- Status Breakdown Section ---
          Text(
            'Estado dos Clientes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusGrid(context, statusCounts),
          const SizedBox(height: 40),
          
          // --- Commissions Section ---
          Text(
            'Comissões',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // --- Commission List ---
          if (proposalsWithCommission.isNotEmpty)
            ...proposalsWithCommission.map((proposal) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 0),
                child: SimpleListItem(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.euro,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  title: proposal.opportunityName,
                  subtitle: '€ ${proposal.commission.toStringAsFixed(2)}',
                  onTap: () {
                    // Optional: Add navigation to proposal details
                  },
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Sem propostas com comissão.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCenteredStat(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          size: 48,
          color: color,
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Status filtering logic from reseller_opportunity_page.dart
  String _getProposalStatusForFilter(SalesforceOpportunity opportunity) {
    if (opportunity.propostasR?.records != null &&
        opportunity.propostasR!.records.isNotEmpty) {
      return opportunity.propostasR!.records.first.statusC ?? '';
    }
    return '';
  }

  Map<String, int> _calculateStatusCounts(List<SalesforceOpportunity> opportunities) {
    int active = 0;
    int actionNeeded = 0;
    int pending = 0;
    int rejected = 0;

    for (final opportunity in opportunities) {
      final proposalStatus = _getProposalStatusForFilter(opportunity);
      
      if (proposalStatus == 'Aceite') {
        active++;
      } else if (['Enviada', 'Em Aprovação'].contains(proposalStatus)) {
        actionNeeded++;
      } else if (['Aprovada', 'Expirada', 'Criação', 'Em Análise'].contains(proposalStatus)) {
        pending++;
      } else if (['Não Aprovada', 'Cancelada'].contains(proposalStatus)) {
        rejected++;
      }
    }

    return {
      'active': active,
      'actionNeeded': actionNeeded,
      'pending': pending,
      'rejected': rejected,
    };
  }

  Widget _buildStatusGrid(BuildContext context, Map<String, int> statusCounts) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            context,
            label: 'Ativos',
            count: statusCounts['active']!,
            icon: CupertinoIcons.checkmark_seal_fill,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            context,
            label: 'Ação Necessária',
            count: statusCounts['actionNeeded']!,
            icon: CupertinoIcons.exclamationmark_circle_fill,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            context,
            label: 'Pendentes',
            count: statusCounts['pending']!,
            icon: CupertinoIcons.clock_fill,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            context,
            label: 'Rejeitados',
            count: statusCounts['rejected']!,
            icon: CupertinoIcons.xmark_seal_fill,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, {
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  static Widget noScrollbars(BuildContext context, Widget child) {
    return ScrollConfiguration(
      behavior: const NoScrollbarBehavior(),
      child: child,
    );
  }
}
