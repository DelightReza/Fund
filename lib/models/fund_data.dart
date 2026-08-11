import 'transaction.dart';

class FundData {
  const FundData({
    this.transactions = const [],
    this.people = const {},
    this.billTypes = const {},
  });

  final List<Transaction> transactions;
  final Map<String, double> people;
  final Map<String, double> billTypes;

  factory FundData.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'];
    final txs = rawTransactions is List
        ? rawTransactions
            .whereType<Map>()
            .map((entry) => Transaction.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <Transaction>[];

    Map<String, double> parseMap(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(k.toString(), _toDouble(v)));
    }

    return FundData(
      transactions: txs,
      people: parseMap(json['people']),
      billTypes: parseMap(json['billTypes']),
    );
  }

  Map<String, dynamic> toJson() => {
        'billTypes': billTypes,
        'people': people,
        'transactions': transactions.map((e) => e.toJson()).toList(),
      };

  FundData copyWith({
    List<Transaction>? transactions,
    Map<String, double>? people,
    Map<String, double>? billTypes,
  }) {
    return FundData(
      transactions: transactions ?? this.transactions,
      people: people ?? this.people,
      billTypes: billTypes ?? this.billTypes,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }
}
