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

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _selectedPeriod = 'month'; // 'month' or 'all'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final salesforceId = user?.uid; // Using UID as salesforceId for now

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
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
      body: salesforceId == null
          ? const Center(child: Text('No user ID found'))
          : Consumer(
              builder: (context, ref, child) {
                final dashboardStatsAsync = ref.watch(
                  dashboardStatsProvider(salesforceId),
                );

                return dashboardStatsAsync.when(
                  data: (stats) => _buildDashboardContent(context, stats),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Error: ${error.toString()}'),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardStats stats) {
    final theme = Theme.of(context);
    return Column(
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
          ),
        ),
        // Period Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_buildPeriodSelector(context)],
          ),
        ),
        // Main Content
        Expanded(
          child: NoScrollbarBehavior.noScrollbars(
            context,
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEarningsCard(context, stats),
                  const SizedBox(height: 24),
                  _buildStatsGrid(context, stats),
                  const SizedBox(height: 24),
                  _buildProposalsList(context, stats),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassBgColor =
        isDark ? Colors.black.withAlpha(26) : Colors.white.withAlpha(20);
    final glassBorderColor =
        isDark ? AppTheme.darkBorder.withAlpha(51) : Colors.white.withAlpha(25);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: AppStyles.standardBlur,
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: glassBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: glassBorderColor, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodOption(context, 'Ciclo', 'month'),
              Container(width: 1, height: 32, color: glassBorderColor),
              _buildPeriodOption(context, 'Total', 'all'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodOption(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final mutedForeground =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final selectionBg =
        isDark ? primaryColor.withAlpha(50) : primaryColor.withAlpha(38);
    final selectedTextColor = primaryColor;
    final unselectedTextColor = mutedForeground;

    final isSelected = _selectedPeriod == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectionBg : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsCard(BuildContext context, DashboardStats stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    final cardBgColor =
        isDark ? primaryColor.withAlpha(50) : primaryColor.withAlpha(38);
    final cardBorderColor =
        isDark ? primaryColor.withAlpha(60) : primaryColor.withAlpha(50);
    final textColor = isDark ? onPrimaryColor : primaryColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: AppStyles.standardBlur,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comissões',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '€ ${stats.totalCommission.toStringAsFixed(2)}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, DashboardStats stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foregroundColor = theme.colorScheme.onSurface;
    final mutedForeground =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;
    final cardBgColor = isDark ? AppTheme.darkSecondary : AppTheme.secondary;
    final cardBorderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final iconColorActive = isDark ? AppTheme.darkSuccess : AppTheme.success;
    final iconColorSubmissions =
        isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final iconBgActive =
        isDark ? iconColorActive.withAlpha(30) : iconColorActive.withAlpha(20);
    final iconBgSubmissions =
        isDark
            ? iconColorSubmissions.withAlpha(30)
            : iconColorSubmissions.withAlpha(20);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(
          context,
          icon: CupertinoIcons.group_solid,
          value: stats.totalOpportunities.toString(),
          label: 'Oportunidades',
          iconColor: iconColorActive,
          iconBgColor: iconBgActive,
          cardBgColor: cardBgColor,
          cardBorderColor: cardBorderColor,
          textColor: foregroundColor,
          labelColor: mutedForeground,
        ),
        _buildStatCard(
          context,
          icon: CupertinoIcons.doc_text,
          value: stats.proposals.length.toString(),
          label: 'Propostas',
          iconColor: iconColorSubmissions,
          iconBgColor: iconBgSubmissions,
          cardBgColor: cardBgColor,
          cardBorderColor: cardBorderColor,
          textColor: foregroundColor,
          labelColor: mutedForeground,
        ),
      ],
    );
  }

  Widget _buildProposalsList(BuildContext context, DashboardStats stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBgColor = isDark ? AppTheme.darkSecondary : AppTheme.secondary;
    final cardBorderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final foregroundColor = theme.colorScheme.onSurface;
    final mutedForeground =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Propostas',
          style: theme.textTheme.titleMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...stats.proposals.map((proposal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: AppStyles.standardBlur,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorderColor, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                proposal.opportunityName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Proposta #${proposal.proposalId}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: mutedForeground,
                                ),
                              ),
                            ],
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
              ),
            )),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
    required Color iconBgColor,
    required Color cardBgColor,
    required Color cardBorderColor,
    required Color textColor,
    required Color labelColor,
  }) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: AppStyles.standardBlur,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: labelColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
