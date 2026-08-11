
class FormatUtils {
  static String formatAmount(double amount) {
    if (amount % 1 == 0) {
      return amount.toInt().toString();
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  static String formatCurrency(double amount, String currency) {
    final formatted = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '$formatted $currency';
  }
}

