
import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (_) {
      return isoString.replaceFirst('T', ' ').substring(0, 16);
    }
  }

  static String formatDateOnly(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return isoString.split('T').first;
    }
  }

  static String now() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-ddTHH:mm:ss').format(now);
  }

  static String fromLocalDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-ddTHH:mm:ss').format(dateTime);
  }
}

