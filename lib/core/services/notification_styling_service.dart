import 'package:flutter/cupertino.dart';
import '../models/notification.dart';

/// Configuration for a notification type including its visual representation
class NotificationTypeConfig {
  final IconData icon;
  final Color lightColor;
  final Color darkColor;
  final String displayName;

  const NotificationTypeConfig({
    required this.icon,
    required this.lightColor,
    required this.darkColor,
    required this.displayName,
  });

  /// Get the appropriate color based on theme brightness
  Color getColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkColor : lightColor;
  }

  /// Get background color with opacity for containers
  Color getBackgroundColor(Brightness brightness, {double opacity = 0.1}) {
    return getColor(brightness).withAlpha((255 * opacity).round());
  }
}

/// Service to provide consistent styling for notifications across the app
class NotificationStylingService {
  // Color constants for consistency
  static const Color _blueLight = Color(0xFF3B82F6);
  static const Color _blueDark = Color(0xFF60A5FA);
  
  static const Color _greenLight = Color(0xFF10B981);
  static const Color _greenDark = Color(0xFF34D399);
  
  static const Color _redLight = Color(0xFFEF4444);
  static const Color _redDark = Color(0xFFF87171);
  
  static const Color _orangeLight = Color(0xFFF59E0B);
  static const Color _orangeDark = Color(0xFFFBBF24);
  
  static const Color _grayLight = Color(0xFF6B7280);
  static const Color _grayDark = Color(0xFF9CA3AF);

  /// Configuration map for all notification types
  static const Map<NotificationType, NotificationTypeConfig> _configs = {
    NotificationType.newSubmission: NotificationTypeConfig(
      icon: CupertinoIcons.doc_on_doc_fill,
      lightColor: _blueLight,
      darkColor: _blueDark,
      displayName: 'Nova Submissão',
    ),
    NotificationType.statusChange: NotificationTypeConfig(
      icon: CupertinoIcons.arrow_swap,
      lightColor: _orangeLight,
      darkColor: _orangeDark,
      displayName: 'Mudança de Estado',
    ),
    NotificationType.rejection: NotificationTypeConfig(
      icon: CupertinoIcons.xmark_circle_fill,
      lightColor: _redLight,
      darkColor: _redDark,
      displayName: 'Rejeitado',
    ),
    NotificationType.proposalRejected: NotificationTypeConfig(
      icon: CupertinoIcons.hand_thumbsdown_fill,
      lightColor: _redLight,
      darkColor: _redDark,
      displayName: 'Proposta Rejeitada',
    ),
    NotificationType.proposalAccepted: NotificationTypeConfig(
      icon: CupertinoIcons.doc_on_doc_fill,
      lightColor: _greenLight,
      darkColor: _greenDark,
      displayName: 'Proposta Aceite',
    ),
    NotificationType.payment: NotificationTypeConfig(
      icon: CupertinoIcons.money_dollar_circle_fill,
      lightColor: _greenLight,
      darkColor: _greenDark,
      displayName: 'Pagamento',
    ),
    NotificationType.system: NotificationTypeConfig(
      icon: CupertinoIcons.bell_fill,
      lightColor: _grayLight,
      darkColor: _grayDark,
      displayName: 'Sistema',
    ),
  };

  /// Get configuration for a notification type
  static NotificationTypeConfig getConfigForType(NotificationType type) {
    return _configs[type] ?? _configs[NotificationType.system]!;
  }

  /// Get icon for a notification type
  static IconData getIconForType(NotificationType type) {
    return getConfigForType(type).icon;
  }

  /// Get color for a notification type based on theme
  static Color getColorForType(NotificationType type, Brightness brightness) {
    return getConfigForType(type).getColor(brightness);
  }

  /// Get background color for a notification type with opacity
  static Color getBackgroundColorForType(
    NotificationType type, 
    Brightness brightness, {
    double opacity = 0.1,
  }) {
    return getConfigForType(type).getBackgroundColor(brightness, opacity: opacity);
  }

  /// Get display name for a notification type
  static String getDisplayNameForType(NotificationType type) {
    return getConfigForType(type).displayName;
  }

  /// Special handling for status change notifications that need context-aware styling
  static NotificationTypeConfig getStatusChangeConfig(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'aprovado':
        return const NotificationTypeConfig(
          icon: CupertinoIcons.check_mark_circled_solid,
          lightColor: _greenLight,
          darkColor: _greenDark,
          displayName: 'Aprovado',
        );
      case 'rejected':
      case 'rejeitado':
        return const NotificationTypeConfig(
          icon: CupertinoIcons.xmark_circle_fill,
          lightColor: _redLight,
          darkColor: _redDark,
          displayName: 'Rejeitado',
        );
      case 'pending_review':
      case 'em_revisao':
        return const NotificationTypeConfig(
          icon: CupertinoIcons.clock_fill,
          lightColor: _orangeLight,
          darkColor: _orangeDark,
          displayName: 'Em Revisão',
        );
      default:
        return _configs[NotificationType.statusChange]!;
    }
  }

  /// Get icon and color for status change notifications with context
  static IconData getStatusChangeIcon(String? status) {
    return getStatusChangeConfig(status).icon;
  }

  /// Get color for status change notifications with context
  static Color getStatusChangeColor(String? status, Brightness brightness) {
    return getStatusChangeConfig(status).getColor(brightness);
  }

  /// Get background color for status change notifications with context
  static Color getStatusChangeBackgroundColor(
    String? status, 
    Brightness brightness, {
    double opacity = 0.1,
  }) {
    return getStatusChangeConfig(status).getBackgroundColor(brightness, opacity: opacity);
  }

  /// Helper method to get all available notification type configs
  static Map<NotificationType, NotificationTypeConfig> getAllConfigs() {
    return Map.unmodifiable(_configs);
  }
} 