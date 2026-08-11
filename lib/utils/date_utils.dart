import 'package:intl/intl.dart';

class AppDateUtils {
  static String nowIso() => DateTime.now().toIso8601String();

  static String generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  static String formatDateTime(String isoDateTime) {
    try {
      final date = DateTime.parse(isoDateTime).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (_) {
      return isoDateTime;
    }
  }

  static String formatDate(String isoDateTime) {
    try {
      final date = DateTime.parse(isoDateTime).toLocal();
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return isoDateTime;
    }
  }
}
