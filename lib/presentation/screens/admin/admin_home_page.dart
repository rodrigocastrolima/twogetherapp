import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import '../../../core/models/enums.dart';
import '../../../presentation/widgets/logo.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../features/notifications/presentation/providers/notification_provider.dart';
import '../../../core/models/notification.dart';
import '../../../features/services/data/repositories/service_submission_repository.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  // State for the time filter
  TimeFilter _selectedTimeFilter = TimeFilter.monthly; // Default to monthly
  // State for chart type (default to submissions)
  ChartType _selectedChartType = ChartType.submissions;

  @override
  void initState() {
    super.initState();

    // Set up callback to refresh notifications when a new one is created
    ServiceSubmissionRepository.onNotificationCreated = () {
      if (kDebugMode) {
        print('AdminHomePage: Notification creation callback triggered');
      }

      // Run this in the next frame to ensure it happens after build
      Future.microtask(() {
        if (mounted) {
          refreshAdminNotifications(ref);
        }
      });
    };
  }

  @override
  void dispose() {
    // Clean up callback
    ServiceSubmissionRepository.onNotificationCreated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final timeFormatter = DateFormat.jm().format(now);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome/Time Section
            _buildWelcomeSection(context, timeFormatter),
            const SizedBox(height: 24),

            // --- Updated Statistics Section ---
            _buildStatisticsSection(context),
            const SizedBox(height: 24),

            // --- Recent Activity Section ---
            _buildSubmissionsNotificationSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, String time) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context) {
    final theme = Theme.of(context);

    // Navigation action for the icon button
    void navigateToDetails() {
      print('Navigating to Statistics Detail - Filter: $_selectedTimeFilter');
      context.push(
        '/admin/stats-detail',
        extra: {
          // Only pass timeFilter now
          'timeFilter': _selectedTimeFilter,
        },
      );
    }

    // Build the single card section
    return Column(
      // Main column for the whole section
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header Row: Title, Filter (Moved outside card) ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Statistics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<TimeFilter>(
                      value: _selectedTimeFilter,
                      icon: Icon(
                        CupertinoIcons.chevron_down,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      elevation: 2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      dropdownColor: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      items:
                          TimeFilter.values.map((TimeFilter filter) {
                            String text;
                            switch (filter) {
                              case TimeFilter.weekly:
                                text = 'Weekly'; // TODO: l10n
                                break;
                              case TimeFilter.monthly:
                                text = 'Monthly'; // TODO: l10n
                                break;
                              case TimeFilter.cycle:
                                text = 'Cycle'; // TODO: l10n
                                break;
                            }
                            return DropdownMenuItem<TimeFilter>(
                              value: filter,
                              child: Text(text),
                            );
                          }).toList(),
                      onChanged: (TimeFilter? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedTimeFilter = newValue;
                            // TODO: Trigger data refresh for charts
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Card containing charts and expand icon ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Card(
            elevation: 2,
            shadowColor: theme.shadowColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expand icon aligned to top right
                  Align(
                    alignment: Alignment.topRight,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      child: Icon(
                        CupertinoIcons.arrow_up_left_arrow_down_right,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: navigateToDetails,
                    ),
                  ),
                  const SizedBox(height: 8), // Space below icon
                  // --- Chart Area: Conditional Layout ---
                  if (kIsWeb) // Web layout: Side-by-side charts
                    SizedBox(
                      height: 300, // Define height for the web chart row
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Submissions',
                                  style: theme.textTheme.titleSmall,
                                ), // TODO: l10n
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _buildSubmissionsChart(
                                    context,
                                    _selectedTimeFilter,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estimated Revenue',
                                  style: theme.textTheme.titleSmall,
                                ), // TODO: l10n
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _buildRevenueChart(
                                    context,
                                    _selectedTimeFilter,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else // Mobile layout: Stacked charts
                    Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submissions',
                              style: theme.textTheme.titleSmall,
                            ), // TODO: l10n
                            const SizedBox(height: 8),
                            AspectRatio(
                              aspectRatio: 1.8,
                              child: _buildSubmissionsChart(
                                context,
                                _selectedTimeFilter,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Revenue',
                              style: theme.textTheme.titleSmall,
                            ), // TODO: l10n
                            const SizedBox(height: 8),
                            AspectRatio(
                              aspectRatio: 1.8,
                              child: _buildRevenueChart(
                                context,
                                _selectedTimeFilter,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionsChart(BuildContext context, TimeFilter filter) {
    final theme = Theme.of(context);
    int days = 30;
    String bottomTitleInterval = 'D'; // D for Day number
    if (filter == TimeFilter.weekly) {
      days = 7;
      bottomTitleInterval = 'WD'; // WD for Week Day initial
    }
    if (filter == TimeFilter.cycle) {
      days = 90;
      bottomTitleInterval = 'W#'; // W# for Week Number
    }
    final spots = _generatePlaceholderSpots(days, 50);
    double maxX = (spots.isNotEmpty ? spots.length - 1 : 0).toDouble();
    double interval = (days / 5).ceilToDouble(); // Show ~5 labels

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
          verticalInterval: interval, // Align vertical lines with bottom titles
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget:
                  (value, meta) => _bottomTitleWidgets(
                    value,
                    meta,
                    days,
                    bottomTitleInterval,
                    theme,
                  ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10, // Adjust interval based on maxY
              getTitlesWidget:
                  (value, meta) => _leftTitleWidgets(value, meta, theme),
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: 60,
        lineTouchData: LineTouchData(
          // Add touch data
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: theme.colorScheme.secondaryContainer,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final flSpot = barSpot;
                return LineTooltipItem(
                  flSpot.y.toStringAsFixed(0), // Show integer value
                  TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  Widget _buildRevenueChart(BuildContext context, TimeFilter filter) {
    final theme = Theme.of(context);
    int days = 30;
    String bottomTitleInterval = 'D';
    if (filter == TimeFilter.weekly) {
      days = 7;
      bottomTitleInterval = 'WD';
    }
    if (filter == TimeFilter.cycle) {
      days = 90;
      bottomTitleInterval = 'W#';
    }
    final spots = _generatePlaceholderSpots(days, 5000, isDouble: true);
    double maxX = (spots.isNotEmpty ? spots.length - 1 : 0).toDouble();
    double interval = (days / 5).ceilToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1000,
          verticalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget:
                  (value, meta) => _bottomTitleWidgets(
                    value,
                    meta,
                    days,
                    bottomTitleInterval,
                    theme,
                  ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1000, // Adjust based on maxY
              getTitlesWidget:
                  (value, meta) => _leftTitleWidgets(
                    value,
                    meta,
                    theme,
                    isCurrency: true,
                  ), // Format as currency
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: 6000,
        lineTouchData: LineTouchData(
          // Add touch data
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: theme.colorScheme.secondaryContainer,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final flSpot = barSpot;
                // Format as currency for tooltip
                final currencyFormatter = NumberFormat.simpleCurrency(
                  decimalDigits: 0,
                );
                String tooltipText = currencyFormatter.format(flSpot.y);
                return LineTooltipItem(
                  tooltipText,
                  TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.2),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  List<FlSpot> _generatePlaceholderSpots(
    int count,
    double maxVal, {
    bool isDouble = false,
  }) {
    if (count <= 0) return []; // Handle zero or negative count
    final random = Random();
    return List.generate(count, (index) {
      double yValue =
          isDouble
              ? random.nextDouble() * maxVal
              : random.nextInt(maxVal.toInt()).toDouble();
      yValue = yValue * (1 + (index / (count * 2)));
      // Ensure value is not negative and clamp upper bound
      yValue = yValue.clamp(0, maxVal * 1.2);
      return FlSpot(index.toDouble(), yValue);
    });
  }

  Widget _buildSubmissionsNotificationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  return Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(4.0),
                        minSize: 0,
                        child: Icon(
                          CupertinoIcons.refresh,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(
                            0.7,
                          ),
                        ),
                        onPressed: () {
                          refreshAdminNotifications(ref);
                        },
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4.0),
                        minSize: 0,
                        child: Icon(
                          CupertinoIcons.checkmark_circle,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(
                            0.7,
                          ),
                        ),
                        onPressed: () {
                          final notificationActions = ref.read(
                            notificationActionsProvider,
                          );
                          notificationActions.markAllAsRead();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildNotificationsList(context),
      ],
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
    final notificationsStream = ref.watch(refreshableAdminSubmissionsProvider);
    final notificationActions = ref.read(notificationActionsProvider);
    final theme = Theme.of(context);

    return notificationsStream.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.bell_slash,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Recent Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: notifications.length,
          separatorBuilder:
              (context, index) => Divider(
                height: 1,
                thickness: 0.5,
                color: theme.dividerColor.withOpacity(0.5),
                indent: 16,
                endIndent: 16,
              ),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildEnhancedNotificationItem(
              context,
              notification,
              onTap: () async {
                await notificationActions.markAsRead(notification.id);
                if (notification.metadata.containsKey('submissionId')) {
                  if (context.mounted) {
                    context.push(
                      '/admin/opportunities/${notification.metadata['submissionId']}',
                    );
                  }
                }
              },
            );
          },
        );
      },
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CupertinoActivityIndicator(),
            ),
          ),
      error:
          (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load activity',
                    style: AppTextStyles.body1.copyWith(
                      color: AppTheme.foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: AppTextStyles.body2.copyWith(
                      color: AppTheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    child: Text('Try Again'),
                    onPressed: () {
                      refreshAdminNotifications(ref);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildEnhancedNotificationItem(
    BuildContext context,
    UserNotification notification, {
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat.yMd().add_jm();
    final formattedDate = dateFormatter.format(notification.createdAt);
    final resellerName = notification.metadata['resellerName'] ?? 'Unknown';
    final clientName = notification.metadata['clientName'] ?? '?';
    final isNew = !notification.isRead;

    IconData itemIcon = CupertinoIcons.doc_plaintext;
    Color iconColor = theme.colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(itemIcon, size: 20, color: iconColor),
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${resellerName} / ${clientName}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formattedDate,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isNew) const SizedBox(height: 4),
          if (isNew)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: onTap,
      dense: true,
    );
  }

  // --- Helper Functions for Chart Titles ---

  Widget _bottomTitleWidgets(
    double value,
    TitleMeta meta,
    int totalDays,
    String intervalType,
    ThemeData theme,
  ) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String text;
    int dayIndex = value.toInt();

    // Prevent labels outside the data range
    if (dayIndex < 0 || dayIndex >= totalDays) {
      return Container();
    }

    switch (intervalType) {
      case 'WD': // Weekly - Day Initials
        // Calculate the date corresponding to the index (assuming today is the last day)
        DateTime date = DateTime.now().subtract(
          Duration(days: totalDays - 1 - dayIndex),
        );
        text = DateFormat.E().format(date)[0]; // First letter of weekday
        break;
      case 'W#': // Cycle - Week Number
        int weekNumber = (dayIndex / 7).floor() + 1;
        text = 'W$weekNumber';
        break;
      case 'D': // Monthly - Day Number
      default:
        text = (dayIndex + 1).toString(); // Day 1, Day 2...
        break;
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(text, style: style),
    );
  }

  Widget _leftTitleWidgets(
    double value,
    TitleMeta meta,
    ThemeData theme, {
    bool isCurrency = false,
  }) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String text;
    if (value == meta.max || value == meta.min) {
      return Container(); // Avoid labels at min/max Y if they overlap border
    }
    if (isCurrency) {
      final currencyFormatter = NumberFormat.compactSimpleCurrency(
        decimalDigits: 0,
      );
      text = currencyFormatter.format(value);
    } else {
      text = value.toInt().toString();
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(text, style: style, textAlign: TextAlign.left),
    );
  }
}
