import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'dart:math'; // Import dart:math
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:intl/intl.dart'; // Import intl
import 'package:flutter/cupertino.dart'; // Import Cupertino Icons

import '../../../../core/models/enums.dart'; // Corrected path again

// Mock Data Structures
class MockResellerStat {
  final String name;
  final double value;
  MockResellerStat({required this.name, required this.value});
}

class MockMetric {
  final String title;
  final String value;
  final IconData icon;
  MockMetric({required this.title, required this.value, required this.icon});
}

class AdminStatsDetailPage extends ConsumerStatefulWidget {
  final TimeFilter timeFilter;

  const AdminStatsDetailPage({super.key, required this.timeFilter});

  @override
  ConsumerState<AdminStatsDetailPage> createState() =>
      _AdminStatsDetailPageState();
}

class _AdminStatsDetailPageState extends ConsumerState<AdminStatsDetailPage> {
  // State for Reseller filter (mock)
  String? _selectedReseller = 'All Resellers'; // Default value
  // Make final as per linter
  final List<String> _mockResellers = [
    'All Resellers',
    'Reseller Alpha',
    'Reseller Beta',
    'Reseller Gamma',
  ];

  // Mock Data Generation
  late List<MockResellerStat> _mockResellerData;
  late List<MockMetric> _mockKeyMetrics;
  late double _mockTotalSubmissions;
  late double _mockTotalRevenue;

  @override
  void initState() {
    super.initState();
    _generateMockData();
  }

  @override
  void didUpdateWidget(covariant AdminStatsDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Regenerate mock data if the time filter changes
    if (widget.timeFilter != oldWidget.timeFilter) {
      _generateMockData();
    }
  }

