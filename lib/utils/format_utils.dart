class FormatUtils {
  static String currency(double value, String symbol) {
    final normalized = value.abs() < 0.005 ? 0.0 : value;
    final formatted = normalized % 1 == 0
        ? normalized.toStringAsFixed(0)
        : normalized.toStringAsFixed(2);
    return '$symbol $formatted';
  }
}
