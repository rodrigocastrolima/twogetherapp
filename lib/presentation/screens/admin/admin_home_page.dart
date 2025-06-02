import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
// import 'package:fl_chart/fl_chart.dart'; // Removed
// import 'dart:math'; // Removed
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/notification.dart';
import '../../../core/models/service_submission.dart';
import '../../../features/notifications/presentation/providers/notification_provider.dart';

import '../../../features/services/data/repositories/service_submission_repository.dart';

import '../../../features/notifications/presentation/widgets/unified_notification_item.dart';
// import '../../../core/theme/ui_styles.dart'; // Removed

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  // State for the time filter
  // TimeFilter _selectedTimeFilter = TimeFilter.monthly; // Removed
  int _currentPage = 0;

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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // --- Title ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
                child: Text(
                  'Início',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
                  // --- Ações Rápidas ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                child: Text(
                    'Ações Rápidas',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                  ),
                    ),
                  ),
                  const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                child: Wrap(
                    spacing: 24,
                    runSpacing: 16,
                        children: [
                    _quickActionCard(
                        icon: CupertinoIcons.cloud_download,
                        label: 'Dropbox',
                        onTap: () => context.push('/admin/providers'),
                      ),
                    _quickActionCard(
                        icon: CupertinoIcons.add_circled_solid,
                        label: 'Nova Oportunidade',
                        onTap: () => context.push('/admin/opportunity/create'),
                            ),
                          ],
                ),
                        ),
                  const SizedBox(height: 40),
                  // --- Notificações ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                child: Text(
                  'Notificações',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
                  const SizedBox(height: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Builder(
                    builder: (context) {
                      return _buildNotificationsList(context);
                    },
                    ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Quick Action Card (copied from reseller_home_page.dart) ---
  Widget _quickActionCard({ // Renamed
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // --- Notification Card (Material style, like reseller home) ---
  Widget _buildNotificationCard(
    BuildContext context,
    UserNotification notification, {
    required VoidCallback onTap,
  }) {
     throw UnimplementedError('This method is unused and should be removed');
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
      case NotificationType.proposalAccepted:
        final proposalId = notification.metadata['proposalId'] as String?;
        if (proposalId != null && proposalId.isNotEmpty) {
          context.push('/admin/proposal/$proposalId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir a proposta: ID em falta.'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        context.push('/review-this-submission', extra: submission);
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
        final totalPages = (notifications.length / 6).ceil();
        final pageNotifications = notifications.skip(_currentPage * 6).take(6).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(0),
                itemCount: pageNotifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 0),
                itemBuilder: (context, index) {
                  final notification = pageNotifications[index];
                  return UnifiedNotificationItem(
                    notification: notification,
                    onTap: () => _handleAdminNotificationTap(context, notification, notificationActions),
                    onDelete: () => notificationActions.deleteNotification(notification.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text('${_currentPage + 1} / $totalPages', style: theme.textTheme.bodyMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed: _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Falha ao carregar notificações', style: TextStyle(color: theme.colorScheme.error))),
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