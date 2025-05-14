import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/notification.dart';
import '../../../core/models/service_submission.dart';
import '../../../features/notifications/presentation/providers/notification_provider.dart';
import '../../../core/models/enums.dart';
import '../../../features/services/data/repositories/service_submission_repository.dart';
import '../../../core/theme/ui_styles.dart'; // Import AppStyles

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  // State for the time filter
  TimeFilter _selectedTimeFilter = TimeFilter.monthly; // Default to monthly

  @override
  void initState() {
    super.initState();

    // Auto-refresh: Set up listener for notification changes
    ServiceSubmissionRepository.onNotificationCreated = () {
      if (mounted) {
        // Automatically refresh notifications when new ones arrive
        refreshAdminNotifications(ref);
      }
    };
    
    // Initial load of notifications
    Future.microtask(() {
      if (mounted) {
        refreshAdminNotifications(ref);
      }
    });
  }

  @override
  void dispose() {
    // Clean up callback
    ServiceSubmissionRepository.onNotificationCreated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final bool isDarkMode = theme.brightness == Brightness.dark;
    // final Color pageBackgroundColor = isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Use theme surface color
      // appBar: AppBar( // AppBar removed
      //   backgroundColor: pageBackgroundColor, 
      //   elevation: 0,
      //   scrolledUnderElevation: 0.0, // Ensure no color change on scroll
      //   title: null,
      //   automaticallyImplyLeading: false,
      //   actions: [
      //     _buildDropboxButton(context),
      //     const SizedBox(width: 16),
      //   ],
      // ),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const NoScrollbarBehavior(), // Custom ScrollBehavior to hide scrollbar
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(context), // Renamed and modified header
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 768) { // Desktop / Wide screen layout
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2, // Give more space to activity
                            child: _buildRecentActivitySection(context),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Column( // Column for Dropbox and future items
                              crossAxisAlignment: CrossAxisAlignment.end, // Align Dropbox to the right
                              children: [
                                _buildDropboxButton(context),
                                // Add other widgets for the right column here if needed
                              ],
                            ),
                          ),
                        ],
                      );
                    } else { // Mobile / Narrow screen layout
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDropboxButton(context), // Dropbox button at the top for mobile
                          const SizedBox(height: 16), 
                          _buildRecentActivitySection(context), // Activity below Dropbox
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) { // Renamed from _buildSubmissionsHeader
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 4.0),
      child: Text(
        'Início', // Changed title
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0, left: 4.0, right: 4.0), // Consistent padding
          child: Text(
            'Atividade Recente',
            style: theme.textTheme.titleLarge?.copyWith( // Adjusted style for subsection
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _buildNotificationsList(context),
      ],
    );
  }

  Widget _buildDropboxButton(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Adjusted padding for a page button
      color: isDarkMode 
          ? theme.colorScheme.surfaceContainerHighest // Use M3 equivalent
          : theme.colorScheme.secondaryContainer, // Use M3 equivalent
      borderRadius: BorderRadius.circular(12), // Standard Apple-like border radius
      onPressed: () {
        context.push('/admin/providers');
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.cloud_download,
            size: 18, // Smaller icon
            color: isDarkMode 
                ? Colors.white 
                : const Color(0xFF000000),
          ),
          const SizedBox(width: 6), // Smaller spacing
          Text(
            'Dropbox',
            style: theme.textTheme.labelMedium?.copyWith( // Smaller text style
              fontWeight: FontWeight.w500,
              color: isDarkMode 
                  ? Colors.white 
                  : const Color(0xFF000000),
            ),
          ),
        ],
      ),
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
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma Atividade Recente',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(204),
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
          padding: const EdgeInsets.all(0),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(
              context,
              notification,
              onTap: () => _handleAdminNotificationTap(
                context,
                notification,
                notificationActions,
              ),
            );
          },
        );
      },
      loading: () => Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      ),
      error: (error, stackTrace) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Falha ao carregar atividade',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
              child: Text(
                'Tentar Novamente',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              onPressed: () {
                refreshAdminNotifications(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    UserNotification notification, {
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat.yMd('pt_PT').add_jm();
    final formattedDate = dateFormatter.format(notification.createdAt);
    final resellerName = notification.metadata['resellerName'] ?? 'Revendedor Desconhecido';
    
    // Determine the second part of the subtitle based on notification type
    String secondarySubtitleText = '?';
    if (notification.type == NotificationType.proposalAccepted || notification.type == NotificationType.proposalRejected) {
      secondarySubtitleText = notification.metadata['proposalName'] ?? '?';
    } else if (notification.type == NotificationType.newSubmission) {
      secondarySubtitleText = notification.metadata['clientName'] ?? notification.metadata['clientNif'] ?? '?';
    } else {
      secondarySubtitleText = notification.metadata['clientName'] ?? '?'; 
    }

    final isNew = !notification.isRead;

    IconData itemIcon = CupertinoIcons.doc_plaintext;
    Color iconColor;

    // Icon and color logic
    switch (notification.type) {
      case NotificationType.newSubmission:
        itemIcon = CupertinoIcons.doc_on_doc_fill;
        iconColor = const Color(0xFF3B82F6); // Blue
        break;
      case NotificationType.statusChange:
        itemIcon = CupertinoIcons.arrow_swap;
        iconColor = const Color(0xFFF59E0B); // Amber
        break;
      case NotificationType.rejection: 
        itemIcon = CupertinoIcons.xmark_circle_fill;
        iconColor = const Color(0xFFEF4444); // Red
        break;
      case NotificationType.proposalRejected:
        itemIcon = CupertinoIcons.hand_thumbsdown_fill;
        iconColor = const Color(0xFFEF4444); // Red
        break;
      case NotificationType.proposalAccepted: 
        itemIcon = CupertinoIcons.check_mark_circled_solid; 
        iconColor = const Color(0xFF10B981); // Green
        break;
      default:
        itemIcon = CupertinoIcons.bell_fill;
        iconColor = const Color(0xFF6B7280); // Gray
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark 
            ? const Color(0xFF1C1C1E) 
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), // Reduced padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
              children: [
                // Leading avatar with improved styling
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(itemIcon, size: 20, color: iconColor),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notification.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                          fontSize: 14, // Slightly smaller for mobile
                        ),
                        maxLines: 1, // Ensure single line
                        overflow: TextOverflow.ellipsis, // Add ellipsis
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$resellerName / $secondarySubtitleText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12, // Slightly smaller for mobile
                        ),
                        maxLines: 1, // Ensure single line
                        overflow: TextOverflow.ellipsis, // Add ellipsis
                      ),
                    ],
                  ),
                ),
                
                // Trailing date and unread indicator
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11, // Slightly smaller for mobile
                      ),
                    ),
                    if (isNew) const SizedBox(height: 4),
                    if (isNew)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: iconColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Admin Notification Tap Handler --- //
  void _handleAdminNotificationTap(
    BuildContext context,
    UserNotification notification,
    NotificationActions actions,
  ) async {
    // Log and mark as read
    if (kDebugMode) {
      print("Notification ID: ${notification.id}");
      print("Notification Type: ${notification.type}");
    }
    
    await actions.markAsRead(notification.id);

    // Navigate based on type
    if (!context.mounted) return;
    
    String snackBarMessage = 'Ação desconhecida';
    bool showSnackBar = false;

    switch (notification.type) {
      case NotificationType.newSubmission:
      case NotificationType.statusChange:
      case NotificationType.rejection:
        if (notification.metadata.containsKey('submissionId')) {
          final submissionId = notification.metadata['submissionId'] as String?;
          if (submissionId != null) {
            await _fetchAndNavigateToDetailAdmin(context, submissionId);
          } else {
            snackBarMessage = 'ID da submissão não encontrado.';
            showSnackBar = true;
          }
        } else {
          snackBarMessage = 'Metadados da submissão em falta.';
          showSnackBar = true;
        }
        break;
      case NotificationType.proposalRejected:
        snackBarMessage = 'Rejeição de Proposta: ${notification.metadata['proposalName'] ?? 'N/A'}';
        showSnackBar = true;
        break;
      default:
        snackBarMessage = 'Tipo de notificação não tratado: ${notification.type}';
        showSnackBar = true;
        break;
    }

    if (showSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackBarMessage),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fetchAndNavigateToDetailAdmin(
    BuildContext context,
    String submissionId,
  ) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('serviceSubmissions')
          .doc(submissionId)
          .get();

      if (!context.mounted) return;

      if (docSnapshot.exists) {
        final submission = ServiceSubmission.fromFirestore(docSnapshot);
        context.push('/admin/opportunity-detail', extra: submission);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível encontrar os detalhes da submissão.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching submission document: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar detalhes da submissão: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatisticsSection(BuildContext context) {
    final theme = Theme.of(context);

    // Navigation action for the icon button
    void navigateToDetails() {
      context.push(
        '/admin/stats-detail',
        extra: {'timeFilter': _selectedTimeFilter},
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
                'Estatísticas',
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
                      dropdownColor:
                          theme
                              .colorScheme
                              .surfaceContainerHighest, // Updated deprecated
                      borderRadius: BorderRadius.circular(8),
                      items:
                          TimeFilter.values.map((TimeFilter filter) {
                            String text;
                            switch (filter) {
                              case TimeFilter.weekly:
                                text = 'Semanal';
                                break;
                              case TimeFilter.monthly:
                                text = 'Mensal';
                                break;
                              case TimeFilter.cycle:
                                text = 'Ciclo';
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
            shadowColor: theme.shadowColor.withAlpha(26), // Use withAlpha
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
                                  'Submissões',
                                  style: theme.textTheme.titleSmall,
                                ),
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
                                  'Receita Estimada',
                                  style: theme.textTheme.titleSmall,
                                ),
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
                              'Submissões',
                              style: theme.textTheme.titleSmall,
                            ),
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
                              'Receita Estimada',
                              style: theme.textTheme.titleSmall,
                            ),
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
      bottomTitleInterval = 'DS'; // DS for Dia da Semana (Weekday initial)
    }
    if (filter == TimeFilter.cycle) {
      days = 90;
      bottomTitleInterval = 'S#'; // S# for Semana Número (Week Number)
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
              color: theme.dividerColor.withAlpha(26), // Use withAlpha
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withAlpha(26), // Use withAlpha
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
            color: theme.dividerColor.withAlpha(51), // Use withAlpha
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
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipMargin: 8,
            getTooltipColor: (LineBarSpot spot) {
              return theme.colorScheme.primaryContainer.withOpacity(0.9);
            },
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
              color: theme.colorScheme.primary.withAlpha(51), // Use withAlpha
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
      bottomTitleInterval = 'DS';
    }
    if (filter == TimeFilter.cycle) {
      days = 90;
      bottomTitleInterval = 'S#';
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
              color: theme.dividerColor.withAlpha(26), // Use withAlpha
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withAlpha(26), // Use withAlpha
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
            color: theme.dividerColor.withAlpha(51), // Use withAlpha
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
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipMargin: 8,
            getTooltipColor: (LineBarSpot spot) {
              return theme.colorScheme.secondaryContainer.withOpacity(0.9);
            },
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final flSpot = barSpot;
                // Format as currency for tooltip
                final currencyFormatter = NumberFormat.simpleCurrency(
                  decimalDigits: 0,
                  locale: 'pt_PT', // Assuming Portuguese (Portugal)
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
              color: Colors.green.withAlpha(51), // Use withAlpha
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

    // Use 'pt_PT' for Portuguese date formatting
    final locale = 'pt_PT';

    switch (intervalType) {
      case 'DS': // Weekly - Day Initials (Dia da Semana)
        DateTime date = DateTime.now().subtract(
          Duration(days: totalDays - 1 - dayIndex),
        );
        text = DateFormat.E(locale).format(date)[0].toUpperCase(); 
        break;
      case 'S#': // Cycle - Week Number (Semana Número)
        int weekNumber = (dayIndex / 7).floor() + 1;
        text = 'S$weekNumber';
        break;
      case 'D': // Monthly - Day Number
      default:
        text = (dayIndex + 1).toString(); // Day 1, Day 2...
        break;
    }

    return SideTitleWidget(
      meta: meta, // Reverted to meta
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
        locale: 'pt_PT', // Assuming Portuguese (Portugal)
      );
      text = currencyFormatter.format(value);
    } else {
      text = value.toInt().toString();
    }

    return SideTitleWidget(
      meta: meta, // Reverted to meta
      space: 8.0,
      child: Text(text, style: style, textAlign: TextAlign.left),
    );
  }

  // --- NEW: Provider Resources Section Widget ---
  Widget _buildProviderResourcesSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recursos do Fornecedor',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shadowColor: theme.shadowColor.withAlpha(26),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: theme.colorScheme.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                context.push('/admin/providers'); // Navigate to provider list
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.folder_fill,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Gerir Documentos do Fornecedor',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.6,
                      ),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- //
}

// Custom ScrollBehavior to hide the scrollbar
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    // Hide scrollbar by returning the child directly
    return child;
  }

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.android;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
