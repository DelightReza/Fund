import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppDateUtils {
  static String todayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  static String todayDateTimeString() {
    return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
  }

  static String todayMonthKey() {
    return DateFormat('yyyy-MM').format(DateTime.now());
  }

  static DateTime parseDateTime(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();
    try {
      if (dateStr.contains('T')) {
        return DateTime.parse(dateStr);
      } else if (dateStr.contains(' ')) {
        return DateFormat('yyyy-MM-dd HH:mm').parse(dateStr);
      } else {
        return DateFormat('yyyy-MM-dd').parse(dateStr);
      }
    } catch (_) {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  static bool hasTime(String dateStr) {
    return dateStr.contains('T') || (dateStr.contains(' ') && dateStr.contains(':'));
  }

  static String getMonthKey(String dateStr) {
    try {
      if (dateStr.length >= 7) {
        return dateStr.substring(0, 7);
      }
      final dt = parseDateTime(dateStr);
      return DateFormat('yyyy-MM').format(dt);
    } catch (_) {
      return dateStr.length >= 7 ? dateStr.substring(0, 7) : dateStr;
    }
  }

  static String formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = parseDateTime(dateStr);
      if (hasTime(dateStr)) {
        return DateFormat('MMM d, yyyy • h:mm a').format(dt);
      }
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatDateOnly(String dateStr) {
    if (dateStr.isEmpty) return todayString();
    try {
      final dt = parseDateTime(dateStr);
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  static String formatTimeOnly(String dateStr) {
    if (dateStr.isEmpty || !hasTime(dateStr)) return '';
    try {
      final dt = parseDateTime(dateStr);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  static TimeOfDay parseTimeOfDay(String dateStr) {
    if (dateStr.isEmpty || !hasTime(dateStr)) {
      return TimeOfDay.now();
    }
    try {
      final dt = parseDateTime(dateStr);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return TimeOfDay.now();
    }
  }

  static String formatTimeOfDay(TimeOfDay time, BuildContext? context) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  static String formatMonthName(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length >= 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final dt = DateTime(year, month, 1);
        return DateFormat('MMMM yyyy').format(dt);
      }
      return monthStr;
    } catch (_) {
      return monthStr;
    }
  }

  static String formatRelativeDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = parseDateTime(dateStr);
      final now = DateTime.now();
      final difference = now.difference(dt);
      final hasTimeInfo = hasTime(dateStr);
      final timeSuffix = hasTimeInfo ? ' • ${DateFormat('h:mm a').format(dt)}' : '';

      if (difference.inDays == 0 && dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return 'Today$timeSuffix';
      } else if (difference.inDays <= 1 && (now.day - dt.day == 1 || difference.inHours < 36)) {
        return 'Yesterday$timeSuffix';
      } else if (difference.inDays < 7 && difference.inDays > 0) {
        return '${difference.inDays}d ago$timeSuffix';
      } else if (dt.year == now.year) {
        return '${DateFormat('MMM d').format(dt)}$timeSuffix';
      } else {
        return '${DateFormat('MMM d, yyyy').format(dt)}$timeSuffix';
      }
    } catch (_) {
      return dateStr;
    }
  }
}
