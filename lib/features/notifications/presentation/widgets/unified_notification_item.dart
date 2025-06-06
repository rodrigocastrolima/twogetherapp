import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/notification.dart';

class _IconConfig {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _IconConfig(this.icon, this.iconColor, this.bgColor);
}

class UnifiedNotificationItem extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final EdgeInsetsGeometry? padding;

  const UnifiedNotificationItem({
    Key? key,
    required this.notification,
    this.onTap,
    this.onDelete,
    this.padding,
  }) : super(key: key);

  _IconConfig _getSubmissionIconAndColor(String? serviceType, ThemeData theme) {
    switch (serviceType) {
      case 'Energia Residencial':
        return _IconConfig(Icons.home_rounded, const Color(0xFF2563EB), const Color(0x1A2563EB)); // Deep blue
      case 'Energia Comercial':
        return _IconConfig(Icons.business_rounded, const Color(0xFFF59E0B), const Color(0x1AF59E0B)); // Vibrant orange
      case 'Solar':
        return _IconConfig(Icons.solar_power_rounded, const Color(0xFF22C55E), const Color(0x1A22C55E)); // Vibrant green
      default:
        return _IconConfig(CupertinoIcons.doc_on_doc_fill, const Color(0xFF6B7280), const Color(0x146B7280)); // Neutral gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat.yMd('pt_PT').add_jm();
    final formattedDate = dateFormatter.format(notification.createdAt);
    final isNew = !notification.isRead;

    // Get icon and color based on notification type and service type
    String? serviceType = notification.metadata['serviceType'] as String?;
    String? processType = notification.metadata['processType'] as String?;
    IconData itemIcon;
    Color iconColor;
    Color iconBgColor;
    if (notification.type == NotificationType.newSubmission) {
      final config = _getSubmissionIconAndColor(serviceType, theme);
      itemIcon = config.icon;
      iconColor = config.iconColor;
      iconBgColor = config.bgColor;
    } else {
      // Fallback to previous logic for other types
      switch (notification.type) {
        case NotificationType.statusChange:
          // Check if this is an opportunity approval notification
          if (notification.title == 'Oportunidade Aceite') {
            itemIcon = CupertinoIcons.checkmark_circle_fill;
            iconColor = const Color(0xFF10B981); // Green color for approval
            iconBgColor = const Color(0x1A10B981);
          } else if (processType == 'contract_insertion') {
            // Check if this is a contract insertion notification
            itemIcon = CupertinoIcons.checkmark_circle_fill;
            iconColor = const Color(0xFF10B981); // Green color for completion
            iconBgColor = const Color(0x1A10B981);
          } else if (notification.title == 'Proposta Expirada') {
            // Specific styling for expired proposals
            itemIcon = CupertinoIcons.clock_fill;
            iconColor = const Color(0xFFF59E0B); // Orange color
            iconBgColor = const Color(0x1AF59E0B);
          } else if (notification.title == 'Revisão de Documentos') {
            // Specific styling for document review
            itemIcon = CupertinoIcons.doc_text_fill;
            iconColor = const Color(0xFF6B7280); // Grey color
            iconBgColor = const Color(0x146B7280);
          } else {
            itemIcon = CupertinoIcons.arrow_swap;
            iconColor = const Color(0xFFF59E0B);
            iconBgColor = const Color(0x1AF59E0B);
          }
          break;
        case NotificationType.rejection:
          itemIcon = CupertinoIcons.hand_thumbsdown_fill;
          iconColor = const Color(0xFFEF4444);
          iconBgColor = const Color(0x0FEF4444); // 6% opacity for a subtler background
          break;
        case NotificationType.proposalRejected:
          itemIcon = CupertinoIcons.hand_thumbsdown_fill;
          iconColor = const Color(0xFFEF4444);
          iconBgColor = const Color(0x0FEF4444); // 6% opacity for a subtler background
          break;
        case NotificationType.proposalAccepted:
          itemIcon = CupertinoIcons.doc_on_doc_fill;
          iconColor = const Color(0xFF10B981);
          iconBgColor = const Color(0x1A10B981);
          break;
        default:
          itemIcon = CupertinoIcons.bell_fill;
          iconColor = const Color(0xFF6B7280);
          iconBgColor = const Color(0x146B7280);
      }
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: theme.colorScheme.primary.withOpacity(0.06),
        highlightColor: theme.colorScheme.primary.withOpacity(0.10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(itemIcon, size: 18, color: iconColor),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isNew ? FontWeight.w700 : FontWeight.normal,
                        color: isNew ? const Color(0xFF2563EB) : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (notification.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Date
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Only show delete (X) icon if notification is read
              if (!isNew)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: 'Eliminar notificação',
                  splashRadius: 18,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
} 