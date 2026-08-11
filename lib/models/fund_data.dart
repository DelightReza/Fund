import 'transaction.dart';

class FundData {
  const FundData({
    this.transactions = const [],
  });

  final List<Transaction> transactions;

  factory FundData.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'];
    if (rawTransactions is! List) {
      return const FundData();
    }

    return FundData(
      transactions: rawTransactions
          .whereType<Map>()
          .map((entry) => Transaction.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'transactions': transactions.map((e) => e.toJson()).toList(),
      };

  FundData copyWith({List<Transaction>? transactions}) {
    return FundData(
      transactions: transactions ?? this.transactions,
    );
  }
}
