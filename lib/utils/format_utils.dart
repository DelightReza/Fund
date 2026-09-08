import 'package:intl/intl.dart';

class FormatUtils {
  static String formatCurrency(double amount, [String currency = '₹']) {
    final cleanSymbol = currency.trim();
    final sym = cleanSymbol.isEmpty ? '' : '$cleanSymbol ';
    final formatter = NumberFormat.currency(
      symbol: sym,
      decimalDigits: amount % 1.0 == 0.0 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  static String formatAmount(double amount) {
    if (amount % 1.0 == 0.0) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}
