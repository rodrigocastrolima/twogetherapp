import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/models/notification.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../features/notifications/presentation/widgets/unified_notification_item.dart';
import '../../features/notifications/presentation/widgets/rejection_detail_dialog.dart';
import '../../features/opportunity/presentation/providers/opportunity_providers.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../app/router/app_router.dart';
import '../widgets/app_loading_indicator.dart';

/// Reusable notification list widget that can be used in home page or dropdown
class NotificationListWidget extends ConsumerStatefulWidget {
  final bool showPasswordReminder;
  final VoidCallback? onNotificationTap; // Called after notification is handled
  final EdgeInsets? padding;
  final int? maxItems; // For dropdown, limit items shown
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool isCompact; // For dropdown, use more compact styling

  const NotificationListWidget({
    super.key,
    this.showPasswordReminder = true,
    this.onNotificationTap,
    this.padding,
    this.maxItems,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.isCompact = false,
  });

  @override
  ConsumerState<NotificationListWidget> createState() => _NotificationListWidgetState();
}

class _NotificationListWidgetState extends ConsumerState<NotificationListWidget> {
  OverlayEntry? _loadingOverlay;

  @override
  void dispose() {
    _loadingOverlay?.remove();
    super.dispose();
  }

  // Build compact notification item for dropdown
  Widget _buildCompactNotificationItem(UserNotification notification, NotificationActions actions) {
    final theme = Theme.of(context);
    final isNew = !notification.isRead;
    final dateFormatter = DateFormat.yMd('pt_PT').add_jm();
    final formattedDate = dateFormatter.format(notification.createdAt);
    
    // Get icon and color (complete logic matching UnifiedNotificationItem)
    IconData itemIcon;
    Color iconColor;
    String? serviceType = notification.metadata['serviceType'] as String?;
    String? processType = notification.metadata['processType'] as String?;
    
    if (notification.type == NotificationType.newSubmission) {
      // Service type specific icons
      switch (serviceType) {
        case 'Energia Residencial':
          itemIcon = Icons.home_rounded;
          iconColor = const Color(0xFF2563EB);
          break;
        case 'Energia Comercial':
          itemIcon = Icons.business_rounded;
          iconColor = const Color(0xFFF59E0B);
          break;
        case 'Solar':
          itemIcon = Icons.solar_power_rounded;
          iconColor = const Color(0xFF22C55E);
          break;
        default:
          itemIcon = CupertinoIcons.doc_on_doc_fill;
          iconColor = const Color(0xFF6B7280);
      }
    } else {
      // Status change and other types
      switch (notification.type) {
        case NotificationType.statusChange:
          if (notification.title == 'Oportunidade Aceite') {
            itemIcon = CupertinoIcons.checkmark_circle_fill;
            iconColor = const Color(0xFF10B981);
          } else if (processType == 'contract_insertion') {
            itemIcon = CupertinoIcons.checkmark_circle_fill;
            iconColor = const Color(0xFF10B981);
          } else if (notification.title == 'Proposta Expirada') {
            itemIcon = CupertinoIcons.clock_fill;
            iconColor = const Color(0xFFF59E0B);
          } else if (notification.title == 'Revisão de Documentos') {
            itemIcon = CupertinoIcons.doc_text_fill;
            iconColor = const Color(0xFF6B7280);
          } else if (notification.title == 'Processo Concluído') {
            itemIcon = CupertinoIcons.checkmark_circle_fill;
            iconColor = const Color(0xFF10B981);
          } else {
            itemIcon = CupertinoIcons.arrow_swap;
            iconColor = const Color(0xFFF59E0B);
          }
          break;
        case NotificationType.rejection:
        case NotificationType.proposalRejected:
          itemIcon = CupertinoIcons.hand_thumbsdown_fill;
          iconColor = const Color(0xFFEF4444);
          break;
        case NotificationType.proposalAccepted:
          itemIcon = CupertinoIcons.doc_on_doc_fill;
          iconColor = const Color(0xFF10B981);
          break;
        default:
          itemIcon = CupertinoIcons.bell_fill;
          iconColor = const Color(0xFF6B7280);
      }
    }

    return InkWell(
      onTap: () => _handleNotificationTap(notification, actions),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Smaller icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(itemIcon, size: 14, color: iconColor),
              ),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isNew ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13, // Smaller font
                      color: isNew ? const Color(0xFF2563EB) : theme.colorScheme.onSurface,
                    ),
                    maxLines: 2, // Allow more lines for title
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11, // Smaller font
                      ),
                      maxLines: 3, // Allow more lines for message
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Add date to compact notifications
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // Delete button for read notifications
            if (!isNew)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: () => actions.deleteNotification(notification.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationActions = ref.watch(notificationActionsProvider);
    final notificationsStream = ref.watch(userNotificationsProvider);

    return Consumer(
      builder: (context, ref, _) {
        // Password reminder logic - same as home page
        final authNotifier = ref.read(authNotifierProvider);
        final passwordHasBeenChanged = authNotifier.initialPasswordChanged;

        return notificationsStream.when(
          data: (notificationsFromProvider) {
            List<UserNotification> combinedNotifications = [...notificationsFromProvider];
            final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
            
            // Add password reminder if needed and enabled
            if (widget.showPasswordReminder && !passwordHasBeenChanged) {
              final passwordReminder = UserNotification(
                id: '__password_reminder__', 
                userId: currentUserId,
                title: 'Security Recommendation', 
                message: 'Change your initial password.',
                type: NotificationType.system, 
                createdAt: DateTime.now(), 
                isRead: true,
                metadata: { 'isPasswordReminder': true },
              );
              combinedNotifications.insert(0, passwordReminder);
            }

            // Apply max items limit for dropdown
            if (widget.maxItems != null && combinedNotifications.length > widget.maxItems!) {
              combinedNotifications = combinedNotifications.take(widget.maxItems!).toList();
            }

            if (combinedNotifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  child: Column(
                    children: [
                      Icon(CupertinoIcons.bell_slash, size: 48, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('Sem notificações', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)))
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: widget.shrinkWrap,
              physics: widget.physics,
              padding: widget.padding,
              itemCount: combinedNotifications.length,
              itemBuilder: (context, index) {
                final notification = combinedNotifications[index];
                
                return widget.isCompact
                    ? _buildCompactNotificationItem(notification, notificationActions)
                    : UnifiedNotificationItem(
                        notification: notification,
                        onTap: () => _handleNotificationTap(notification, notificationActions),
                        onDelete: () => notificationActions.deleteNotification(notification.id),
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text('Falha ao carregar notificações', style: TextStyle(color: theme.colorScheme.error))),
        );
      },
    );
  }

  // EXACT COPY of _handleNotificationTap from reseller_home_page.dart
  void _handleNotificationTap(
    UserNotification notification,
    NotificationActions actions,
  ) async {
    // --- Check for special password reminder ID ---
    if (notification.id == '__password_reminder__') {
      context.push('/profile-details');
      widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
      return; // Don't proceed with marking as read etc.
    }
    // --------------------------------------------

    // Mark notification as read (only for real notifications)
    await actions.markAsRead(notification.id);

    // Navigate based on notification type and metadata
    switch (notification.type) {
      case NotificationType.statusChange:
        // Check if this is an opportunity approval notification
        if (notification.title == 'Oportunidade Aceite') {
          // Navigate to the opportunity list page
          context.go('/clients');
          widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
          return;
        }
        // Check if this is a contract insertion, proposal expired, or document review notification
        final processType = notification.metadata['processType'] as String?;
        if (processType == 'contract_insertion' || processType == 'proposal_expired' || processType == 'document_review') {
          final opportunityId = notification.metadata['opportunityId'] as String?;
          if (opportunityId != null) {
            // Show loading overlay over entire app
            _loadingOverlay = OverlayEntry(
              builder: (context) => const AppLoadingIndicator(),
            );
            Overlay.of(context, rootOverlay: true).insert(_loadingOverlay!);
            
            // Get the opportunity data to navigate to details page
            try {
              final opportunitiesAsync = ref.read(resellerOpportunitiesProvider);
              final opportunities = opportunitiesAsync.value;
              
              if (opportunities != null) {
                final opportunity = opportunities.firstWhere(
                  (opp) => opp.id == opportunityId,
                  orElse: () => throw Exception('Opportunity not found'),
                );
                // Remove loading overlay and navigate
                if (mounted) {
                  _loadingOverlay?.remove();
                  _loadingOverlay = null;
                  context.push('/opportunity-details', extra: opportunity);
                  widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
                }
              } else {
                // If opportunities haven't loaded yet, refresh and wait
                ref.refresh(resellerOpportunitiesProvider);
                final refreshedOpportunities = await ref.read(resellerOpportunitiesProvider.future);
                final opportunity = refreshedOpportunities.firstWhere(
                  (opp) => opp.id == opportunityId,
                  orElse: () => throw Exception('Opportunity not found'),
                );
                // Remove loading overlay and navigate
                if (mounted) {
                  _loadingOverlay?.remove();
                  _loadingOverlay = null;
                  context.push('/opportunity-details', extra: opportunity);
                  widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error navigating to opportunity details: $e');
              }
              // Remove loading overlay and show error
              if (mounted) {
                _loadingOverlay?.remove();
                _loadingOverlay = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao abrir detalhes da oportunidade: $e')),
                );
              }
            }
          }
        } else if (notification.metadata.containsKey('submissionId')) {
          final submissionId = notification.metadata['submissionId'];
          context.push('/submissions/$submissionId');
          widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
        }
        break;
      case NotificationType.rejection:
        // Show the dialog instead of navigation
        showDialog(
          context: context,
          builder: (dialogContext) {
            return RejectionDetailDialog(notification: notification);
          },
        );
        widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
        break;
      case NotificationType.payment:
        // Navigate to payment details or dashboard
        context.push('/dashboard');
        widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
        break;
      case NotificationType.system:
      default:
        // For system notifications (like our reminder, though handled above),
        // just mark as read but don't navigate
        widget.onNotificationTap?.call(); // Close dropdown if this is called from dropdown
        break;
    }
  }
} 