  void _generateMockData() {
    final random = Random();
    int days = 30;
    if (widget.timeFilter == TimeFilter.weekly) days = 7;
    if (widget.timeFilter == TimeFilter.cycle) days = 90;

    // Mock totals
    _mockTotalSubmissions = (random.nextDouble() * 300 + 50 * days).clamp(
      0,
      50 * days * 1.1,
    );
    _mockTotalRevenue = (random.nextDouble() * 30000 + 500 * days).clamp(
      0,
      5000 * days * 1.1,
    );

    // Mock reseller data
    _mockResellerData = List.generate(5, (index) {
      double value =
          random.nextDouble() *
          (_mockTotalSubmissions / 3); // Example contribution
      return MockResellerStat(
        name: 'Reseller ${String.fromCharCode(65 + index)}',
        value: value,
      );
    });
    _mockResellerData.sort(
      (a, b) => b.value.compareTo(a.value),
    ); // Sort descending

    // Mock key metrics
    _mockKeyMetrics = [
      MockMetric(
        title: 'Avg. Sub Value',
        value: NumberFormat.compactSimpleCurrency().format(
          _mockTotalRevenue / max(1, _mockTotalSubmissions),
        ),
        icon: CupertinoIcons.money_dollar_circle,
      ),
      MockMetric(
        title: 'Accept Rate',
        value: '${(random.nextDouble() * 15 + 80).toStringAsFixed(1)}%',
        icon: CupertinoIcons.check_mark_circled,
      ),
      MockMetric(
        title: 'Avg. Time to Accept',
        value: '${(random.nextDouble() * 3 + 1).toStringAsFixed(1)} days',
        icon: CupertinoIcons.timer,
      ),
      MockMetric(
        title: 'New Clients',
        value: '${random.nextInt(15) + 5}',
        icon: CupertinoIcons.person_add,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context)!; // REMOVE: Unused variable
    final theme = Theme.of(context);

    final String chartTitle = 'Statistics'; // New general title

    String filterTitle = ''; // Initialize
    switch (widget.timeFilter) {
      case TimeFilter.weekly:
        filterTitle = 'Weekly'; // TODO: Use l10n
        break;
      case TimeFilter.monthly:
        filterTitle = 'Monthly'; // TODO: Use l10n
        break;
      case TimeFilter.cycle:
        filterTitle = 'Cycle'; // TODO: Use l10n
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$chartTitle Details ($filterTitle)'), // Update title
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        iconTheme: theme.iconTheme, // Ensures back button uses theme color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Summary Stats ---
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    title: 'Total Submissions', // TODO: l10n
                    value: _mockTotalSubmissions.toStringAsFixed(0),
                    icon: CupertinoIcons.doc_chart,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    title: 'Total Revenue', // TODO: l10n
                    value: NumberFormat.compactSimpleCurrency(
                      decimalDigits: 0,
                    ).format(_mockTotalRevenue),
                    icon: CupertinoIcons.money_dollar,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Chart Area ---
            Text(
              'Trends', // TODO: l10n
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
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
                                      widget.timeFilter,
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
                                      widget.timeFilter,
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
                          AspectRatio(
                            aspectRatio: 1.8,
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
                                    widget.timeFilter,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AspectRatio(
                            aspectRatio: 1.8,
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
                                    widget.timeFilter,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Divider(thickness: 1, color: theme.dividerColor.withAlpha((255 * 0.5).round())),
            const SizedBox(height: 16),

            // --- Reseller Breakdown ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reseller Breakdown',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Mock Filter Dropdown
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedReseller,
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    style: theme.textTheme.bodySmall,
                    dropdownColor: theme.colorScheme.surfaceVariant,
                    items:
                        _mockResellers.map((String reseller) {
                          return DropdownMenuItem<String>(
                            value: reseller,
                            child: Text(reseller),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedReseller = newValue;
                        // TODO: Add logic to actually filter _mockResellerData if needed
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResellerList(context),
            const SizedBox(height: 24),

            // --- Key Metrics ---
            Text(
              'Key Metrics',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildKeyMetricsGrid(context),
          ],
        ),
      ),
    );
  }

  // --- New Widgets for Sections ---

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  icon,
                  size: 20,
                  color: color.withAlpha((255 * 0.8).round()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResellerList(BuildContext context) {
    final theme = Theme.of(context);
    // final currencyFormatter = NumberFormat.compactSimpleCurrency(decimalDigits: 0); // REMOVE: Unused variable

    // Show message if filtered and no data (example)
    final filteredData =
        (_selectedReseller == 'All Resellers')
            ? _mockResellerData
            : _mockResellerData
                .where((r) => r.name == _selectedReseller)
                .toList();

    if (filteredData.isEmpty && _selectedReseller != 'All Resellers') {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(
            (0.5 * 255).round(),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No data for $_selectedReseller',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredData.length,
      separatorBuilder:
          (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: theme.dividerColor.withAlpha((0.3 * 255).round()),
          ),
      itemBuilder: (context, index) {
        final item = filteredData[index];
        // Decide if showing submissions or revenue based on some logic (defaulting to submissions here)
        final displayValue = item.value.toStringAsFixed(0);
        // final displayValue = currencyFormatter.format(item.value); // if showing revenue

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4.0,
            horizontal: 8.0,
          ),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              item.name.substring(0, 1), // Initial
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(item.name, style: theme.textTheme.bodyMedium),
          trailing: Text(
            displayValue,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyMetricsGrid(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kIsWeb ? 4 : 2, // Responsive columns
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: kIsWeb ? 1.8 : 1.5, // Adjust aspect ratio
      ),
      itemCount: _mockKeyMetrics.length,
      itemBuilder: (context, index) {
        final metric = _mockKeyMetrics[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        metric.title,
                        style: theme.textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      metric.icon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                // const SizedBox(height: 8),
                Text(
                  metric.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Copied Chart Building Logic ---

  Widget _buildSubmissionsChart(BuildContext context, TimeFilter filter) {
    final theme = Theme.of(context);
    int days = 30;
    if (filter == TimeFilter.weekly) days = 7;
    if (filter == TimeFilter.cycle) days = 90;
    final spots = _generatePlaceholderSpots(days, 50);
    double maxX = (spots.isNotEmpty ? spots.length - 1 : 0).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: 60,
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
              color: theme.colorScheme.primary.withAlpha((255 * 0.2).round()),
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
    if (filter == TimeFilter.weekly) days = 7;
    if (filter == TimeFilter.cycle) days = 90;
    final spots = _generatePlaceholderSpots(days, 5000, isDouble: true);
    double maxX = (spots.isNotEmpty ? spots.length - 1 : 0).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: 6000,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green, // Keep consistent color
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withAlpha((255 * 0.2).round()),
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
    if (count <= 0) return [];
    final random = Random();
    return List.generate(count, (index) {
      double yValue =
          isDouble
              ? random.nextDouble() * maxVal
              : random.nextInt(maxVal.toInt()).toDouble();
      yValue = yValue * (1 + (index / (count * 2)));
      yValue = yValue.clamp(0, maxVal * 1.2);
      return FlSpot(index.toDouble(), yValue);
    });
  }
}
