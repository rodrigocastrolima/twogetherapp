import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/ui_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/salesforce/presentation/providers/salesforce_providers.dart';
import '../../../features/salesforce/domain/models/dashboard_stats.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/logo.dart';
import '../../widgets/app_loading_indicator.dart';

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
    // final salesforceId = user?.uid; // salesforceId is fetched by the provider now

    // Watch the provider at a higher level
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
        data: (stats) => Center(
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
                  child: _buildDashboardContent(context, stats),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: AppLoadingIndicator()), // Full screen loader
        error: (error, stack) => Center(
          // Ensure error is displayed within the page structure if AppBar is present
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

  Widget _buildDashboardContent(BuildContext context, DashboardStats stats) {
    final theme = Theme.of(context);
    final proposalsWithCommission = stats.proposals.where((p) => p.commission > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Stat Cards Row ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildMaterialStatCard(
                context,
                label: 'Comissões',
                value: stats.totalCommission.toStringAsFixed(2),
                icon: Icons.euro,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              _buildMaterialStatCard(
                context,
                label: 'Oportunidades',
                value: stats.totalOpportunities.toString(),
                icon: CupertinoIcons.group_solid,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Comissões',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...proposalsWithCommission.map((proposal) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(14),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            proposal.opportunityName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '€ ${proposal.commission.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
              if (proposalsWithCommission.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Sem propostas com comissão.', style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialStatCard(BuildContext context, {required String label, required String value, required IconData icon, required Color color, bool isClickable = false}) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  label == 'Comissões' ? '€ $value' : value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
