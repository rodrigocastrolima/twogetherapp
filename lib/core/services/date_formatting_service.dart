import 'package:intl/intl.dart';

/// Service to provide consistent date formatting for notifications across the app
class DateFormattingService {
  // Private constructors to prevent instantiation
  DateFormattingService._();

  // Date formatters for consistent formatting
  static final DateFormat _dateFormatter = DateFormat.yMd('pt_PT');
  static final DateFormat _timeFormatter = DateFormat.Hm('pt_PT'); // HH:mm format
  static final DateFormat _dateTimeFormatter = DateFormat.yMd('pt_PT').add_jm();
  static final DateFormat _shortDateFormatter = DateFormat('dd MMM', 'pt_PT');
  static final DateFormat _fullDateFormatter = DateFormat('dd/MM/yyyy', 'pt_PT');

  /// Format notification date with intelligent relative/absolute formatting
  /// 
  /// Returns:
  /// - "Agora" for less than 1 minute ago
  /// - "X min" for 1-59 minutes ago  
  /// - "Hoje, HH:mm" for today
  /// - "Ontem, HH:mm" for yesterday
  /// - "dd MMM" for this year
  /// - "dd/MM/yyyy" for previous years
  static String formatNotificationDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final isToday = _isSameDay(dateTime, now);
    final isYesterday = _isSameDay(dateTime, now.subtract(const Duration(days: 1)));
    final isThisYear = dateTime.year == now.year;

    // Less than 1 minute ago
    if (difference.inMinutes < 1) {
      return 'Agora';
    }

    // Less than 1 hour ago (1-59 minutes)
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    }

    // Today
    if (isToday) {
      return 'Hoje, ${_timeFormatter.format(dateTime)}';
    }

    // Yesterday
    if (isYesterday) {
      return 'Ontem, ${_timeFormatter.format(dateTime)}';
    }

    // This year (but not today/yesterday)
    if (isThisYear) {
      return _shortDateFormatter.format(dateTime);
    }

    // Previous years
    return _fullDateFormatter.format(dateTime);
  }

  /// Format date for admin notifications (more detailed)
  /// Returns: "dd/MM/yyyy HH:mm"
  static String formatAdminNotificationDate(DateTime dateTime) {
    return _dateTimeFormatter.format(dateTime);
  }

  /// Format date for simple display
  /// Returns: "dd/MM/yyyy"
  static String formatSimpleDate(DateTime dateTime) {
    return _dateFormatter.format(dateTime);
  }

  /// Format time only
  /// Returns: "HH:mm"
  static String formatTime(DateTime dateTime) {
    return _timeFormatter.format(dateTime);
  }

  /// Format short date
  /// Returns: "dd MMM" (e.g., "15 Jan")
  static String formatShortDate(DateTime dateTime) {
    return _shortDateFormatter.format(dateTime);
  }

  /// Format relative time for very recent notifications
  /// Returns: "há X minutos", "há X horas", etc.
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'há ${minutes} ${minutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'há ${hours} ${hours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'há ${days} ${days == 1 ? 'dia' : 'dias'}';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return 'há ${weeks} ${weeks == 1 ? 'semana' : 'semanas'}';
    } else {
      return formatSimpleDate(dateTime);
    }
  }

  /// Check if two dates are on the same day
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Get a human-readable time difference
  /// Examples: "2 minutes ago", "1 hour ago", "3 days ago"
  static String getTimeDifference(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'agora mesmo';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'há ${minutes} ${minutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'há ${hours} ${hours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return 'há ${days} ${days == 1 ? 'dia' : 'dias'}';
    } else if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return 'há ${months} ${months == 1 ? 'mês' : 'meses'}';
    } else {
      final years = difference.inDays ~/ 365;
      return 'há ${years} ${years == 1 ? 'ano' : 'anos'}';
    }
  }

  /// Check if a date is within the last 24 hours
  static bool isWithinLast24Hours(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    return difference.inHours < 24;
  }

  /// Check if a date is today
  static bool isToday(DateTime dateTime) {
    return _isSameDay(dateTime, DateTime.now());
  }

  /// Check if a date is yesterday
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _isSameDay(dateTime, yesterday);
  }

  /// Get a formatted string for notification timestamps with fallback
  /// This is the main method that should be used throughout the app
  static String formatNotificationTimestamp(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Data desconhecida';
    }
    
    try {
      return formatNotificationDate(dateTime);
    } catch (e) {
      // Fallback to simple date format if there's any formatting error
      return formatSimpleDate(dateTime);
    }
  }
} 