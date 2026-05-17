import 'package:intl/intl.dart';

/// Utility class for date and time formatting
class DateFormatter {
  DateFormatter._();

  /// Format date as 'Jan 15, 2024'
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  /// Format date as '15/01/2024'
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format date as 'Monday, January 15, 2024'
  static String formatDateLong(DateTime date) {
    return DateFormat('EEEE, MMMM d, y').format(date);
  }

  /// Format time as '2:30 PM'
  static String formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return time;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final dateTime = DateTime(2024, 1, 1, hour, minute);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return time;
    }
  }

  /// Format DateTime to time string '2:30 PM'
  static String formatTimeFromDateTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Format date and time as 'Jan 15, 2024 at 2:30 PM'
  static String formatDateTime(DateTime date, String time) {
    return '${formatDate(date)} at ${formatTime(time)}';
  }

  /// Get relative time (e.g., 'Today', 'Tomorrow', 'In 3 days')
  static String getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = targetDate.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 1 && difference < 7) {
      return 'In $difference days';
    } else if (difference < -1 && difference > -7) {
      return '${-difference} days ago';
    } else {
      return formatDate(date);
    }
  }

  /// Get time until event (e.g., 'Starts in 2 hours', 'Started 30 minutes ago')
  static String getTimeUntilEvent(DateTime eventDate, String eventTime) {
    try {
      final parts = eventTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final eventDateTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        hour,
        minute,
      );

      final now = DateTime.now();
      final difference = eventDateTime.difference(now);

      if (difference.isNegative) {
        // Event has passed
        final absDiff = difference.abs();
        if (absDiff.inMinutes < 60) {
          return 'Started ${absDiff.inMinutes} ${absDiff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
        } else if (absDiff.inHours < 24) {
          return 'Started ${absDiff.inHours} ${absDiff.inHours == 1 ? 'hour' : 'hours'} ago';
        } else {
          return 'Event ended';
        }
      } else {
        // Event is upcoming
        if (difference.inMinutes < 60) {
          return 'Starts in ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'}';
        } else if (difference.inHours < 24) {
          return 'Starts in ${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'}';
        } else if (difference.inDays < 7) {
          return 'Starts in ${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'}';
        } else {
          return formatDateTime(eventDate, eventTime);
        }
      }
    } catch (e) {
      return formatDateTime(eventDate, eventTime);
    }
  }

  /// Convert date to ISO string for storage
  static String toIsoString(DateTime date) {
    return date.toIso8601String();
  }

  /// Parse ISO string to DateTime
  static DateTime fromIsoString(String isoString) {
    return DateTime.parse(isoString);
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Check if date is in the future
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }
}
