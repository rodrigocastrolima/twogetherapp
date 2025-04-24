import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/ui_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Dashboard',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_back,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Period Selector - More compact and higher up
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
                    _buildEarningsCard(context),
                    const SizedBox(height: 24),
                    _buildEarningsGraph(context),
                    const SizedBox(height: 24),
                    _buildStatsGrid(context),
                    const SizedBox(height: 24),
                    _buildProcessesSection(context),
                    const SizedBox(height: 24),
                    _buildSubmissionsSection(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildEarningsCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    final cardBgColor =
        isDark ? primaryColor.withAlpha(50) : primaryColor.withAlpha(38);
    final cardBorderColor =
        isDark ? primaryColor.withAlpha(60) : primaryColor.withAlpha(50);
    final textColor = isDark ? onPrimaryColor : primaryColor;

    final bool isCurrentCycle = _selectedPeriod == 'month';

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
                isCurrentCycle ? '€ 5.280,00' : '€ 42.150,00',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (isCurrentCycle) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_up_right,
                      size: 16,
                      color: textColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+22% em relação ao ciclo anterior',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
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
          value: '32',
          label: 'Clientes Ativos',
          iconColor: iconColorActive,
          iconBgColor: iconBgActive,
          cardBgColor: cardBgColor,
          cardBorderColor: cardBorderColor,
          textColor: foregroundColor,
          labelColor: mutedForeground,
        ),
        _buildStatCard(
          context,
          icon: CupertinoIcons.doc_chart_fill,
          value: '28',
          label: 'Submissões',
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

  Widget _buildEarningsGraph(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final cardBgColor = isDark ? AppTheme.darkSecondary : AppTheme.secondary;
    final cardBorderColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final foregroundColor = theme.colorScheme.onSurface;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: AppStyles.standardBlur,
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evolução de Comissões',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots:
                            _selectedPeriod == 'month'
                                ? [
                                  const FlSpot(0, 1500),
                                  const FlSpot(1, 2300),
                                  const FlSpot(2, 1800),
                                  const FlSpot(3, 3200),
                                  const FlSpot(4, 2800),
                                  const FlSpot(5, 5280),
                                ]
                                : [
                                  const FlSpot(0, 15000),
                                  const FlSpot(1, 23000),
                                  const FlSpot(2, 18000),
                                  const FlSpot(3, 32000),
                                  const FlSpot(4, 28000),
                                  const FlSpot(5, 42150),
                                ],
                        isCurved: true,
                        color: primaryColor,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: primaryColor.withAlpha(isDark ? 30 : 25),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        tooltipMargin: 8,
                        getTooltipColor: (LineBarSpot spot) {
                          return theme.colorScheme.primaryContainer.withOpacity(
                            0.9,
                          );
                        },
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final textStyle = TextStyle(
                              color:
                                  isDark
                                      ? AppTheme.darkForeground
                                      : AppTheme.foreground,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            );
                            return LineTooltipItem(
                              '€${barSpot.y.toStringAsFixed(0)}',
                              textStyle,
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildProcessesSection(BuildContext context) {
    // Placeholder for processes section
    return _buildSectionHeader(context, 'Processos Pendentes');
    // TODO: Add list of pending processes similar to submissions
  }

  Widget _buildSubmissionsSection(BuildContext context) {
    // TODO: Replace with actual data fetching
    final recentSubmissions = [
      {
        'title': 'New Submission', // Example title
        'subtitle': 'Cristina Chirita / abc',
        'trailing': '4/22/2025 2:40 AM',
        'isUnread': true,
      },
      {
        'title': 'Submission Updated',
        'subtitle': 'João Silva / xyz',
        'trailing': '4/21/2025 11:15 PM',
        'isUnread': false,
      },
      // Add more dummy data if needed
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Submissões Recentes'),
        ListView.builder(
          itemCount: recentSubmissions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = recentSubmissions[index];
            // Call _buildSubmissionItem with data from the map
            return _buildSubmissionItem(
              context,
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              trailing: item['trailing'] as String,
              isUnread: item['isUnread'] as bool,
              // Removed icon/color parameters, will be handled internally
            );
          },
        ),
      ],
    );
  }

  // Updated to align styling with notification items
  Widget _buildSubmissionItem(
    BuildContext context, {
    // Removed icon, iconColor, iconBgColor parameters
    required String title,
    required String subtitle,
    required String trailing,
    required bool isUnread,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark =
        theme.brightness == Brightness.dark; // Keep for potential future use

    // --- Styling derived internally (assuming 'new submission' type for now) ---
    final IconData icon = Icons.description_outlined; // Standardized icon
    final Color iconColor = colorScheme.primary;
    final Color iconContainerColor = colorScheme.primaryContainer;
    final Color titleColor = colorScheme.onSurface;
    final Color subtitleColor = colorScheme.onSurfaceVariant;
    final Color trailingColor = colorScheme.onSurfaceVariant;
    final Color unreadIndicatorColor = colorScheme.primary;
    // --------------------------------------------------------------------------

    // Keep using ClipRRect for potential blur/border effects if needed
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 12,
        ), // Add margin like notifications
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: colorScheme.surface, // Use surface color like notifications
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            // Add subtle shadow like notifications
            BoxShadow(
              color:
                  isDark
                      ? colorScheme.shadow.withOpacity(0.2)
                      : colorScheme.shadow.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            // Add border like notifications (for dark mode)
            color:
                isDark
                    ? colorScheme.onSurface.withOpacity(0.05)
                    : Colors.transparent,
            width: isDark ? 1 : 0,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40, // Match notification icon size
              height: 40,
              decoration: BoxDecoration(
                color: iconContainerColor, // Use derived container color
                borderRadius: BorderRadius.circular(
                  8,
                ), // Match notification radius
                // Removed shape: BoxShape.circle
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ), // Use derived icon/color
            ),
            const SizedBox(width: 16), // Match notification spacing
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      // Use titleSmall
                      fontWeight: FontWeight.w600, // Keep bold title
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4), // Match notification spacing
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      // Use bodyMedium
                      color: subtitleColor,
                    ),
                    maxLines: 1, // Add overflow handling
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // Add spacing before trailing
            // Trailing & Unread
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center, // Align vertically
              children: [
                Text(
                  trailing,
                  style: textTheme.labelSmall?.copyWith(
                    // Use labelSmall
                    color: trailingColor,
                  ),
                ),
                const SizedBox(height: 4),
                // Ensure unread indicator container is sized even if empty
                Container(
                  width: 8,
                  height: 8,
                  child:
                      isUnread
                          ? Container(
                            decoration: BoxDecoration(
                              color: unreadIndicatorColor,
                              shape: BoxShape.circle,
                            ),
                          )
                          : null, // Render nothing if read
                ),
              ],
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
